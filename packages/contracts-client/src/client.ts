/**
 * The facade: one object for everything the play page does.
 *
 * {@link createMintABearClient} takes a viem public client, optionally a wallet client (from Privy
 * or any other provider), and the deployment's addresses, and returns the calls grouped by what
 * they are for: `mint`, `whitelist`, `bears`, `events`, `split`, `units`. Reads need no wallet;
 * writes use the wallet's account and throw `NO_WALLET` without one. Every write simulates first,
 * waits for the transaction, and returns what it did (the minted ids, the spot number, the new
 * level) rather than a bare receipt.
 *
 * The functions underneath (`planBurn`, `execute`, `readBear`, …) stay exported for flows the facade
 * does not cover.
 *
 * @example
 * ```ts
 * import { createPublicClient, createWalletClient, custom, http } from "viem";
 * import { createMintABearClient, getDeployment, robinhoodChain } from "@mintabear/contracts-client";
 *
 * const provider = await privyWallet.getEthereumProvider();
 * const mintabear = createMintABearClient({
 *   publicClient: createPublicClient({ chain: robinhoodChain, transport: http() }),
 *   walletClient: createWalletClient({ chain: robinhoodChain, transport: custom(provider), account: privyWallet.address }),
 *   addresses: getDeployment(robinhoodChain.id),
 *   feeRecipient: OPENSEA_FEE_RECIPIENT,
 * });
 *
 * const bear = await mintabear.bears.get(7n);
 * const plan = await mintabear.bears.planBurn({ tokenId: 7n, targetLevel: 3 });
 * if (plan.ok) await mintabear.bears.executeBurn(plan);
 * ```
 *
 * @module
 */
import type { Abi, Address, Hex, Log, TransactionReceipt } from "viem";

import { seaDropAbi, whitelistClaimAbi } from "./abi/index.js";

import {
  linkCall,
  linkPrompt,
  planBurn,
  readBear,
  readCostToReach,
  readLevel,
  readLink,
  readLinkStatus,
  readPaused,
  readSnapshot,
  readThreshold,
  readWeightFor,
  unlinkCall,
  type BurnPlan,
  type PlanBurnArgs,
} from "./activation.js";
import type { MintABearAddresses } from "./addresses.js";
import { buildAllowList, type AllowList, type MintParams, type StageParams } from "./allowlist.js";
import { execute, executePlan, type AnyPublicClient, type AnyWalletClient, type Call, type WriteResult } from "./calls.js";
import { MAX_LEVEL } from "./constants.js";
import { ClientRefusal, MintABearError } from "./errors.js";
import { decodeSystemLogs, readSystemEvents, ReferenceIndexer, type SystemEvent } from "./events.js";
import {
  allowListMatchesChain,
  mintAllowListCall,
  mintPublicCall,
  readMintStats,
  readPublicDrop,
  remainingWhitelistMints,
} from "./mint.js";
import { computeSplit, type BearRow, type SplitResult } from "./split/compute.js";
import { rowsFromEvents, rowsFromSnapshot } from "./split/inputs.js";
import { planTransfer, type TransferPlan } from "./transfer.js";
import { formatMntd, parseMntd, readMntdDecimals } from "./units.js";
import { campaignOpen, claimCall, readAccountClaims, readCampaign, readClaimants, readClaimsOf, type Voucher } from "./whitelist.js";

/** Options of {@link createMintABearClient}. */
export interface MintABearClientOptions {
  /** A viem public client on the deployment's chain (reads, simulation, receipts). */
  publicClient: AnyPublicClient;
  /** The holder's wallet, with an account. Without one, writes throw `NO_WALLET`. */
  walletClient?: AnyWalletClient;
  /** The deployment's addresses (`getDeployment(chainId)`, or your own). */
  addresses: MintABearAddresses;
  /** The fee recipient Studio allows for SeaDrop mints (OpenSea's). Needed by `mint.public` and `mint.allowList` unless passed per call. */
  feeRecipient?: Address;
  /** Counts a bear's open marketplace listings, for the pre-burn warning (MINT's OpenSea API call). */
  countOpenListings?: (tokenId: bigint) => Promise<number>;
  /** The block the contracts were deployed at: where event reads (`bears.linkStatus`, `events.*`, `split.*`) start. Default 0. */
  deployBlock?: bigint;
  /** Errors of contracts outside this library (the $MNTD token's) to decode as well. */
  extraErrors?: Abi;
}

/** What a mint did. */
export interface MintResult extends WriteResult<typeof seaDropAbi> {
  /** The ids minted, ascending. */
  tokenIds: bigint[];
}

/** What a whitelist claim did. */
export interface ClaimResult extends WriteResult<typeof whitelistClaimAbi> {
  /** The spot claimed, 1–1,000. */
  spotNumber: bigint;
  /** The account's allocation number this claim used (1 or 2). */
  allocationIndex: number;
}

/** What a burn did. */
export interface BurnResult {
  /** One result per call sent (`approve`, then `burn`; or `burn` alone). */
  results: WriteResult[];
  /** From `BearActivated`. Amounts in base units. */
  activated: { tokenId: bigint; previousLevel: number; newLevel: number; amount: bigint; cumulative: bigint };
}

/** Where the royalty split's inputs come from; see `rowsFromEvents` and `rowsFromSnapshot`. */
export type SplitMode = { mode?: "events"; blockRange?: bigint } | { mode: "snapshot"; gasBudget?: bigint };

/**
 * Creates the facade.
 *
 * @param options - Clients, addresses, and defaults.
 * @returns The facade; see each group's methods.
 */
export function createMintABearClient(options: MintABearClientOptions) {
  const { publicClient, walletClient, addresses } = options;
  const deployBlock = options.deployBlock ?? 0n;
  const executeOptions = options.extraErrors ? { extraErrors: options.extraErrors } : undefined;
  let decimals: Promise<number> | undefined;

  const wallet = (): AnyWalletClient => {
    if (!walletClient) throw new ClientRefusal("NO_WALLET");
    return walletClient;
  };
  /** The given address, or the wallet's; `NO_WALLET` when neither. */
  const self = (address?: Address): Address => address ?? wallet().account.address;
  const send = <A extends Abi>(call: Call<A>) => execute(publicClient, wallet(), call, executeOptions);
  const feeRecipientOf = (given?: Address): Address => {
    const recipient = given ?? options.feeRecipient;
    if (!recipient) throw new ClientRefusal("INVALID_ARGUMENT", { reason: "Pass a feeRecipient (OpenSea's, as Studio allows it) to the client or the call." });
    return recipient;
  };
  const mintedIds = (result: { receipt: TransactionReceipt }, minter: Address): bigint[] =>
    decodeSystemLogs(result.receipt.logs, addresses)
      .flatMap((e) =>
        e.emitter === "bears" && e.eventName === "Transfer" && e.args.from === "0x0000000000000000000000000000000000000000" && e.args.to.toLowerCase() === minter.toLowerCase()
          ? [e.args.tokenId]
          : [],
      )
      .sort((x, y) => (x < y ? -1 : 1));

  const bears = {
    /**
     * Everything about one bear: `{ exists: false }`, or owner, level, burns, weight and the cost to level 5.
     * @param tokenId - The bear.
     */
    get: (tokenId: bigint) => readBear(publicClient, addresses, tokenId),
    /** The bear's level, 0–5. */
    level: (tokenId: bigint) => readLevel(publicClient, addresses, tokenId),
    /** $MNTD (base units) still needed for `targetLevel`; 0 when reached. */
    costToReach: (tokenId: bigint, targetLevel: number) => readCostToReach(publicClient, addresses, tokenId, targetLevel),
    /** The cumulative $MNTD (base units) each level needs, levels 0–5. */
    thresholds: () => Promise.all(Array.from({ length: MAX_LEVEL + 1 }, (_, level) => readThreshold(publicClient, addresses, level))),
    /** The royalty weight of each level 0–5, basis 100. */
    weights: () => Promise.all(Array.from({ length: MAX_LEVEL + 1 }, (_, level) => readWeightFor(publicClient, addresses, level))),
    /** Whether burning and linking are suspended. */
    paused: () => readPaused(publicClient, addresses),
    /** Owner, level and weight per id (`Activation.snapshot`). */
    snapshot: (ids: readonly bigint[], blockNumber?: bigint) => readSnapshot(publicClient, addresses, ids, blockNumber),

    /**
     * Works out and checks a burn to `targetLevel` for the connected wallet (or `owner`).
     * Show `plan.warnings`, then pass the plan to {@link bears.executeBurn}.
     * @returns `{ ok: true, amount, calls, warnings }`, or `{ ok: false, code, userMessage }`.
     */
    planBurn: (args: Omit<PlanBurnArgs, "owner" | "countOpenListings"> & Partial<Pick<PlanBurnArgs, "owner" | "countOpenListings">>): Promise<BurnPlan> =>
      planBurn(publicClient, addresses, {
        ...args,
        owner: self(args.owner),
        countOpenListings: args.countOpenListings ?? options.countOpenListings,
      }),

    /**
     * Sends a plan from {@link bears.planBurn}: `approve` if needed, then `burn`.
     * @returns The results and the `BearActivated` it produced.
     * @throws {ClientRefusal} With the plan's code when the plan was a refusal.
     * @throws {MintABearError} What the chain refused; `completed` lists an `approve` already mined.
     */
    executeBurn: async (plan: BurnPlan): Promise<BurnResult> => {
      if (!plan.ok) throw new ClientRefusal(plan.code, { ...plan.details });
      const results = await executePlan(publicClient, wallet(), plan.calls, executeOptions);
      const burn = results.at(-1)!;
      const event = decodeSystemLogs(burn.receipt.logs, addresses).find((e) => e.emitter === "activation" && e.eventName === "BearActivated");
      if (!event || event.emitter !== "activation" || event.eventName !== "BearActivated") {
        throw new MintABearError("UNKNOWN_ERROR", { context: "burn", details: { reason: "The burn was mined without a BearActivated event." } });
      }
      const { tokenId, previousLevel, newLevel, amount, cumulative } = event.args;
      return { results, activated: { tokenId, previousLevel, newLevel, amount, cumulative } };
    },

    /**
     * Plans and sends a burn to `targetLevel` in one call, without showing warnings — for scripts
     * and tests. A page should use `planBurn`, show the warnings, then `executeBurn`.
     * @throws {ClientRefusal} With the refusal's code (`ALREADY_MAX_LEVEL`, `NOT_BEAR_OWNER`, …).
     */
    burnTo: async (args: { tokenId: bigint; targetLevel: number }): Promise<BurnResult> => bears.executeBurn(await bears.planBurn(args)),

    /** Links `tokenId` to the connected wallet's Status boost; replaces any earlier link. */
    link: (tokenId: bigint) => send(linkCall(addresses, tokenId)),
    /** Removes the connected wallet's link; a no-op without one. */
    unlink: () => send(unlinkCall(addresses)),
    /** The bear carrying the wallet's boost, and its level; `tokenId` 0 for none. */
    linkOf: (wallet?: Address) => readLink(publicClient, addresses, self(wallet)),
    /** `none`, `active`, or `voided` (the linked bear was sold). */
    linkStatus: (wallet?: Address) => readLinkStatus(publicClient, addresses, self(wallet), deployBlock),
    /** Whether to prompt the wallet to link `tokenId` (after a purchase or a first burn). */
    linkPrompt: (tokenId: bigint, wallet?: Address) => linkPrompt(publicClient, addresses, self(wallet), tokenId),

    /**
     * Checks a transfer from the connected wallet (or `from`). Show `plan.warnings`, then pass the
     * plan to {@link bears.executeTransfer}.
     * @throws {ClientRefusal} `SELF_TRANSFER` or `BURN_DISABLED`.
     */
    planTransfer: (args: { to: Address; tokenId: bigint; from?: Address; safe?: boolean }): Promise<TransferPlan> =>
      planTransfer(publicClient, addresses, { ...args, from: self(args.from) }),
    /** Sends a plan from {@link bears.planTransfer}. */
    executeTransfer: (plan: TransferPlan) => send(plan.call),
  };

  return {
    /** The options' addresses. */
    addresses,

    mint: {
      /** The public stage: price (wei per bear), window, per-wallet limit. */
      publicStage: () => readPublicDrop(publicClient, addresses),
      /**
       * Mints in the public stage at its current price.
       * @param args - Quantity; optionally a recipient (the sender must then be an allowed payer) and a fee recipient.
       * @returns The result and the ids minted.
       */
      public: async (args: { quantity: bigint; minter?: Address; feeRecipient?: Address }): Promise<MintResult> => {
        const { mintPrice } = await readPublicDrop(publicClient, addresses);
        const result = await send(mintPublicCall(addresses, { quantity: args.quantity, mintPrice, minter: args.minter, feeRecipient: feeRecipientOf(args.feeRecipient) }));
        return { ...result, tokenIds: mintedIds(result, args.minter ?? wallet().account.address) };
      },
      /**
       * Mints in the whitelist stage with the wallet's entry from `whitelist.allowList(stage).entry(wallet)`.
       * @returns The result and the ids minted.
       */
      allowList: async (args: { quantity: bigint; mintParams: MintParams; proof: readonly Hex[]; minter?: Address; feeRecipient?: Address }): Promise<MintResult> => {
        const result = await send(mintAllowListCall(addresses, { ...args, feeRecipient: feeRecipientOf(args.feeRecipient) }));
        return { ...result, tokenIds: mintedIds(result, args.minter ?? wallet().account.address) };
      },
      /** Whether `allowList` is the one Studio set on SeaDrop. */
      allowListMatchesChain: (allowList: AllowList) => allowListMatchesChain(publicClient, addresses, allowList),
      /** Bears minted to the wallet, supply, and the advertised maximum. */
      stats: (wallet?: Address) => readMintStats(publicClient, addresses, self(wallet)),
      /** Whitelist mints left: the wallet's allocations minus every bear already minted to it. */
      remainingWhitelistMints: async (wallet?: Address) => {
        const who = self(wallet);
        const [allocations, stats] = await Promise.all([readClaimsOf(publicClient, addresses.registry, who), readMintStats(publicClient, addresses, who)]);
        return remainingWhitelistMints(allocations, stats.numberMinted);
      },
    },

    whitelist: {
      /** Spots left of 1,000, the window, and the signer. */
      campaign: () => readCampaign(publicClient, addresses.registry),
      /** Whether claims are accepted now (by the latest block's time). */
      isOpen: async () => {
        const [campaign, block] = await Promise.all([readCampaign(publicClient, addresses.registry), publicClient.getBlock()]);
        return campaignOpen(campaign, block.timestamp);
      },
      /** The wallet's allocations, 0–2. */
      claimsOf: (wallet?: Address) => readClaimsOf(publicClient, addresses.registry, self(wallet)),
      /** The account's allocations, 0–2. */
      accountClaims: (account: Hex) => readAccountClaims(publicClient, addresses.registry, account),
      /** Every claimant with its allocations. */
      claimants: () => readClaimants(publicClient, addresses.registry),
      /** The allowlist for the whitelist stage, from the claimants and the stage as Studio set it. */
      allowList: async (stage: StageParams) => buildAllowList(await readClaimants(publicClient, addresses.registry), stage),
      /**
       * Claims a spot with the voucher and signature MINT's backend returned. The connected wallet must be `voucher.wallet`.
       * @returns The result, the spot number and the allocation index.
       */
      claim: async (args: { voucher: Voucher; signature: Hex }): Promise<ClaimResult> => {
        const result = await send(claimCall(addresses.registry, args.voucher, args.signature));
        const claimed = result.events.find((e) => e.eventName === "WhitelistClaimed");
        if (!claimed || claimed.eventName !== "WhitelistClaimed") {
          throw new MintABearError("UNKNOWN_ERROR", { context: "claim", details: { reason: "The claim was mined without a WhitelistClaimed event." } });
        }
        return { ...result, spotNumber: claimed.args.spotNumber, allocationIndex: claimed.args.allocationIndex };
      },
    },

    bears,

    events: {
      /** Every event of the system from `fromBlock` (default: the deployment block). */
      read: (fromBlock: bigint = deployBlock, toBlock?: bigint): Promise<SystemEvent[]> => readSystemEvents(publicClient, addresses, fromBlock, toBlock),
      /** Decodes a receipt's or a log query's logs by emitter. */
      decode: (logs: readonly Log[]) => decodeSystemLogs(logs, addresses),
      /** A {@link ReferenceIndexer} fed every event up to `toBlock`. */
      index: async (toBlock?: bigint) => new ReferenceIndexer().applyAll(await readSystemEvents(publicClient, addresses, deployBlock, toBlock)),
    },

    split: {
      /** Each owned bear's owner and weight at `closingBlock` (needs an archive node). */
      rows: async (args: { closingBlock: bigint } & SplitMode): Promise<BearRow[]> =>
        args.mode === "snapshot"
          ? (await rowsFromSnapshot(publicClient, addresses, { closingBlock: args.closingBlock, gasBudget: args.gasBudget })).rows
          : rowsFromEvents(publicClient, addresses, { fromBlock: deployBlock, closingBlock: args.closingBlock, blockRange: args.blockRange }),
      /** The split of `funding` over `rows`; see `computeSplit`. */
      compute: computeSplit,
      /** Reads the rows at `closingBlock` and splits `funding` over them. */
      run: async (args: { closingBlock: bigint; funding: bigint; carriedIn?: bigint } & SplitMode): Promise<SplitResult> => {
        const rows =
          args.mode === "snapshot"
            ? (await rowsFromSnapshot(publicClient, addresses, { closingBlock: args.closingBlock, gasBudget: args.gasBudget })).rows
            : await rowsFromEvents(publicClient, addresses, { fromBlock: deployBlock, closingBlock: args.closingBlock, blockRange: args.blockRange });
        return computeSplit(rows, args.funding, { carriedIn: args.carriedIn });
      },
    },

    units: {
      /** $MNTD's decimals, read once from `Activation`. */
      decimals: () => (decimals ??= readMntdDecimals(publicClient, addresses)),
      /** A $MNTD amount (base units) as a decimal string, at the chain's decimals. */
      formatMntd: async (amount: bigint) => formatMntd(amount, await (decimals ??= readMntdDecimals(publicClient, addresses))),
      /** A decimal $MNTD string as base units, at the chain's decimals. */
      parseMntd: async (text: string) => parseMntd(text, await (decimals ??= readMntdDecimals(publicClient, addresses))),
    },
  };
}

/** The facade's type. */
export type MintABearClient = ReturnType<typeof createMintABearClient>;
