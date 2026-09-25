import { BaseError, ContractFunctionRevertedError, type Abi, type Hex } from "viem";

import { activationAbi, mintABearAbi, seaDropAbi, whitelistClaimAbi } from "./abi/index.js";

/**
 * OpenZeppelin v5's ERC-20 errors. `Activation` calls $MNTD's `burnFrom` (OpenZeppelin
 * `ERC20Burnable`), which reverts with one of these when the allowance or the balance is short;
 * an OpenZeppelin v4 token reverts with a string instead, which decodes as `Error`.
 */
export const erc20ErrorsAbi = [
  {
    type: "error",
    name: "ERC20InsufficientAllowance",
    inputs: [
      { name: "spender", type: "address" },
      { name: "allowance", type: "uint256" },
      { name: "needed", type: "uint256" },
    ],
  },
  {
    type: "error",
    name: "ERC20InsufficientBalance",
    inputs: [
      { name: "sender", type: "address" },
      { name: "balance", type: "uint256" },
      { name: "needed", type: "uint256" },
    ],
  },
] as const;

type AbiError = Extract<Abi[number], { type: "error" }>;

type ErrorsOf<T extends readonly unknown[]> = Extract<T[number], { type: "error" }>;

/** Every custom error a call through this library can revert with, whichever contract raised it. */
export type KnownErrorName =
  | ErrorsOf<typeof mintABearAbi>["name"]
  | ErrorsOf<typeof whitelistClaimAbi>["name"]
  | ErrorsOf<typeof activationAbi>["name"]
  | ErrorsOf<typeof seaDropAbi>["name"]
  | ErrorsOf<typeof erc20ErrorsAbi>["name"];

function signature(error: AbiError): string {
  return `${error.name}(${error.inputs.map((input) => input.type).join(",")})`;
}

/**
 * The errors of every contract in one ABI. A revert bubbles up through the call stack unchanged
 * (`Activation.burn` of an unminted id reverts with the collection's
 * `OwnerQueryForNonexistentToken`), so decoding needs all of them, not only the called
 * contract's.
 */
export const allErrorsAbi: readonly AbiError[] = (() => {
  const seen = new Map<string, AbiError>();
  for (const abi of [mintABearAbi, whitelistClaimAbi, activationAbi, seaDropAbi, erc20ErrorsAbi] as readonly Abi[]) {
    for (const item of abi) {
      if (item.type === "error" && !seen.has(signature(item))) seen.set(signature(item), item);
    }
  }
  return [...seen.values()];
})();

/**
 * A decoded revert. `name` is the custom error's name, `Error` for a revert string (with the
 * reason as `args[0]`), `Panic` for a panic code, or `undefined` when the selector is not one
 * this library knows — `raw` then carries the revert data for the caller to decode.
 */
export interface Revert {
  name: KnownErrorName | "Error" | "Panic" | (string & {}) | undefined;
  args: readonly unknown[];
  raw?: Hex;
}

/** Extracts the revert from anything viem throws for a failed call, or `undefined` if it was not a revert. */
export function decodeRevert(error: unknown): Revert | undefined {
  if (!(error instanceof BaseError)) return undefined;
  const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError);
  if (!(reverted instanceof ContractFunctionRevertedError)) return undefined;
  if (reverted.data) return { name: reverted.data.errorName, args: reverted.data.args ?? [], raw: reverted.raw };
  if (reverted.reason !== undefined) return { name: "Error", args: [reverted.reason], raw: reverted.raw };
  return { name: undefined, args: [], raw: reverted.raw };
}

/** Thrown by `execute` when a call reverts in simulation or on chain; `revert` is decoded. */
export class ContractRevertError extends Error {
  override readonly name = "ContractRevertError";
  constructor(
    readonly functionName: string,
    readonly revert: Revert,
    override readonly cause: unknown,
  ) {
    super(`${functionName} reverted: ${revert.name ?? revert.raw ?? "unknown"}`);
  }
}

/** Thrown by a client-side guard before anything is sent (for example a transfer to oneself). */
export class ClientRefusal extends Error {
  override readonly name = "ClientRefusal";
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}
