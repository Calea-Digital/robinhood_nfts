/**
 * Minting through SeaDrop.
 *
 * Bears are minted by OpenSea's SeaDrop, never by the collection directly. Studio configures two
 * kinds of stage: the public stage (`mintPublic`) and allowlist stages (`mintAllowList`, with a
 * Merkle proof). The whitelist stage is Studio's first stage open to non-team wallets (WL-4):
 * SeaDrop's per-wallet limit counts every mint to a wallet in any stage.
 *
 * The facade's `mintabear.mint` wraps these with the price read for you.
 *
 * @module
 */
import { zeroAddress, type Address, type Hex } from "viem";

import { mintABearAbi, seaDropAbi } from "./abi/index.js";
import { seaDropOf, type MintABearAddresses } from "./addresses.js";
import type { AllowList, MintParams } from "./allowlist.js";
import type { AnyPublicClient, Call } from "./calls.js";

/** The addresses a mint needs: the collection, and SeaDrop (canonical when omitted). */
export type CollectionAddresses = Pick<MintABearAddresses, "bears" | "seaDrop">;

/**
 * The contract errors a mint can meet. While `maxSupply` is 4,444, SeaDrop's
 * `MintQuantityExceedsMaxSupply` fires before the collection's own `ExceedsMaxBears`, which binds only
 * if Studio ever raises `maxSupply` (COL-2). Each maps to a code in `REVERT_CODES`.
 */
export const MINT_REVERTS = [
  "NotActive",
  "MintQuantityCannotBeZero",
  "MintQuantityExceedsMaxMintedPerWallet",
  "MintQuantityExceedsMaxSupply",
  "MintQuantityExceedsMaxTokenSupplyForStage",
  "IncorrectPayment",
  "InvalidProof",
  "FeeRecipientNotAllowed",
  "FeeRecipientCannotBeZeroAddress",
  "PayerNotAllowed",
  "ExceedsMaxBears",
] as const;

/** The public stage as SeaDrop holds it. Times are Unix seconds; `mintPrice` is wei per bear. */
export interface PublicStage {
  mintPrice: bigint;
  startTime: bigint;
  endTime: bigint;
  /** Most bears one wallet may mint across all stages. */
  maxTotalMintableByWallet: number;
  feeBps: number;
  restrictFeeRecipients: boolean;
}

/**
 * The public stage SeaDrop holds for the collection.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The collection (and SeaDrop).
 * @returns The stage: price, window, per-wallet limit, fee settings.
 */
export async function readPublicDrop(client: AnyPublicClient, addresses: CollectionAddresses): Promise<PublicStage> {
  const d = await client.readContract({ address: seaDropOf(addresses), abi: seaDropAbi, functionName: "getPublicDrop", args: [addresses.bears] });
  return {
    mintPrice: d.mintPrice,
    startTime: BigInt(d.startTime),
    endTime: BigInt(d.endTime),
    maxTotalMintableByWallet: d.maxTotalMintableByWallet,
    feeBps: d.feeBps,
    restrictFeeRecipients: d.restrictFeeRecipients,
  };
}

/**
 * The allowlist root Studio set on SeaDrop for the collection.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The collection (and SeaDrop).
 */
export async function readAllowListRoot(client: AnyPublicClient, addresses: CollectionAddresses): Promise<Hex> {
  return client.readContract({ address: seaDropOf(addresses), abi: seaDropAbi, functionName: "getAllowListMerkleRoot", args: [addresses.bears] });
}

/**
 * Whether `allowList` is the one Studio set, so its proofs will verify on SeaDrop.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The collection (and SeaDrop).
 * @param allowList - From `buildAllowList`.
 * @returns `true` when the roots match.
 */
export async function allowListMatchesChain(client: AnyPublicClient, addresses: CollectionAddresses, allowList: AllowList): Promise<boolean> {
  return (await readAllowListRoot(client, addresses)).toLowerCase() === allowList.root.toLowerCase();
}

/** A wallet's mint count and the collection's supply. */
export interface MintStats {
  /** Bears minted to the wallet, in every stage. */
  numberMinted: bigint;
  /** Bears in existence. */
  totalSupply: bigint;
  /** The advertised maximum (4,444). */
  maxSupply: bigint;
}

/**
 * The collection's `getMintStats` for `minter`.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The collection.
 * @param minter - The wallet.
 */
export async function readMintStats(client: AnyPublicClient, addresses: Pick<MintABearAddresses, "bears">, minter: Address): Promise<MintStats> {
  const [numberMinted, totalSupply, maxSupply] = await client.readContract({
    address: addresses.bears,
    abi: mintABearAbi,
    functionName: "getMintStats",
    args: [minter],
  });
  return { numberMinted, totalSupply, maxSupply };
}

/**
 * Whitelist mints left to a claimant: `allocations − numberMinted`, never below zero. A public mint
 * made first uses up an allocation too (WL-4).
 *
 * @param allocations - The wallet's allocations (1 or 2).
 * @param numberMinted - From {@link readMintStats}.
 */
export function remainingWhitelistMints(allocations: number | bigint, numberMinted: bigint): bigint {
  const left = BigInt(allocations) - numberMinted;
  return left > 0n ? left : 0n;
}

/**
 * {@link remainingWhitelistMints} read from the chain.
 *
 * @param client - Any viem public client on the chain.
 * @param addresses - The collection.
 * @param wallet - The claimant.
 * @param allocations - Its allocations (`readClaimsOf`).
 */
export async function readRemainingWhitelistMints(
  client: AnyPublicClient,
  addresses: Pick<MintABearAddresses, "bears">,
  wallet: Address,
  allocations: number | bigint,
): Promise<bigint> {
  return remainingWhitelistMints(allocations, (await readMintStats(client, addresses, wallet)).numberMinted);
}

/** Arguments of {@link mintPublicCall}. */
export interface MintPublicArgs {
  /** The fee recipient Studio allows for the drop (OpenSea's). */
  feeRecipient: Address;
  /** Bears to mint. */
  quantity: bigint;
  /** The stage's price per bear in wei (`readPublicDrop(...).mintPrice`). The call pays `mintPrice × quantity`. */
  mintPrice: bigint;
  /** Mint to this address instead of the sender. The sender must then be an allowed payer. */
  minter?: Address;
}

/**
 * The `SeaDrop.mintPublic` call.
 *
 * @param addresses - The collection (and SeaDrop).
 * @param args - Fee recipient, quantity, price and optional recipient.
 * @returns A {@link Call} paying exactly `mintPrice × quantity`.
 *
 * @example
 * ```ts
 * const stage = await readPublicDrop(client, addresses);
 * await execute(client, wallet, mintPublicCall(addresses, { feeRecipient, quantity: 2n, mintPrice: stage.mintPrice }));
 * ```
 */
export function mintPublicCall(addresses: CollectionAddresses, args: MintPublicArgs) {
  return {
    address: seaDropOf(addresses),
    abi: seaDropAbi,
    functionName: "mintPublic",
    args: [addresses.bears, args.feeRecipient, args.minter ?? zeroAddress, args.quantity],
    value: args.mintPrice * args.quantity,
  } as const satisfies Call;
}

/** Arguments of {@link mintAllowListCall}. */
export interface MintAllowListArgs {
  /** The fee recipient Studio allows for the drop. */
  feeRecipient: Address;
  /** Bears to mint; at most the wallet's remaining whitelist mints. */
  quantity: bigint;
  /** The wallet's mint params, from `AllowList.entry(wallet)`. */
  mintParams: MintParams;
  /** The wallet's proof, from `AllowList.entry(wallet)`. */
  proof: readonly Hex[];
  /** Mint to this address instead of the sender (an allowed payer only). */
  minter?: Address;
}

/**
 * The `SeaDrop.mintAllowList` call. The proof is for the minter's address — for a smart wallet,
 * the smart account, not its signer.
 *
 * @param addresses - The collection (and SeaDrop).
 * @param args - Fee recipient, quantity, and the wallet's entry from the allowlist.
 * @returns A {@link Call} paying `mintParams.mintPrice × quantity`.
 */
export function mintAllowListCall(addresses: CollectionAddresses, args: MintAllowListArgs) {
  return {
    address: seaDropOf(addresses),
    abi: seaDropAbi,
    functionName: "mintAllowList",
    args: [addresses.bears, args.feeRecipient, args.minter ?? zeroAddress, args.quantity, args.mintParams, args.proof],
    value: args.mintParams.mintPrice * args.quantity,
  } as const satisfies Call;
}
