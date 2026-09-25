import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createHmac } from "node:crypto";
import {
  createWalletClient,
  hashTypedData,
  http,
  keccak256,
  parseEventLogs,
  stringToHex,
  toHex,
  type Address,
  type Hex,
} from "viem";
import { foundry } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import {
  CLAIM_REVERTS,
  claimCall,
  claimDomain,
  claimTypedData,
  ContractRevertError,
  execute,
  readAccountClaims,
  readCampaign,
  readClaimants,
  readClaimsOf,
  whitelistClaimAbi,
  type Voucher,
} from "../src/index.js";
import { accountHash, canonicalAccountId, planVoucher, signVoucher } from "../src/backend.js";
import { startAnvil, type Anvil } from "./setup/anvil.js";
import { accounts, deployFixture, type Fixture } from "./setup/fixture.js";

// Known answer, computed independently with Foundry's `cast` (not viem):
//   cast wallet sign --private-key $SIGNER_KEY --data --from-file <typed data below>
//   and keccak256(0x1901 ‖ domainSeparator ‖ structHash) built from `cast keccak` / `cast abi-encode`.
const KAT = {
  signerKey: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as Hex, // anvil account 1
  chainId: 4663,
  registry: "0x000000000000000000000000000000000000c1a1" as Address,
  voucher: {
    wallet: "0x1111111111111111111111111111111111111111",
    allocationIndex: 2,
    account: "0xabababababababababababababababababababababababababababababababab",
    deadline: 1_793_145_599n,
  } satisfies Voucher,
  typeHash: "0xefeffa9865bdd10925c4d58977e909cdd655e28373af9e2ea0de78826e523661",
  digest: "0x9ddcbbbdce67db104ed9cde123aeafa69a99007c53be2c0c3c0c611cb7319419",
  signature:
    "0x0c76f45fec1b6c0b2210e4cc476385e723ca0713d73ba96ff7b9b25a1ac3114848c4e9198600bc451dc276e795f6e1bbadcdabf77d5cd26edb43c10bc6463b3f1b",
} as const;

const SERVER_KEY = new Uint8Array(32).fill(7);

describe("whitelist voucher typed data", () => {
  it("uses exactly the contract's type string", () => {
    /* Scenario:
       Given the EIP-712 type string Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)
       When it is hashed
       Then it equals the known type hash, which the contract's CLAIM_TYPEHASH also equals (checked on chain below) */
    expect(keccak256(stringToHex("Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)"))).toBe(KAT.typeHash);
  });

  it("hashes and signs a voucher to the known answer", async () => {
    /* Scenario:
       Given a fixed key, the domain WhitelistClaim / 1 / 4663 / a fixed registry, and a fixed voucher
       When viem hashes it and signs it with signTypedData
       Then the digest and the signature equal those cast computed */
    const typed = claimTypedData(KAT.chainId, KAT.registry, KAT.voucher);
    expect(hashTypedData(typed)).toBe(KAT.digest);
    const signer = privateKeyToAccount(KAT.signerKey);
    expect(await signer.signTypedData(typed)).toBe(KAT.signature);
    expect(await signVoucher(signer, KAT.chainId, KAT.registry, KAT.voucher)).toBe(KAT.signature);
  });

  it("changes the digest with any domain field", () => {
    /* Scenario:
       Given the known voucher
       When the chain id or the registry differs
       Then the digest differs, so a voucher is good for one registry on one chain only */
    expect(hashTypedData(claimTypedData(46630, KAT.registry, KAT.voucher))).not.toBe(KAT.digest);
    expect(hashTypedData(claimTypedData(KAT.chainId, accounts.alice.address, KAT.voucher))).not.toBe(KAT.digest);
  });
});

describe("account hash (backend rule 1)", () => {
  it("is HMAC-SHA256 under the server key over the canonical id", async () => {
    /* Scenario:
       Given a server key and an email account id
       When accountHash is computed
       Then it equals HMAC-SHA256(key, "email:" + the canonical email) as node:crypto computes it */
    const expected = "0x" + createHmac("sha256", SERVER_KEY).update("email:alice@example.com").digest("hex");
    expect(await accountHash(SERVER_KEY, { email: "alice@example.com" })).toBe(expected);
  });

  it("makes one account of an email typed with other case or spacing", async () => {
    /* Scenario:
       Given " Alice@Example.COM " and "alice@example.com"
       When each is hashed as an email
       Then both give the same account, so the two-per-account cap holds across the spellings */
    expect(canonicalAccountId({ email: " Alice@Example.COM " })).toBe("email:alice@example.com");
    expect(await accountHash(SERVER_KEY, { email: " Alice@Example.COM " })).toBe(await accountHash(SERVER_KEY, { email: "alice@example.com" }));
  });

  it("compares a user id exactly, and keeps it apart from an email spelled the same", async () => {
    /* Scenario:
       Given the user ids "AbC" and "abc", and the email "abc"
       When each is hashed
       Then all three differ: a system-issued id is never case-folded into another account */
    const upper = await accountHash(SERVER_KEY, { userId: "AbC" });
    const lower = await accountHash(SERVER_KEY, { userId: "abc" });
    expect(upper).not.toBe(lower);
    expect(lower).not.toBe(await accountHash(SERVER_KEY, { email: "abc" }));
    expect(await accountHash(SERVER_KEY, { userId: " abc " })).toBe(lower);
  });

  it("is not the unsalted hash of the id, and changes with the key", async () => {
    /* Scenario:
       Given an account id
       When it is hashed with two keys and without one
       Then all three differ: the public topic cannot be matched to a guessed id without the key */
    const a = await accountHash(SERVER_KEY, { email: "alice@example.com" });
    expect(a).not.toBe(keccak256(stringToHex("alice@example.com")));
    expect(a).not.toBe(keccak256(stringToHex("email:alice@example.com")));
    expect(a).not.toBe(await accountHash(new Uint8Array(32).fill(8), { email: "alice@example.com" }));
  });

  it("refuses a server key shorter than 32 bytes", async () => {
    /* Scenario:
       Given a 16-byte key
       When accountHash is called
       Then it throws */
    await expect(accountHash(new Uint8Array(16), { userId: "alice" })).rejects.toThrow(/32 bytes/);
  });
});

describe("whitelist claim on chain", () => {
  let anvil: Anvil;
  let f: Fixture;
  let snapshot: Hex;
  let chainId: number;

  const signer = privateKeyToAccount(KAT.signerKey); // anvil account 1: the fixture's eligibility signer
  const now = async () => (await f.publicClient.getBlock()).timestamp;
  const acct = (name: string) => accountHash(SERVER_KEY, { userId: name });

  async function voucherFor(wallet: Address, account: Hex, allocationIndex: number, deadline?: bigint) {
    const voucher: Voucher = { wallet, allocationIndex, account, deadline: deadline ?? (await now()) + 600n };
    return { voucher, signature: await signVoucher(signer, chainId, f.registry, voucher) };
  }

  async function claim(from: keyof typeof accounts, v: { voucher: Voucher; signature: Hex }) {
    return execute(f.publicClient, f.wallet(accounts[from]), claimCall(f.registry, v.voucher, v.signature));
  }

  async function expectRevert(promise: Promise<unknown>, name: (typeof CLAIM_REVERTS)[number]) {
    const error = await promise.then(
      () => undefined,
      (e: unknown) => e,
    );
    expect(error).toBeInstanceOf(ContractRevertError);
    expect((error as ContractRevertError).revert.name).toBe(name);
  }

  async function ownerCall(functionName: "setSigner" | "setWindow", args: readonly unknown[]) {
    await execute(f.publicClient, f.wallet(accounts.deployer), { address: f.registry, abi: whitelistClaimAbi, functionName, args });
  }

  beforeAll(async () => {
    anvil = await startAnvil();
    f = await deployFixture(anvil.rpcUrl);
    chainId = await f.publicClient.getChainId();
  });
  afterAll(() => anvil.stop());
  beforeEach(async () => {
    snapshot = await f.testClient.snapshot();
  });
  afterEach(async () => {
    await f.testClient.revert({ id: snapshot });
  });

  it("agrees with the contract's type hash and EIP-712 domain", async () => {
    /* Scenario:
       Given the deployed registry
       When CLAIM_TYPEHASH and eip712Domain are read
       Then they are the known type hash and WhitelistClaim / 1 / chain id / the registry */
    const read = f.publicClient.readContract;
    expect(await read({ address: f.registry, abi: whitelistClaimAbi, functionName: "CLAIM_TYPEHASH" })).toBe(KAT.typeHash);
    const [, name, version, onChainId, verifyingContract] = await read({ address: f.registry, abi: whitelistClaimAbi, functionName: "eip712Domain" });
    expect({ name, version, chainId: Number(onChainId), verifyingContract }).toEqual(claimDomain(chainId, f.registry));
  });

  it("claims with a voucher the backend planned and signed, and the reads follow", async () => {
    /* Scenario:
       Given an account eligible for one allocation and a wallet with none
       When the backend plans and signs a voucher and the wallet claims it
       Then WhitelistClaimed carries the wallet, index 1, the account and spot 1; spots left read 999; the claimant list has the wallet */
    const account = await acct("alice");
    const plan = await planVoucher(f.publicClient, f.registry, { wallet: accounts.alice.address, account, eligibleAllocations: 1, now: await now() });
    expect(plan.ok).toBe(true);
    if (!plan.ok) return;
    expect(plan.voucher.allocationIndex).toBe(1);
    const receipt = await claim("alice", { voucher: plan.voucher, signature: await signVoucher(signer, chainId, f.registry, plan.voucher) });
    const [event] = parseEventLogs({ abi: whitelistClaimAbi, logs: receipt.logs, eventName: "WhitelistClaimed" });
    expect(event?.args).toEqual({ wallet: accounts.alice.address, allocationIndex: 1, account, spotNumber: 1n });
    expect((await readCampaign(f.publicClient, f.registry)).spotsLeft).toBe(999n);
    expect(await readClaimsOf(f.publicClient, f.registry, accounts.alice.address)).toBe(1);
    expect(await readAccountClaims(f.publicClient, f.registry, account)).toBe(1);
    expect(await readClaimants(f.publicClient, f.registry)).toEqual([{ wallet: accounts.alice.address, allocations: 1 }]);
  });

  it("numbers allocations by account, whichever wallet claims (backend rule 2)", async () => {
    /* Scenario:
       Given an account at $100 that claimed allocation 1 from alice's wallet
       When the backend plans for the same account and bob's wallet
       Then the voucher carries index 2, bob's claim succeeds, and the account reads two */
    const account = await acct("alice");
    await claim("alice", await voucherFor(accounts.alice.address, account, 1));
    const plan = await planVoucher(f.publicClient, f.registry, { wallet: accounts.bob.address, account, eligibleAllocations: 2, now: await now() });
    expect(plan).toMatchObject({ ok: true, voucher: { allocationIndex: 2 } });
    if (!plan.ok) return;
    await claim("bob", { voucher: plan.voucher, signature: await signVoucher(signer, chainId, f.registry, plan.voucher) });
    expect(await readAccountClaims(f.publicClient, f.registry, account)).toBe(2);
  });

  it("refuses to plan past the wagering tier, the wallet cap and the account cap", async () => {
    /* Scenario:
       Given an account at $50 that has claimed its one allocation, then a wallet holding two, then an account holding two
       When the backend plans another voucher for each
       Then it answers NotYetEligible, WalletLimit and AccountLimit, and signs nothing */
    const a = await acct("a");
    const b = await acct("b");
    const t = await now();
    await claim("alice", await voucherFor(accounts.alice.address, a, 1));
    expect(await planVoucher(f.publicClient, f.registry, { wallet: accounts.alice.address, account: a, eligibleAllocations: 1, now: t })).toEqual({
      ok: false,
      reason: "NotYetEligible",
    });
    await claim("alice", await voucherFor(accounts.alice.address, b, 1));
    expect(await planVoucher(f.publicClient, f.registry, { wallet: accounts.alice.address, account: await acct("c"), eligibleAllocations: 2, now: t })).toEqual({
      ok: false,
      reason: "WalletLimit",
    });
    await claim("bob", await voucherFor(accounts.bob.address, a, 2));
    expect(await planVoucher(f.publicClient, f.registry, { wallet: accounts.carol.address, account: a, eligibleAllocations: 2, now: t })).toEqual({
      ok: false,
      reason: "AccountLimit",
    });
  });

  it("refuses to plan outside the window", async () => {
    /* Scenario:
       Given the campaign window
       When the backend plans at a time after closeAt
       Then it answers CampaignClosed */
    const plan = await planVoucher(f.publicClient, f.registry, {
      wallet: accounts.alice.address,
      account: await acct("a"),
      eligibleAllocations: 2,
      now: f.closeAt + 1n,
    });
    expect(plan).toEqual({ ok: false, reason: "CampaignClosed" });
  });

  describe("reverts, in check order", () => {
    it("NotClaimant: the voucher is sent by another wallet", async () => {
      /* Scenario:
         Given a voucher for alice
         When bob sends it
         Then the claim reverts NotClaimant */
      await expectRevert(claim("bob", await voucherFor(accounts.alice.address, await acct("a"), 1)), "NotClaimant");
    });

    it("BadSigner: signed by a key that is not the signer", async () => {
      /* Scenario:
         Given a voucher for alice signed by carol's key
         When alice sends it
         Then the claim reverts BadSigner */
      const voucher: Voucher = { wallet: accounts.alice.address, allocationIndex: 1, account: await acct("a"), deadline: (await now()) + 600n };
      const signature = await accounts.carol.signTypedData(claimTypedData(chainId, f.registry, voucher));
      await expectRevert(claim("alice", { voucher, signature }), "BadSigner");
    });

    it("BadSigner: a contract as the signer can never sign (backend rule 4)", async () => {
      /* Scenario:
         Given the signer set to a contract address
         When any voucher is claimed
         Then the claim reverts BadSigner: the contract recovers with ecrecover only */
      await ownerCall("setSigner", [f.activation]);
      await expectRevert(claim("alice", await voucherFor(accounts.alice.address, await acct("a"), 1)), "BadSigner");
    });

    it("BadSigner after rotation, and a rotated-out key revived by rotating it back (backend rule 4)", async () => {
      /* Scenario:
         Given an unexpired voucher from the signer, then the signer rotated to carol
         When alice claims, and again after the old key is set back
         Then the first reverts BadSigner and the second succeeds — why a key rotated out is never rotated back */
      const v = await voucherFor(accounts.alice.address, await acct("a"), 1);
      await ownerCall("setSigner", [accounts.carol.address]);
      await expectRevert(claim("alice", v), "BadSigner");
      await ownerCall("setSigner", [signer.address]);
      await claim("alice", v);
    });

    it("Expired: after the deadline", async () => {
      /* Scenario:
         Given a voucher whose deadline has passed
         When alice sends it
         Then the claim reverts Expired */
      await expectRevert(claim("alice", await voucherFor(accounts.alice.address, await acct("a"), 1, (await now()) - 1n)), "Expired");
    });

    it("CampaignClosed: after closeAt", async () => {
      /* Scenario:
         Given a voucher with a far deadline and the chain past closeAt
         When alice sends it
         Then the claim reverts CampaignClosed */
      const v = await voucherFor(accounts.alice.address, await acct("a"), 1, f.closeAt + 86_400n);
      await f.testClient.setNextBlockTimestamp({ timestamp: f.closeAt + 1n });
      await f.testClient.mine({ blocks: 1 });
      await expectRevert(claim("alice", v), "CampaignClosed");
    });

    it("SoldOut: all 1,000 spots claimed", async () => {
      /* Scenario:
         Given the spot counter at 1,000 (written to storage: slot 0, bytes 30–31, per forge inspect)
         When a valid voucher is claimed
         Then the claim reverts SoldOut and spotsLeft reads zero */
      const slot0 = await f.publicClient.getStorageAt({ address: f.registry, slot: toHex(0, { size: 32 }) });
      const value = (BigInt(slot0!) & ~(0xffffn << 240n)) | (1000n << 240n);
      await f.testClient.setStorageAt({ address: f.registry, index: toHex(0, { size: 32 }), value: toHex(value, { size: 32 }) });
      expect((await readCampaign(f.publicClient, f.registry)).spotsLeft).toBe(0n);
      await expectRevert(claim("alice", await voucherFor(accounts.alice.address, await acct("a"), 1)), "SoldOut");
      expect(await planVoucher(f.publicClient, f.registry, { wallet: accounts.alice.address, account: await acct("a"), eligibleAllocations: 2, now: await now() })).toEqual({
        ok: false,
        reason: "SoldOut",
      });
    });

    it("WalletLimit: a wallet with two allocations", async () => {
      /* Scenario:
         Given alice holding two allocations from two accounts
         When she claims a third from a third account
         Then the claim reverts WalletLimit */
      await claim("alice", await voucherFor(accounts.alice.address, await acct("a"), 1));
      await claim("alice", await voucherFor(accounts.alice.address, await acct("b"), 1));
      await expectRevert(claim("alice", await voucherFor(accounts.alice.address, await acct("c"), 1)), "WalletLimit");
    });

    it("AccountLimit: an account with two allocations", async () => {
      /* Scenario:
         Given an account that claimed allocations 1 and 2
         When a third wallet claims for it
         Then the claim reverts AccountLimit */
      const a = await acct("a");
      await claim("alice", await voucherFor(accounts.alice.address, a, 1));
      await claim("bob", await voucherFor(accounts.bob.address, a, 2));
      await expectRevert(claim("carol", await voucherFor(accounts.carol.address, a, 3)), "AccountLimit");
    });

    it("WrongAllocation: an index that is not the account's next", async () => {
      /* Scenario:
         Given an account with no claims
         When a voucher with index 2 is claimed, and after one claim, a second voucher with index 1
         Then both revert WrongAllocation: the wager tier does not pick the index, the chain does */
      const a = await acct("a");
      await expectRevert(claim("alice", await voucherFor(accounts.alice.address, a, 2)), "WrongAllocation");
      await claim("alice", await voucherFor(accounts.alice.address, a, 1));
      await expectRevert(claim("bob", await voucherFor(accounts.bob.address, a, 1)), "WrongAllocation");
    });
  });

  it("claims from a smart-wallet address: the voucher's wallet is the account that sends", async () => {
    /* Scenario:
       Given a contract address standing for a smart wallet, with a voucher naming it
       When that address sends the claim
       Then the claim succeeds and the contract address holds the allocation */
    const smart = f.validator; // any address with code
    await f.testClient.impersonateAccount({ address: smart });
    await f.testClient.setBalance({ address: smart, value: 10n ** 18n });
    const v = await voucherFor(smart, await acct("a"), 1);
    const wallet = createWalletClient({ chain: foundry, transport: http(anvil.rpcUrl), account: smart });
    await execute(f.publicClient, wallet, claimCall(f.registry, v.voucher, v.signature));
    await f.testClient.stopImpersonatingAccount({ address: smart });
    expect(await readClaimsOf(f.publicClient, f.registry, smart)).toBe(1);
  });
});
