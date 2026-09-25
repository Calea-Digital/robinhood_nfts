/**
 * Sending calls.
 *
 * Every write in this library is first a {@link Call}: a plain object naming the contract, the
 * function and its arguments. From there:
 *
 * - {@link execute} simulates it, sends it from a wallet, waits for it and returns the receipt with
 *   the call's own events decoded — or throws a {@link MintABearError}.
 * - {@link executePlan} does the same for a list of calls in order (approve, then burn).
 * - {@link toTransaction} turns it into the raw `{ to, data, value }` a smart wallet batches
 *   (Privy smart wallets: `sendTransaction({ calls })`).
 * - {@link simulate} checks it without sending, to show a holder why a button is disabled.
 *
 * The facade (`createMintABearClient`) does all of this for you; these are for when you build your
 * own flow.
 *
 * @module
 */
import {
  encodeFunctionData,
  parseEventLogs,
  type Abi,
  type Account,
  type Address,
  type Chain,
  type Hash,
  type Hex,
  type ParseEventLogsReturnType,
  type PublicClient,
  type TransactionReceipt,
  type Transport,
  type WalletClient,
} from "viem";

import { allErrorsAbi, MintABearError, toMintABearError } from "./errors.js";

/** A viem public client on any chain. */
export type AnyPublicClient = PublicClient<Transport, Chain | undefined>;
/** A viem wallet client with an account — what Privy's provider gives you through `createWalletClient`. */
export type AnyWalletClient = WalletClient<Transport, Chain | undefined, Account>;

/**
 * One contract call, as every write builder returns it. It is also a valid argument to viem's own
 * `writeContract` and `simulateContract`.
 */
export interface Call<A extends Abi = Abi> {
  /** The contract called. */
  address: Address;
  /** Its ABI (a generated one from this package). */
  abi: A;
  /** The function called. */
  functionName: string;
  /** The function's arguments, in order. */
  args: readonly unknown[];
  /** ETH sent with the call, in wei. */
  value?: bigint;
}

/**
 * The raw transaction for a call.
 *
 * @param call - A call from one of the builders.
 * @returns `{ to, data, value }`, with `value` 0 when the call sends no ETH.
 *
 * @example
 * ```ts
 * // One user operation for approve + burn with a Privy smart wallet:
 * const plan = await mintabear.bears.planBurn({ tokenId: 7n, targetLevel: 2 });
 * if (plan.ok) await smartWallet.sendTransaction({ calls: plan.calls.map(toTransaction) });
 * ```
 */
export function toTransaction(call: Call): { to: Address; data: Hex; value: bigint } {
  return {
    to: call.address,
    data: encodeFunctionData({ abi: call.abi, functionName: call.functionName, args: call.args }),
    value: call.value ?? 0n,
  };
}

/** Options for {@link execute} and {@link simulate}. */
export interface ExecuteOptions {
  /** Errors of contracts outside this library (a token's own) to decode as well. */
  extraErrors?: Abi;
}

/** What a sent call returns. */
export interface WriteResult<A extends Abi = Abi> {
  /** The transaction hash. */
  hash: Hash;
  /** The mined receipt; its `status` is always `"success"` (a failure throws instead). */
  receipt: TransactionReceipt;
  /** The events the called contract emitted in this transaction, decoded with its ABI. */
  events: ParseEventLogsReturnType<A, undefined, true>;
}

function withErrors(call: Call, options?: ExecuteOptions): Abi {
  return [...call.abi, ...allErrorsAbi, ...(options?.extraErrors ?? [])];
}

/**
 * Checks `call` from `account` without sending it.
 *
 * @param publicClient - Any viem public client on the chain.
 * @param account - The address (or account) that would send it.
 * @param call - A call from one of the builders.
 * @throws {MintABearError} What the call would fail with: a `ContractRevertError` with the
 *   contract's reason, or another code.
 *
 * @example
 * ```ts
 * try {
 *   await simulate(publicClient, wallet, burnCall(addresses, 7n, amount));
 *   enableBurnButton();
 * } catch (error) {
 *   disableBurnButton(explainError(error).userMessage);
 * }
 * ```
 */
export async function simulate(publicClient: AnyPublicClient, account: Address | Account, call: Call, options?: ExecuteOptions): Promise<void> {
  try {
    await publicClient.simulateContract({
      address: call.address,
      abi: withErrors(call, options),
      functionName: call.functionName,
      args: call.args,
      value: call.value,
      account,
    });
  } catch (error) {
    throw toMintABearError(error, call.functionName);
  }
}

/**
 * Simulates `call`, sends it from the wallet's account and waits until it is mined.
 *
 * @param publicClient - Any viem public client on the chain.
 * @param wallet - The wallet that signs and sends (for Privy: `createWalletClient({ transport: custom(provider) })`).
 * @param call - A call from one of the builders.
 * @returns The hash, the receipt, and the called contract's events decoded.
 * @throws {MintABearError} On any failure. A contract's refusal is a `ContractRevertError` whose
 *   `code` and `userMessage` explain it; a declined wallet prompt is `USER_REJECTED`; too little ETH
 *   for gas is `INSUFFICIENT_GAS_FUNDS`.
 *
 * @example
 * ```ts
 * const { events } = await execute(publicClient, wallet, linkCall(addresses, 7n));
 * // events[0].eventName === "BearLinked"
 * ```
 */
export async function execute<A extends Abi>(
  publicClient: AnyPublicClient,
  wallet: AnyWalletClient,
  call: Call<A>,
  options?: ExecuteOptions,
): Promise<WriteResult<A>> {
  try {
    const { request } = await publicClient.simulateContract({
      address: call.address,
      abi: withErrors(call, options),
      functionName: call.functionName,
      args: call.args,
      value: call.value,
      account: wallet.account,
    });
    const hash = await wallet.writeContract({ ...request, chain: wallet.chain } as Parameters<typeof wallet.writeContract>[0]);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== "success") {
      throw new MintABearError("TRANSACTION_REVERTED", { details: { hash }, context: call.functionName });
    }
    const own = receipt.logs.filter((log) => log.address.toLowerCase() === call.address.toLowerCase());
    const events = parseEventLogs({ abi: call.abi, logs: own, strict: true }) as ParseEventLogsReturnType<A, undefined, true>;
    return { hash, receipt, events };
  } catch (error) {
    throw toMintABearError(error, call.functionName);
  }
}

/**
 * Sends `calls` one after another, each after the previous is mined — for a plan such as
 * `[approve, burn]`.
 *
 * @param publicClient - Any viem public client on the chain.
 * @param wallet - The wallet that signs and sends every call.
 * @param calls - The calls, in order.
 * @returns One {@link WriteResult} per call.
 * @throws {MintABearError} The first failure. Its `completed` field lists the results of the calls
 *   that were mined before it — for example an `approve` that went through before a `burn` failed,
 *   so the next attempt can skip it.
 *
 * @example
 * ```ts
 * const plan = await planBurn(publicClient, addresses, { tokenId: 7n, owner: account, targetLevel: 2 });
 * if (plan.ok) await executePlan(publicClient, wallet, plan.calls);
 * ```
 */
export async function executePlan(publicClient: AnyPublicClient, wallet: AnyWalletClient, calls: readonly Call[], options?: ExecuteOptions): Promise<WriteResult[]> {
  const results: WriteResult[] = [];
  for (const call of calls) {
    try {
      results.push(await execute(publicClient, wallet, call, options));
    } catch (error) {
      const failure = toMintABearError(error, call.functionName);
      failure.completed = [...results];
      throw failure;
    }
  }
  return results;
}

declare module "./errors.js" {
  interface MintABearError {
    /** Set by {@link executePlan}: the calls of the plan that were mined before this failure. */
    completed?: readonly WriteResult[];
  }
}
