/**
 * Errors, in one model.
 *
 * Everything this library throws is a {@link MintABearError}: a stable `code` to switch on, a
 * `userMessage` written for the holder, the facts behind it in `details`, and the original error
 * as `cause`. Two subclasses say where it came from:
 *
 * - {@link ContractRevertError} — a contract refused the call (in simulation or on chain);
 *   `revert.errorName` is the contract's own error name.
 * - {@link ClientRefusal} — the library refused before anything was sent (a transfer to yourself,
 *   an argument out of range, a split input that would pay the wrong people).
 *
 * A wallet that declines to sign, or has no ETH for gas, is a `MintABearError` too
 * (`USER_REJECTED`, `INSUFFICIENT_GAS_FUNDS`).
 *
 * The "plan" functions (`planBurn`, `planVoucher`) do not throw for an expected refusal; they return
 * `{ ok: false, code, userMessage }` with the **same codes**, so one table of messages serves both.
 *
 * @example
 * ```ts
 * import { explainError } from "@mintabear/contracts-client";
 *
 * try {
 *   await mintabear.bears.burnTo({ tokenId: 7n, targetLevel: 3 });
 * } catch (error) {
 *   const { code, userMessage } = explainError(error);
 *   if (code === "USER_REJECTED") return;          // the holder closed the wallet prompt
 *   toast(userMessage);                             // "This bear is already at level 5." …
 * }
 * ```
 *
 * @module
 */
import {
  BaseError,
  ContractFunctionRevertedError,
  InsufficientFundsError,
  UserRejectedRequestError,
  type Abi,
  type Hex,
} from "viem";

import { activationAbi, mintABearAbi, seaDropAbi, whitelistClaimAbi } from "./abi/index.js";

/**
 * OpenZeppelin v5's ERC-20 errors. `Activation` calls $MNTD's `burnFrom` (OpenZeppelin
 * `ERC20Burnable`), which reverts with one of these when the allowance or the balance is short;
 * an OpenZeppelin v4 token reverts with a string instead, which is recognised too.
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

/** Every custom error name a call through this library can revert with, whichever contract raised it. */
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
 * `OwnerQueryForNonexistentToken`), so decoding needs all of them, not only the called contract's.
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

// ---------------------------------------------------------------------------------------------
// Codes and messages
// ---------------------------------------------------------------------------------------------

/**
 * The stable codes a caller switches on. Contract reverts, the plans' refusals and the library's
 * own checks share them: `planBurn`'s `NOT_BEAR_OWNER` and `burn`'s `NotBearOwner` revert are one
 * code. Each has a default `userMessage` (see {@link explainError}).
 */
export type ErrorCode =
  // Minting (SeaDrop and the collection)
  | "MINT_NOT_ACTIVE"
  | "MINT_ZERO_QUANTITY"
  | "MINT_WALLET_LIMIT"
  | "MINT_EXCEEDS_SUPPLY"
  | "MINT_EXCEEDS_STAGE_SUPPLY"
  | "MINT_WRONG_PAYMENT"
  | "NOT_ON_ALLOWLIST"
  | "FEE_RECIPIENT_NOT_ALLOWED"
  | "PAYER_NOT_ALLOWED"
  // Bears (the collection)
  | "TOKEN_DOES_NOT_EXIST"
  | "NOT_TOKEN_OWNER_OR_APPROVED"
  | "BURN_DISABLED"
  | "RECEIVER_NOT_ERC721"
  | "SELF_TRANSFER"
  // Whitelist claim
  | "CLAIM_WRONG_WALLET"
  | "VOUCHER_INVALID"
  | "VOUCHER_EXPIRED"
  | "CAMPAIGN_CLOSED"
  | "WHITELIST_SOLD_OUT"
  | "WALLET_LIMIT"
  | "ACCOUNT_LIMIT"
  | "WRONG_ALLOCATION"
  | "NOT_YET_ELIGIBLE"
  // Activation: burn and link
  | "ACTIVATION_PAUSED"
  | "ZERO_AMOUNT"
  | "NOT_BEAR_OWNER"
  | "ALREADY_MAX_LEVEL"
  | "TARGET_REACHED"
  | "OVERSHOOT"
  | "INVALID_LEVEL"
  | "REENTRANCY"
  | "INSUFFICIENT_MNTD_BALANCE"
  | "INSUFFICIENT_MNTD_ALLOWANCE"
  // Owner-only functions called by someone else
  | "NOT_CONTRACT_OWNER"
  // Wallet and transaction
  | "USER_REJECTED"
  | "INSUFFICIENT_GAS_FUNDS"
  | "NO_WALLET"
  | "TRANSACTION_REVERTED"
  // Library checks
  | "INVALID_ARGUMENT"
  | "EMPTY_ALLOWLIST"
  | "WEAK_SERVER_KEY"
  | "SPLIT_INVALID_INPUT"
  | "SPLIT_MISSING_BEARS"
  | "SPLIT_GAS_BUDGET"
  | "UNKNOWN_DEPLOYMENT"
  // Anything this library does not recognise
  | "UNKNOWN_REVERT"
  | "UNKNOWN_ERROR";

/** Which code each contract error name maps to. Names not listed map to `UNKNOWN_REVERT`. */
export const REVERT_CODES: Readonly<Record<string, ErrorCode>> = {
  // SeaDrop mint path
  NotActive: "MINT_NOT_ACTIVE",
  MintQuantityCannotBeZero: "MINT_ZERO_QUANTITY",
  MintZeroQuantity: "MINT_ZERO_QUANTITY",
  MintQuantityExceedsMaxMintedPerWallet: "MINT_WALLET_LIMIT",
  MintQuantityExceedsMaxSupply: "MINT_EXCEEDS_SUPPLY",
  ExceedsMaxBears: "MINT_EXCEEDS_SUPPLY",
  MintQuantityExceedsMaxTokenSupplyForStage: "MINT_EXCEEDS_STAGE_SUPPLY",
  IncorrectPayment: "MINT_WRONG_PAYMENT",
  InvalidProof: "NOT_ON_ALLOWLIST",
  FeeRecipientNotAllowed: "FEE_RECIPIENT_NOT_ALLOWED",
  FeeRecipientCannotBeZeroAddress: "FEE_RECIPIENT_NOT_ALLOWED",
  PayerNotAllowed: "PAYER_NOT_ALLOWED",
  // The collection (ERC721A and MintABear)
  OwnerQueryForNonexistentToken: "TOKEN_DOES_NOT_EXIST",
  URIQueryForNonexistentToken: "TOKEN_DOES_NOT_EXIST",
  ApprovalQueryForNonexistentToken: "TOKEN_DOES_NOT_EXIST",
  TransferCallerNotOwnerNorApproved: "NOT_TOKEN_OWNER_OR_APPROVED",
  TransferFromIncorrectOwner: "NOT_TOKEN_OWNER_OR_APPROVED",
  ApprovalCallerNotOwnerNorApproved: "NOT_TOKEN_OWNER_OR_APPROVED",
  BurnDisabled: "BURN_DISABLED",
  TransferToZeroAddress: "BURN_DISABLED",
  TransferToNonERC721ReceiverImplementer: "RECEIVER_NOT_ERC721",
  // WhitelistClaim
  NotClaimant: "CLAIM_WRONG_WALLET",
  BadSigner: "VOUCHER_INVALID",
  Expired: "VOUCHER_EXPIRED",
  CampaignClosed: "CAMPAIGN_CLOSED",
  SoldOut: "WHITELIST_SOLD_OUT",
  WalletLimit: "WALLET_LIMIT",
  AccountLimit: "ACCOUNT_LIMIT",
  WrongAllocation: "WRONG_ALLOCATION",
  // Activation
  ContractPaused: "ACTIVATION_PAUSED",
  ZeroAmount: "ZERO_AMOUNT",
  NotBearOwner: "NOT_BEAR_OWNER",
  AlreadyAtMaxLevel: "ALREADY_MAX_LEVEL",
  Overshoot: "OVERSHOOT",
  InvalidLevel: "INVALID_LEVEL",
  Reentrancy: "REENTRANCY",
  // $MNTD (OpenZeppelin v5, and the plain names other tokens use)
  ERC20InsufficientBalance: "INSUFFICIENT_MNTD_BALANCE",
  ERC20InsufficientAllowance: "INSUFFICIENT_MNTD_ALLOWANCE",
  InsufficientBalance: "INSUFFICIENT_MNTD_BALANCE",
  InsufficientAllowance: "INSUFFICIENT_MNTD_ALLOWANCE",
  // Owner-only
  OnlyOwner: "NOT_CONTRACT_OWNER",
  Unauthorized: "NOT_CONTRACT_OWNER",
};

/** OpenZeppelin v4 revert strings, mapped like the custom errors. */
const REVERT_STRINGS: readonly [RegExp, ErrorCode][] = [
  [/insufficient allowance/i, "INSUFFICIENT_MNTD_ALLOWANCE"],
  [/(burn|transfer) amount exceeds balance/i, "INSUFFICIENT_MNTD_BALANCE"],
];

const when = (seconds: unknown) =>
  typeof seconds === "bigint" ? new Date(Number(seconds) * 1000).toISOString().replace(".000Z", "Z") : "the scheduled time";

/**
 * The default message for each code, written for the holder. `details` fills in the numbers when
 * the error carried them (for example the per-wallet limit, or the stage's start time).
 */
const MESSAGES: Record<ErrorCode, (d: Record<string, unknown>) => string> = {
  MINT_NOT_ACTIVE: (d) =>
    d.startTimestamp !== undefined
      ? `This mint stage is not open. It runs from ${when(d.startTimestamp)} to ${when(d.endTimestamp)}.`
      : "This mint stage is not open right now.",
  MINT_ZERO_QUANTITY: () => "Choose at least one bear to mint.",
  MINT_WALLET_LIMIT: (d) =>
    d.allowed !== undefined
      ? `This wallet can mint at most ${d.allowed} in this stage, and it has reached that limit.`
      : "This wallet has reached its mint limit for this stage.",
  MINT_EXCEEDS_SUPPLY: () => "There are not enough bears left to mint that many.",
  MINT_EXCEEDS_STAGE_SUPPLY: () => "This stage does not have that many bears left.",
  MINT_WRONG_PAYMENT: () => "The payment did not match the mint price. Refresh the price and try again.",
  NOT_ON_ALLOWLIST: () => "This wallet is not on the whitelist for this stage, or the whitelist has changed.",
  FEE_RECIPIENT_NOT_ALLOWED: () => "The mint was sent with a fee recipient this drop does not accept.",
  PAYER_NOT_ALLOWED: () => "This wallet is not allowed to mint on behalf of another wallet.",
  TOKEN_DOES_NOT_EXIST: (d) => (d.tokenId !== undefined ? `Bear #${d.tokenId} has not been minted.` : "That bear has not been minted."),
  NOT_TOKEN_OWNER_OR_APPROVED: () => "This wallet does not own that bear and is not approved to move it.",
  BURN_DISABLED: () => "Bears cannot be burned or sent to the zero address.",
  RECEIVER_NOT_ERC721: () => "The receiving contract cannot accept NFTs.",
  SELF_TRANSFER: () =>
    "Sending a bear to the wallet that already holds it moves nothing, but it resets the bear's level and its Status link.",
  CLAIM_WRONG_WALLET: () => "This whitelist pass was issued for a different wallet. Connect the wallet you chose when claiming.",
  VOUCHER_INVALID: () => "This whitelist pass is not valid. Request a new one.",
  VOUCHER_EXPIRED: () => "This whitelist pass has expired. Request a new one.",
  CAMPAIGN_CLOSED: () => "The whitelist campaign is not open.",
  WHITELIST_SOLD_OUT: () => "All 1,000 whitelist spots have been claimed.",
  WALLET_LIMIT: () => "This wallet already holds two whitelist spots, the most one wallet can hold.",
  ACCOUNT_LIMIT: () => "This account has already claimed both of its whitelist spots.",
  WRONG_ALLOCATION: () => "This whitelist pass is out of date: the account's spots changed since it was issued. Request a new one.",
  NOT_YET_ELIGIBLE: () => "This account has not wagered enough yet for another whitelist spot.",
  ACTIVATION_PAUSED: () => "Burning and Status linking are not open yet.",
  ZERO_AMOUNT: () => "Choose an amount of $MNTD above zero.",
  NOT_BEAR_OWNER: () => "Only the bear's owner can do this, and this wallet does not own it.",
  ALREADY_MAX_LEVEL: () => "This bear is already at level 5.",
  TARGET_REACHED: (d) => (d.targetLevel !== undefined ? `This bear is already at level ${d.targetLevel} or above.` : "This bear has already reached that level."),
  OVERSHOOT: () => "That is more $MNTD than this bear needs to reach level 5. Burn only what the next level costs.",
  INVALID_LEVEL: () => "Levels run from 0 to 5.",
  REENTRANCY: () => "The burn was interrupted. Try again.",
  INSUFFICIENT_MNTD_BALANCE: () => "This wallet does not hold enough $MNTD for this burn.",
  INSUFFICIENT_MNTD_ALLOWANCE: () => "$MNTD has not been approved for this burn. Approve it, then burn.",
  NOT_CONTRACT_OWNER: () => "Only the contract's owner can do this.",
  USER_REJECTED: () => "The request was cancelled in the wallet.",
  INSUFFICIENT_GAS_FUNDS: () => "This wallet does not have enough ETH to pay the network fee.",
  NO_WALLET: () => "Connect a wallet first.",
  TRANSACTION_REVERTED: () => "The transaction failed on chain.",
  INVALID_ARGUMENT: (d) => (typeof d.reason === "string" ? d.reason : "An argument was out of range."),
  EMPTY_ALLOWLIST: () => "The whitelist has no rows.",
  WEAK_SERVER_KEY: () => "The server key must be at least 32 bytes.",
  SPLIT_INVALID_INPUT: (d) => (typeof d.reason === "string" ? d.reason : "The split's input rows are invalid."),
  SPLIT_MISSING_BEARS: (d) =>
    `The Transfer logs account for ${d.owned} bears but ${d.totalSupply} exist at block ${d.closingBlock}. Check fromBlock and the RPC's log range.`,
  SPLIT_GAS_BUDGET: (d) => `Reading bear #${d.tokenId} alone does not fit the gas budget of ${d.gasBudget}.`,
  UNKNOWN_DEPLOYMENT: (d) => `No MintABear deployment is recorded for chain ${d.chainId}.`,
  UNKNOWN_REVERT: () => "The contract refused the transaction.",
  UNKNOWN_ERROR: () => "Something went wrong.",
};

/** Every {@link ErrorCode}, for building your own message table or checking one. */
export const ERROR_CODES = Object.keys(MESSAGES) as readonly ErrorCode[];

/**
 * The default holder-facing message for `code`, with `details` filled in.
 *
 * @param code - Any {@link ErrorCode}.
 * @param details - The facts to fill in (a revert's arguments, a refusal's details).
 * @returns Plain English, safe to show a holder. To use your own wording, switch on `code` instead.
 */
export function messageFor(code: ErrorCode, details: Record<string, unknown> = {}): string {
  return MESSAGES[code](details);
}

// ---------------------------------------------------------------------------------------------
// Error classes
// ---------------------------------------------------------------------------------------------

/**
 * The base of every error this library throws.
 *
 * - `code` — stable, to switch on ({@link ErrorCode}).
 * - `userMessage` — plain English for the holder; safe to show as is.
 * - `message` — the same with a technical prefix, for logs.
 * - `details` — the facts behind it, by name (for a revert, the contract error's arguments).
 * - `cause` — the underlying error (viem's, or the one this wraps).
 */
export class MintABearError extends Error {
  override name = "MintABearError";
  readonly code: ErrorCode;
  readonly userMessage: string;
  readonly details: Readonly<Record<string, unknown>>;

  constructor(code: ErrorCode, options: { details?: Record<string, unknown>; userMessage?: string; cause?: unknown; context?: string } = {}) {
    const details = options.details ?? {};
    const userMessage = options.userMessage ?? messageFor(code, details);
    super(`${options.context ? `${options.context}: ` : ""}[${code}] ${userMessage}`, { cause: options.cause });
    this.code = code;
    this.userMessage = userMessage;
    this.details = details;
  }
}

/**
 * A decoded contract revert.
 *
 * - `errorName` — the contract's error (`"Overshoot"`), `"Error"` for a revert string, `"Panic"` for a
 *   panic, or `undefined` when the selector is not one this library knows.
 * - `args` — the error's arguments by name (`{ total: 3n, allowed: 2n }`); for a revert string,
 *   `{ reason }`.
 * - `raw` — the revert data, for decoding an error this library does not know.
 */
export interface Revert {
  errorName: KnownErrorName | "Error" | "Panic" | (string & {}) | undefined;
  args: Readonly<Record<string, unknown>>;
  raw?: Hex;
}

/** A contract refused the call. `revert` is the decoded revert; `code` and `userMessage` explain it. */
export class ContractRevertError extends MintABearError {
  override name = "ContractRevertError";
  readonly functionName: string;
  readonly revert: Revert;

  constructor(functionName: string, revert: Revert, cause: unknown) {
    super(codeForRevert(revert), { details: revert.args, cause, context: `${functionName} reverted with ${revert.errorName ?? "unknown error"}` });
    this.functionName = functionName;
    this.revert = revert;
  }
}

/** The library refused before anything was sent: nothing reached the wallet or the chain. */
export class ClientRefusal extends MintABearError {
  override name = "ClientRefusal";
  constructor(code: ErrorCode, details: Record<string, unknown> = {}, cause?: unknown) {
    super(code, { details, cause });
  }
}

// ---------------------------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------------------------

function codeForRevert(revert: Revert): ErrorCode {
  if (revert.errorName === "Error" && typeof revert.args.reason === "string") {
    for (const [pattern, code] of REVERT_STRINGS) if (pattern.test(revert.args.reason)) return code;
  }
  return (revert.errorName && REVERT_CODES[revert.errorName]) || "UNKNOWN_REVERT";
}

/**
 * Extracts the revert from anything viem throws for a failed call, or `undefined` if the error was
 * not a revert.
 *
 * @param error - What a viem call threw.
 * @returns The contract error's name and its arguments by name, or `undefined`.
 */
export function decodeRevert(error: unknown): Revert | undefined {
  if (!(error instanceof BaseError)) return undefined;
  const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError);
  if (!(reverted instanceof ContractFunctionRevertedError)) return undefined;
  if (reverted.data) {
    const values = reverted.data.args ?? [];
    // viem decodes a revert string as Error(string message) and a panic as Panic(uint256).
    if (reverted.data.errorName === "Error") return { errorName: "Error", args: { reason: values[0] }, raw: reverted.raw };
    if (reverted.data.errorName === "Panic") return { errorName: "Panic", args: { code: values[0] }, raw: reverted.raw };
    const inputs = (reverted.data.abiItem as AbiError).inputs ?? [];
    const args = Object.fromEntries(inputs.map((input, i) => [input.name || String(i), values[i]]));
    return { errorName: reverted.data.errorName, args, raw: reverted.raw };
  }
  if (reverted.reason !== undefined) return { errorName: "Error", args: { reason: reverted.reason }, raw: reverted.raw };
  return { errorName: undefined, args: {}, raw: reverted.raw };
}

/**
 * Turns anything a call threw into a {@link MintABearError}: a revert becomes a
 * `ContractRevertError`, a declined wallet prompt `USER_REJECTED`, too little ETH for gas
 * `INSUFFICIENT_GAS_FUNDS`; a `MintABearError` is returned unchanged; anything else is wrapped as
 * `UNKNOWN_ERROR` with the original as `cause`.
 *
 * @param error - What was thrown.
 * @param functionName - The contract function being called, for the message.
 */
export function toMintABearError(error: unknown, functionName = "call"): MintABearError {
  if (error instanceof MintABearError) return error;
  if (error instanceof BaseError) {
    if (error.walk((e) => e instanceof UserRejectedRequestError) instanceof UserRejectedRequestError) {
      return new MintABearError("USER_REJECTED", { cause: error, context: functionName });
    }
    // Nodes say it two ways: geth "insufficient funds for gas * price + value" (viem's
    // InsufficientFundsError); anvil and others cap estimation at the balance, "gas required exceeds allowance: 0".
    const noGasFunds = error.walk(
      (e) => e instanceof InsufficientFundsError || (e instanceof BaseError && /insufficient funds|gas required exceeds allowance:? \(?0\)?$/i.test(e.details ?? "")),
    );
    if (noGasFunds) {
      return new MintABearError("INSUFFICIENT_GAS_FUNDS", { cause: error, context: functionName });
    }
    const revert = decodeRevert(error);
    if (revert) return new ContractRevertError(functionName, revert, error);
  }
  return new MintABearError("UNKNOWN_ERROR", { cause: error, context: functionName });
}

/**
 * The `code` and holder-facing `userMessage` for anything thrown — the one call a UI's `catch` needs.
 *
 * @param error - Anything a call threw (a `MintABearError`, a viem error, a wallet's error, anything else).
 * @returns The code to branch on, the message to show, and the details behind it.
 *
 * @example
 * ```ts
 * catch (error) {
 *   const { code, userMessage } = explainError(error);
 *   if (code !== "USER_REJECTED") showError(userMessage);
 * }
 * ```
 */
export function explainError(error: unknown): { code: ErrorCode; userMessage: string; details: Readonly<Record<string, unknown>> } {
  const e = toMintABearError(error);
  return { code: e.code, userMessage: e.userMessage, details: e.details };
}

/**
 * True when `error` is a {@link MintABearError} — with `code` given, one with that code.
 *
 * @param error - Anything thrown.
 * @param code - The code to match; omit to match any `MintABearError`.
 *
 * @example
 * ```ts
 * if (isMintABearError(error, "OVERSHOOT")) offerTheExactAmount();
 * ```
 */
export function isMintABearError(error: unknown, code?: ErrorCode): error is MintABearError {
  return error instanceof MintABearError && (code === undefined || error.code === code);
}

/**
 * A plan's refusal: an expected "no", returned rather than thrown. `code` and `userMessage` are the
 * same as the error the contract would have reverted with.
 */
export interface Refusal<C extends ErrorCode = ErrorCode> {
  ok: false;
  code: C;
  userMessage: string;
  details: Readonly<Record<string, unknown>>;
}

/**
 * Builds a {@link Refusal}, with the code's default message.
 * @param code - The refusal's code.
 * @param details - The facts behind it.
 */
export function refusal<C extends ErrorCode>(code: C, details: Record<string, unknown> = {}): Refusal<C> {
  return { ok: false, code, userMessage: messageFor(code, details), details };
}
