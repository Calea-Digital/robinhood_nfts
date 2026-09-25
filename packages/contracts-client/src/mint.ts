import { zeroAddress, type Address, type Chain, type Hex, type PublicClient, type Transport } from "viem";

import { mintABearAbi, seaDropAbi } from "./abi/index.js";
import type { AllowList, MintParams } from "./allowlist.js";
import type { Call } from "./calls.js";
import { SEADROP_ADDRESS } from "./constants.js";

type Client = PublicClient<Transport, Chain | undefined>;

/** Where the collection and its minter live. `seaDrop` defaults to OpenSea's canonical SeaDrop. */
export interface CollectionAddresses {
  bears: Address;
  seaDrop?: Address;
}

const seaDropOf = (c: CollectionAddresses): Address => c.seaDrop ?? SEADROP_ADDRESS;

/**
 * The reverts a mint through SeaDrop can meet, as a caller handles them. While `maxSupply` is
 * 4,444, SeaDrop's `MintQuantityExceedsMaxSupply` fires before the collection's own
 * `ExceedsMaxBears`, which binds only if Studio ever raises `maxSupply` (COL-2).
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

/** The public stage as SeaDrop holds it for the collection. */
export async function readPublicDrop(client: Client, c: CollectionAddresses) {
  return client.readContract({ address: seaDropOf(c), abi: seaDropAbi, functionName: "getPublicDrop", args: [c.bears] });
}

/** The allowlist root Studio set on SeaDrop for the collection. */
export async function readAllowListRoot(client: Client, c: CollectionAddresses): Promise<Hex> {
  return client.readContract({ address: seaDropOf(c), abi: seaDropAbi, functionName: "getAllowListMerkleRoot", args: [c.bears] });
}

/** True when `allowList` is the one Studio set: a proof from it will verify on SeaDrop. */
export async function allowListMatchesChain(client: Client, c: CollectionAddresses, allowList: AllowList): Promise<boolean> {
  return (await readAllowListRoot(client, c)).toLowerCase() === allowList.root.toLowerCase();
}

/** `getMintStats`: how many bears `minter` has minted, how many exist, and the advertised `maxSupply`. */
export async function readMintStats(client: Client, c: CollectionAddresses, minter: Address) {
  const [numberMinted, totalSupply, maxSupply] = await client.readContract({
    address: c.bears,
    abi: mintABearAbi,
    functionName: "getMintStats",
    args: [minter],
  });
  return { numberMinted, totalSupply, maxSupply };
}

/**
 * Whitelist mints left to a claimant: `allocations − numberMinted`, never below zero. SeaDrop's
 * per-wallet limit counts every mint to the wallet in any stage, so a public mint made first uses
 * up an allocation too (WL-4).
 */
export function remainingWhitelistMints(allocations: number | bigint, numberMinted: bigint): bigint {
  const left = BigInt(allocations) - numberMinted;
  return left > 0n ? left : 0n;
}

/** `remainingWhitelistMints` read from the chain for `wallet`. */
export async function readRemainingWhitelistMints(
  client: Client,
  c: CollectionAddresses,
  wallet: Address,
  allocations: number | bigint,
): Promise<bigint> {
  return remainingWhitelistMints(allocations, (await readMintStats(client, c, wallet)).numberMinted);
}

export interface MintPublicArgs {
  /** The fee recipient Studio allows for the drop (OpenSea's). */
  feeRecipient: Address;
  quantity: bigint;
  /** The stage's price per bear (`readPublicDrop(...).mintPrice`); the call pays `mintPrice × quantity`. */
  mintPrice: bigint;
  /** The recipient when it is not the payer; omit to mint to the sender. */
  minter?: Address;
}

/** `SeaDrop.mintPublic` for the collection. */
export function mintPublicCall(c: CollectionAddresses, a: MintPublicArgs) {
  return {
    address: seaDropOf(c),
    abi: seaDropAbi,
    functionName: "mintPublic",
    args: [c.bears, a.feeRecipient, a.minter ?? zeroAddress, a.quantity],
    value: a.mintPrice * a.quantity,
  } as const satisfies Call;
}

export interface MintAllowListArgs {
  feeRecipient: Address;
  quantity: bigint;
  /** The row's mint params and proof, from `AllowList.entry(wallet)`. */
  mintParams: MintParams;
  proof: readonly Hex[];
  minter?: Address;
}

/**
 * `SeaDrop.mintAllowList` for the collection. The whitelist stage is Studio's first stage open to
 * non-team wallets (WL-4). The proof is for the minter's address, which for a smart wallet is the
 * smart account, not its signer.
 */
export function mintAllowListCall(c: CollectionAddresses, a: MintAllowListArgs) {
  return {
    address: seaDropOf(c),
    abi: seaDropAbi,
    functionName: "mintAllowList",
    args: [c.bears, a.feeRecipient, a.minter ?? zeroAddress, a.quantity, a.mintParams, a.proof],
    value: a.mintParams.mintPrice * a.quantity,
  } as const satisfies Call;
}
