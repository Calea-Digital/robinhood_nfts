import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Abi } from "viem";

import * as client from "../src/index.js";
import * as backend from "../src/backend.js";

const { activationAbi, mintABearAbi, seaDropAbi, whitelistClaimAbi } = client;

/**
 * Every contract function the play page (or MINT's backend and split) calls, with the library
 * export that makes the call. Owner and Studio configuration are not the app's calls: they are
 * listed apart, so a function added to a contract fails this test until it is placed.
 */
const SURFACE = {
  MintABear: {
    abi: mintABearAbi,
    calls: {
      ownerOf: "readOwner",
      transferNonce: "readTransferNonce",
      exists: "readExists",
      getMintStats: "readMintStats",
      transferFrom: "planTransfer",
      safeTransferFrom: "planTransfer",
    },
  },
  SeaDrop: {
    abi: seaDropAbi,
    calls: {
      mintPublic: "mintPublicCall",
      mintAllowList: "mintAllowListCall",
      getPublicDrop: "readPublicDrop",
      getAllowListMerkleRoot: "readAllowListRoot",
    },
  },
  WhitelistClaim: {
    abi: whitelistClaimAbi,
    calls: {
      claim: "claimCall",
      spotsLeft: "readCampaign",
      openAt: "readCampaign",
      closeAt: "readCampaign",
      signer: "readCampaign",
      claimsOf: "readClaimsOf",
      accountClaims: "readAccountClaims",
      claimants: "readClaimants",
    },
  },
  Activation: {
    abi: activationAbi,
    calls: {
      burn: "burnCall",
      linkBear: "linkCall",
      unlinkBear: "unlinkCall",
      levelOf: "readLevel",
      cumulativeOf: "readCumulative",
      lifetimeBurned: "readLifetimeBurned",
      weightOf: "readWeight",
      weightFor: "readWeightFor",
      thresholdFor: "readThreshold",
      costToReach: "readCostToReach",
      linkOf: "readLink",
      snapshot: "readSnapshot",
      paused: "readPaused",
    },
  },
} as const;

/** The state-changing functions of WhitelistClaim and Activation that are not the app's: owner-only. */
const OWNER_ONLY = [
  "setSigner",
  "setWindow",
  "setPaused",
  "transferOwnership",
  "renounceOwnership",
  "requestOwnershipHandover",
  "cancelOwnershipHandover",
  "completeOwnershipHandover",
];

const functions = (abi: Abi) => new Set(abi.filter((i) => i.type === "function").map((i) => (i as { name: string }).name));

describe("call surface", () => {
  it("covers every call the app makes", () => {
    /* Scenario: DEL-6 — Every call the app makes is covered
       - WHEN MINT integrates the play page
       - THEN every contract call it makes is covered by the typed TypeScript library, with passing tests and documented revert reasons, and the reference script reproduces the royalty split
       Here: each function the page, the voucher backend and the split call exists in the generated ABI
       and is made by a library export; $MNTD's approve is approveBurnCall; the voucher is signVoucher;
       the split is computeSplit over rowsFromEvents or rowsFromSnapshot. The other suites exercise each. */
    const exports = client as Record<string, unknown>;
    for (const [contract, { abi, calls }] of Object.entries(SURFACE)) {
      const names = functions(abi as Abi);
      for (const [fn, exported] of Object.entries(calls)) {
        expect(names.has(fn), `${contract}.${fn} in the ABI`).toBe(true);
        expect(typeof exports[exported], `${exported} for ${contract}.${fn}`).toBe("function");
      }
    }
    for (const exported of ["approveBurnCall", "planBurn", "computeSplit", "rowsFromEvents", "rowsFromSnapshot", "decodeSystemLogs", "execute"]) {
      expect(typeof exports[exported], exported).toBe("function");
    }
    expect(typeof backend.signVoucher).toBe("function");
    expect(typeof backend.planVoucher).toBe("function");
  });

  it("places every state-changing function of WhitelistClaim and Activation as the app's or the owner's", () => {
    /* Scenario:
       Given the generated ABIs of WhitelistClaim and Activation
       When their state-changing functions are listed
       Then each is either an app call the library makes or an owner-only function — a function added to either contract fails here */
    for (const abi of [whitelistClaimAbi, activationAbi] as Abi[]) {
      const writes = abi
        .filter((i) => i.type === "function" && i.stateMutability !== "view" && i.stateMutability !== "pure")
        .map((i) => (i as { name: string }).name);
      const app = new Set([...Object.keys(SURFACE.WhitelistClaim.calls), ...Object.keys(SURFACE.Activation.calls)]);
      for (const name of writes) expect(app.has(name) || OWNER_ONLY.includes(name), name).toBe(true);
    }
  });

  it("documents a revert table for every call family in the README", () => {
    /* Scenario:
       Given the package README
       When its sections are read
       Then it has a revert table for mint, claim and burn, and every revert the library lists for them appears in it */
    const readme = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "README.md"), "utf8");
    for (const name of [...client.MINT_REVERTS, ...client.CLAIM_REVERTS, ...client.BURN_REVERTS, "OwnerQueryForNonexistentToken", "BurnDisabled"]) {
      expect(readme.includes(`\`${name}\``), name).toBe(true);
    }
  });
});
