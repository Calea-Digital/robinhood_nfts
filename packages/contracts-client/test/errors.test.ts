import { describe, expect, it } from "vitest";
import { BaseError, ContractFunctionRevertedError, encodeErrorResult, UserRejectedRequestError } from "viem";

import {
  allErrorsAbi,
  BURN_REVERTS,
  CLAIM_REVERTS,
  ContractRevertError,
  ERROR_CODES,
  explainError,
  IMPORT_REVERTS,
  isMintABearError,
  LINK_REVERTS,
  messageFor,
  MINT_REVERTS,
  MintABearError,
  REVERT_CODES,
  toMintABearError,
} from "../src/index.js";

/** A viem revert error for `errorName(args)`, as `simulateContract` throws it. */
function reverted(errorName: string, args: readonly unknown[] = []) {
  const data = encodeErrorResult({ abi: allErrorsAbi, errorName, args } as never);
  return new BaseError("call failed", { cause: new ContractFunctionRevertedError({ abi: allErrorsAbi, data, functionName: "f" }) });
}

describe("error model", () => {
  it("maps every documented revert to a code with a message", () => {
    /* Scenario:
       Given every revert the library documents for mint, claim, burn and link, plus the collection's and the token's
       When each is mapped
       Then each has a code other than UNKNOWN_REVERT, and that code has a non-empty message */
    const documented = [...MINT_REVERTS, ...CLAIM_REVERTS, ...IMPORT_REVERTS, ...BURN_REVERTS, ...LINK_REVERTS, "NotListed", "InvalidWindow", "OwnerQueryForNonexistentToken", "BurnDisabled", "ERC20InsufficientAllowance", "ERC20InsufficientBalance"];
    for (const name of documented) {
      const code = REVERT_CODES[name];
      expect(code, name).toBeDefined();
      expect(messageFor(code!).length, code).toBeGreaterThan(10);
    }
  });

  it("has a message for every code", () => {
    /* Scenario:
       Given every ErrorCode
       When its default message is built with no details
       Then each is a sentence */
    for (const code of ERROR_CODES) expect(messageFor(code), code).toMatch(/^\S.*[.]$/);
  });

  it("decodes a revert into a ContractRevertError with named arguments and a filled-in message", () => {
    /* Scenario:
       Given SeaDrop's NotActive(current, start, end) and MintQuantityExceedsMaxMintedPerWallet(total, allowed)
       When they are turned into MintABearErrors
       Then the arguments are named in details, and the messages carry the stage window and the limit */
    const notActive = toMintABearError(reverted("NotActive", [1_793_000_000n, 1_793_145_600n, 1_793_232_000n]), "mintPublic");
    expect(notActive).toBeInstanceOf(ContractRevertError);
    expect(notActive.code).toBe("MINT_NOT_ACTIVE");
    expect(notActive.details).toEqual({ currentTimestamp: 1_793_000_000n, startTimestamp: 1_793_145_600n, endTimestamp: 1_793_232_000n });
    expect(notActive.userMessage).toBe("This mint stage is not open. It runs from 2026-10-28T00:00:00Z to 2026-10-29T00:00:00Z.");

    const limit = toMintABearError(reverted("MintQuantityExceedsMaxMintedPerWallet", [3n, 2n]));
    expect(limit.userMessage).toBe("This wallet can mint at most 2 in this stage, and it has reached that limit.");
  });

  it("wraps a declined prompt, passes its own errors through, and wraps anything else", () => {
    /* Scenario:
       Given a viem UserRejectedRequestError, a MintABearError, and a plain Error
       When each is explained
       Then they read USER_REJECTED, the error's own code, and UNKNOWN_ERROR with the original as cause */
    expect(explainError(new UserRejectedRequestError(new Error("no"))).code).toBe("USER_REJECTED");
    const own = new MintABearError("OVERSHOOT");
    expect(toMintABearError(own)).toBe(own);
    const other = toMintABearError(new Error("boom"));
    expect(other.code).toBe("UNKNOWN_ERROR");
    expect((other.cause as Error).message).toBe("boom");
    expect(isMintABearError(other)).toBe(true);
    expect(isMintABearError(other, "OVERSHOOT")).toBe(false);
    expect(isMintABearError(new Error("x"))).toBe(false);
  });

  it("maps a selector it does not know to UNKNOWN_REVERT with the raw data", () => {
    /* Scenario:
       Given revert data with an unknown selector
       When it is turned into a MintABearError
       Then the code is UNKNOWN_REVERT and revert.raw carries the data for decoding elsewhere */
    const error = new BaseError("call failed", {
      cause: new ContractFunctionRevertedError({ abi: allErrorsAbi, data: "0xdeadbeef", functionName: "f" }),
    });
    const wrapped = toMintABearError(error);
    expect(wrapped.code).toBe("UNKNOWN_REVERT");
    expect(wrapped instanceof ContractRevertError && wrapped.revert.raw).toBe("0xdeadbeef");
  });
});
