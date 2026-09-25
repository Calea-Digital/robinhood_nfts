import {
  encodeFunctionData,
  type Abi,
  type Account,
  type Address,
  type Chain,
  type Hex,
  type PublicClient,
  type TransactionReceipt,
  type Transport,
  type WalletClient,
} from "viem";

import { allErrorsAbi, ContractRevertError, decodeRevert } from "./errors.js";

/**
 * One contract call, as every write builder in this library returns it. It is also a valid
 * argument to viem's `writeContract` and `simulateContract`, and `toTransaction` turns it into the
 * `{ to, data, value }` a smart wallet batches (Privy smart wallets: `sendTransaction({ calls })`).
 */
export interface Call {
  address: Address;
  abi: Abi;
  functionName: string;
  args: readonly unknown[];
  value?: bigint;
}

/** The raw transaction for a call. */
export function toTransaction(call: Call): { to: Address; data: Hex; value: bigint } {
  return {
    to: call.address,
    data: encodeFunctionData({ abi: call.abi, functionName: call.functionName, args: call.args }),
    value: call.value ?? 0n,
  };
}

export interface ExecuteOptions {
  /** Errors of contracts outside this library (a token's own) to decode as well. */
  extraErrors?: Abi;
}

function withErrors(call: Call, options?: ExecuteOptions): Abi {
  return [...call.abi, ...allErrorsAbi, ...(options?.extraErrors ?? [])];
}

/**
 * Simulates `call` from `account` and throws `ContractRevertError`, with the revert decoded, if it
 * would revert. Nothing is sent; use it to show a holder why a button is disabled.
 */
export async function simulate(
  publicClient: PublicClient<Transport, Chain | undefined>,
  account: Address | Account,
  call: Call,
  options?: ExecuteOptions,
): Promise<void> {
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
    const revert = decodeRevert(error);
    if (revert) throw new ContractRevertError(call.functionName, revert, error);
    throw error;
  }
}

/**
 * Simulates `call`, sends it from the wallet's account and waits for the receipt. Any revert —
 * in simulation or on chain — is thrown as `ContractRevertError` with its name decoded, so a
 * caller switches on `error.revert.name`.
 */
export async function execute(
  publicClient: PublicClient<Transport, Chain | undefined>,
  wallet: WalletClient<Transport, Chain | undefined, Account>,
  call: Call,
  options?: ExecuteOptions,
): Promise<TransactionReceipt> {
  const abi = withErrors(call, options);
  try {
    const { request } = await publicClient.simulateContract({
      address: call.address,
      abi,
      functionName: call.functionName,
      args: call.args,
      value: call.value,
      account: wallet.account,
    });
    const hash = await wallet.writeContract({ ...request, chain: wallet.chain } as Parameters<typeof wallet.writeContract>[0]);
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    if (receipt.status !== "success") {
      throw new ContractRevertError(call.functionName, { name: undefined, args: [] }, receipt);
    }
    return receipt;
  } catch (error) {
    if (error instanceof ContractRevertError) throw error;
    const revert = decodeRevert(error);
    if (revert) throw new ContractRevertError(call.functionName, revert, error);
    throw error;
  }
}
