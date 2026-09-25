/**
 * The one piece of plumbing the examples share: a local chain with the MintABear contracts
 * deployed, standing in for Robinhood Chain.
 *
 * On getminted.io you would not call any of this. You would build the two viem clients from Privy
 * and take the addresses from `getDeployment`:
 *
 * ```ts
 * const provider = await privyWallet.getEthereumProvider();
 * const publicClient = createPublicClient({ chain: robinhoodChain, transport: http() });
 * const walletClient = createWalletClient({ chain: robinhoodChain, transport: custom(provider), account: privyWallet.address as Address });
 * const addresses = getDeployment(robinhoodChain.id);
 * ```
 *
 * Here `wallet("alice")` plays the part of `walletClient`, and `studio`, `admin` and `faucet` do what
 * OpenSea Studio, MINT's admin and the $MNTD market do on the real chain.
 */
import { zeroAddress, type Address } from "viem";

import type { MintABearAddresses, StageParams } from "@mintabear/contracts-client";
import { activationAbi, mintABearAbi } from "@mintabear/contracts-client";

import { startAnvil } from "../test/setup/anvil.js";
import { accounts, deployFixture, fundMntd, UNIT } from "../test/setup/fixture.js";

export type Holder = "alice" | "bob" | "carol";

export async function localChain() {
  const anvil = await startAnvil();
  const f = await deployFixture(anvil.rpcUrl, { mntd: "oz" });
  const deployBlock = 0n;
  const addresses: Required<MintABearAddresses> = { bears: f.bears, activation: f.activation, registry: f.registry, mntd: f.mntd, seaDrop: f.seaDrop };
  const owner = f.wallet(accounts.deployer);
  const configure = async (functionName: string, args: readonly unknown[]) => {
    const hash = await owner.writeContract({ address: f.bears, abi: mintABearAbi, functionName: functionName as "updatePublicDrop", args: args as never });
    await f.publicClient.waitForTransactionReceipt({ hash });
  };
  const now = async () => (await f.publicClient.getBlock()).timestamp;
  await configure("updateCreatorPayoutAddress", [f.seaDrop, accounts.payout.address]);
  await configure("updateAllowedFeeRecipient", [f.seaDrop, accounts.feeRecipient.address, true]);

  return {
    /** The node's URL (on getminted.io: Robinhood Chain's RPC, or your provider's). */
    rpcUrl: anvil.rpcUrl,
    /** The viem public client (on getminted.io: `createPublicClient({ chain: robinhoodChain, transport: http() })`). */
    publicClient: f.publicClient,
    /** A holder's wallet client (on getminted.io: the one built from Privy's provider). */
    wallet: (who: Holder) => f.wallet(accounts[who]),
    /** A holder's address. */
    address: (who: Holder): Address => accounts[who].address,
    /** The deployment (on getminted.io: `getDeployment(robinhoodChain.id)`). */
    addresses,
    deployBlock,
    /** The fee recipient Studio allows (OpenSea's, on the real drop). */
    feeRecipient: accounts.feeRecipient.address,
    /** MINT's backend eligibility signer — a private key, server-side only. */
    backendSigner: accounts.signer,
    /** A 32-byte server key for account hashes — server-side only. */
    serverKey: new Uint8Array(32).fill(42),
    /** The chain's current time, Unix seconds. */
    now,
    /** Moves the chain's clock forward. */
    advance: async (seconds: bigint) => {
      await f.testClient.setNextBlockTimestamp({ timestamp: (await now()) + seconds });
      await f.testClient.mine({ blocks: 1 });
    },

    /** What OpenSea Studio configures on SeaDrop. */
    studio: {
      openPublicStage: async (mintPrice: bigint, perWallet = 10) =>
        configure("updatePublicDrop", [
          f.seaDrop,
          { mintPrice, startTime: await now(), endTime: (await now()) + 86_400n, maxTotalMintableByWallet: perWallet, feeBps: 0, restrictFeeRecipients: true },
        ]),
      /** The whitelist stage's parameters, as Studio configures them. */
      whitelistStage: async (): Promise<StageParams> => ({
        mintPrice: 0n,
        startTime: await now(),
        endTime: (await now()) + 86_400n,
        dropStageIndex: 1n,
        maxTokenSupplyForStage: 4444n,
        feeBps: 0n,
        restrictFeeRecipients: true,
      }),
      loadAllowList: (root: `0x${string}`) => configure("updateAllowList", [f.seaDrop, { merkleRoot: root, publicKeyURIs: [], allowListURI: "" }]),
    },

    /** What MINT's admin does. */
    admin: {
      pauseActivation: async (paused: boolean) => {
        const hash = await owner.writeContract({ address: f.activation, abi: activationAbi, functionName: "setPaused", args: [paused] });
        await f.publicClient.waitForTransactionReceipt({ hash });
      },
    },

    /** Gives a holder $MNTD (on the real chain, they buy it). */
    faucet: (who: Holder, whole: bigint) => fundMntd(f, accounts[who].address, whole),
    /** One whole $MNTD in base units (18 decimals). */
    MNTD: UNIT,
    zeroAddress,

    stop: () => anvil.stop(),
  };
}

export type LocalChain = Awaited<ReturnType<typeof localChain>>;
