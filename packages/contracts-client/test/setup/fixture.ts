import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  createPublicClient,
  createTestClient,
  createWalletClient,
  getAddress,
  http,
  type Abi,
  type Address,
  type Hex,
  type PublicClient,
  type TestClient,
  type WalletClient,
  type Chain,
  type Transport,
  type Account,
} from "viem";
import { foundry } from "viem/chains";
import { mnemonicToAccount, type HDAccount } from "viem/accounts";

import { mintABearAbi, seaDropAbi } from "../../src/abi/index.js";

const repo = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..", "..");

/** Reads a Foundry artifact from the repository's `out/` (run `forge build` first). */
export function artifact(name: string): { abi: Abi; bytecode: Hex } {
  const json = JSON.parse(readFileSync(join(repo, "out", `${name}.sol`, `${name}.json`), "utf8"));
  return { abi: json.abi as Abi, bytecode: json.bytecode.object as Hex };
}

const MNEMONIC = "test test test test test test test test test test test junk";

/** anvil's default accounts, by role. */
export const accounts = {
  deployer: mnemonicToAccount(MNEMONIC, { addressIndex: 0 }),
  signer: mnemonicToAccount(MNEMONIC, { addressIndex: 1 }),
  alice: mnemonicToAccount(MNEMONIC, { addressIndex: 2 }),
  bob: mnemonicToAccount(MNEMONIC, { addressIndex: 3 }),
  carol: mnemonicToAccount(MNEMONIC, { addressIndex: 4 }),
  feeRecipient: mnemonicToAccount(MNEMONIC, { addressIndex: 5 }),
  payout: mnemonicToAccount(MNEMONIC, { addressIndex: 6 }),
} satisfies Record<string, HDAccount>;

/** The specified thresholds and weights (ACT-2, ACT-3), as `script/config/example.json` has them. */
export const THRESHOLDS_WHOLE = [1666n, 3333n, 8333n, 16666n, 41666n] as const;
export const WEIGHTS = [100, 110, 125, 145, 170, 200] as const;
export const UNIT = 10n ** 18n;

export type Wallet = WalletClient<Transport, Chain, Account>;

export interface Fixture {
  publicClient: PublicClient<Transport, Chain>;
  testClient: TestClient<"anvil", Transport, Chain>;
  wallet: (account: HDAccount) => Wallet;
  seaDrop: Address;
  bears: Address;
  mntd: Address;
  validator: Address;
  registry: Address;
  activation: Address;
  openAt: bigint;
  closeAt: bigint;
}

/**
 * Deploys the tranche-1 system on a fresh anvil chain from the Foundry artifacts: a real SeaDrop
 * (at an ordinary address, passed to the library as configuration), the collection with that
 * SeaDrop as its only minter and `maxSupply` 4,444, the V3 stand-in as its transfer validator, an
 * 18-decimal $MNTD stand-in, the whitelist registry with a window open now for seven days, and
 * `Activation` unpaused with the specified thresholds and weights.
 */
export async function deployFixture(rpcUrl: string): Promise<Fixture> {
  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain: foundry, transport });
  const testClient = createTestClient({ chain: foundry, mode: "anvil", transport });
  const wallet = (account: HDAccount): Wallet => createWalletClient({ chain: foundry, transport, account });
  const deployer = wallet(accounts.deployer);

  async function deploy(name: string, args: readonly unknown[] = []): Promise<Address> {
    const { abi, bytecode } = artifact(name);
    const hash = await deployer.deployContract({ abi, bytecode, args });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (!receipt.contractAddress) throw new Error(`${name} not deployed`);
    return getAddress(receipt.contractAddress);
  }

  async function send(address: Address, abi: Abi, functionName: string, args: readonly unknown[]): Promise<void> {
    const hash = await deployer.writeContract({ address, abi, functionName, args });
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== "success") throw new Error(`${functionName} reverted`);
  }

  const seaDrop = await deploy("SeaDrop");
  const validator = await deploy("MockTransferValidator");
  const mntd = await deploy("MockMNTD", [18]);
  const bears = await deploy("MintABear", ["MintABear", "BEAR", [seaDrop]]);
  await send(bears, mintABearAbi, "setMaxSupply", [4444n]);
  await send(bears, mintABearAbi, "setTransferValidator", [validator]);

  const now = (await publicClient.getBlock()).timestamp;
  const openAt = now;
  const closeAt = now + 7n * 86_400n;
  const registry = await deploy("WhitelistClaim", [accounts.deployer.address, accounts.signer.address, openAt, closeAt]);
  const activation = await deploy("Activation", [bears, mntd, THRESHOLDS_WHOLE, WEIGHTS]);

  return { publicClient, testClient, wallet, seaDrop, bears, mntd, validator, registry, activation, openAt, closeAt };
}

/** The $MNTD stand-in's ABI (test/mocks/MockMNTD.sol): `mint` for funding test holders. */
export const mockMntdAbi = artifact("MockMNTD").abi;

/**
 * Opens a free public stage on SeaDrop (payout and fee recipient set, up to 65,535 per wallet) so
 * tests can mint bears the way holders do.
 */
export async function openFreeMint(f: Fixture): Promise<void> {
  const deployer = f.wallet(accounts.deployer);
  const now = (await f.publicClient.getBlock()).timestamp;
  const calls: [string, readonly unknown[]][] = [
    ["updateCreatorPayoutAddress", [f.seaDrop, accounts.payout.address]],
    ["updateAllowedFeeRecipient", [f.seaDrop, accounts.feeRecipient.address, true]],
    [
      "updatePublicDrop",
      [
        f.seaDrop,
        { mintPrice: 0n, startTime: now, endTime: now + 365n * 86_400n, maxTotalMintableByWallet: 65_535, feeBps: 0, restrictFeeRecipients: true },
      ],
    ],
  ];
  for (const [functionName, args] of calls) {
    const hash = await deployer.writeContract({ address: f.bears, abi: mintABearAbi, functionName: functionName as "updatePublicDrop", args: args as never });
    await f.publicClient.waitForTransactionReceipt({ hash });
  }
}

/** Mints `quantity` bears to `account` through SeaDrop's public stage (after `openFreeMint`). */
export async function mintBears(f: Fixture, account: HDAccount, quantity: bigint): Promise<void> {
  const hash = await f.wallet(account).writeContract({
    address: f.seaDrop,
    abi: seaDropAbi,
    functionName: "mintPublic",
    args: [f.bears, accounts.feeRecipient.address, "0x0000000000000000000000000000000000000000", quantity],
  });
  const receipt = await f.publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("mint reverted");
}

/** Gives `account` `whole` $MNTD from the stand-in (no approval). */
export async function fundMntd(f: Fixture, account: Address, whole: bigint): Promise<void> {
  const hash = await f.wallet(accounts.deployer).writeContract({
    address: f.mntd,
    abi: mockMntdAbi,
    functionName: "mint",
    args: [account, whole * UNIT],
  });
  await f.publicClient.waitForTransactionReceipt({ hash });
}
