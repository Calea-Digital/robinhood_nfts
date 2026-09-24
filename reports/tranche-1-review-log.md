# Tranche-1 review — running log

The working log of the paired review started on 2026-09-23 from `docs/prompts/tranche-1-review.md`
and continued from `docs/prompts/tranche-1-integrity-and-review.md`. One entry per Task in review
order: the findings as raised, how each was settled, the Defect and its commits. It is the source
for `reports/tranche-1-review.md`, written when every Task is Done. Severity: L = Low, M = Medium,
I = Informational. "Presented" marks the entry opened when the Task was shown; the lines after it
record the settlement.

## MNT-15 COL-9
- I-1 Info: guard test's derived address uses a made-up implementation — ACCEPTED by reviewer.
- I-2 Info: second test's Scenario block not the spec's text — FIXED, Defect MNT-99, d510ae3 / merge 47a2368.
- I-3 Info: absence checked against historical selectors only — FIXED, MNT-99 (same commits).
- Slither src/MintABear.sol: solc-version (inherited), unimplemented-functions supportsInterface (FP).
- Done: MNT-15, MNT-99
## MNT-11 COL-5 (presented)
- diff-review f153925: removes renderer external call + owner setRenderer; tokenURI inherited. No findings.
- I-1 Info: "Artwork is immutable" not enforced on-chain; owner can setBaseURI after reveal.
- I-2 Info: SeaDropIntegration.t.sol:222 bare expectRevert in provenance test.
- I-1, I-3 ACCEPTED. I-2 FIXED, Defect MNT-100, f423bef / merge 03e8c1f.
- Done: MNT-11, MNT-100
## MNT-14 COL-8 (presented)
- Repo-wide: 42 blocks in COL family open with `Scenario: COL-n —` but don't quote the spec (WL/ACT/OPS: all 32 quoting blocks OK). COL-3: no block quotes the full Scenario. Checker: docs/tools/check_scenario_quotes.py
- Stranger burn → TransferCallerNotOwnerNorApproved, not BurnDisabled (Scenario "anyone").
- Error precedence: override/hook refuse zero before owner/approval (transfer) and before MintToZeroAddress (mint).
- adversarial-modeler: 9 vectors, none reachable; only I-2 (error precedence) Informational.
- I-1, I-2 ACCEPTED. I-3 FIXED as sweep, Defect MNT-101, 65a88d9 / merge e7db112.
- Done: MNT-14, MNT-101
## MNT-10 COL-4 (presented)
- No contract finding. I-1 Info: tests pin log order (reset before Transfer), stricter than the spec's "same transaction".
- Noted for COL-3 (#9): unchecked ++ on uint64 transferNonce — wrap infeasible (2^64 transfers).
- I-1 ACCEPTED. Done: MNT-10
## MNT-18 COL-12 (presented)
- No contract finding. I-1 Info: MintABear does not declare `is IMintABear`; conformance checked only at runtime by Activation/adapter tests (a return-type widening would be silent).
- I-2 Info: "plus the ERC-721 and SeaDrop standard surface" not exercised by name (balanceOf, getApproved, isApprovedForAll, name, symbol).
- I-1, I-2 ACCEPTED. Done: MNT-18
## MNT-19 COL-13 (presented) — findings: none
- Done: MNT-19
## MNT-7 COL-1 (presented)
- I-1 Info/test gap: canonical SeaDrop wiring (Deploy.s.sol:40,123) never asserted; fixture uses makeAddr("seaDrop").
- I-2 Info/trust: owner can updateAllowedSeaDrop to itself and mint up to MAX_BEARS outside Studio; not in HANDOVER Accepted risks.
- Deferred to COL-2 (#8): SeaDropIntegration.t.sol:147 bare expectRevert (tree says MintQuantityExceedsMaxSupply).
- I-1 FIXED, Defect MNT-102, b6b14a8 (test) / merge 26b7aa3. I-2 ACCEPTED → HANDOVER Accepted risks, bcfbd8a.
- TODO end of review: refresh test count (219+) in HANDOVER:50 and docs/prompts/tranche-1-rehearsal.md:16.
- Done: MNT-7, MNT-102
## MNT-8 COL-2 (presented)
- I-1 Info/spec: Scenario "whatever maxSupply says → ExceedsMaxBears" literally false for maxSupply ≤ 4444 (SeaDrop's MintQuantityExceedsMaxSupply first); documented in tests/CLAUDE.md.
- I-2 Info/test: bare expectRevert at MintABear.t.sol:62 and SeaDropIntegration.t.sol:147 — both SeaDrop's MintQuantityExceedsMaxSupply; tree leaf MintABear.tree.md:156 says only "it reverts".
- I-1 ACCEPTED. I-2 FIXED, Defect MNT-103, 29ed238 / merge 9c7defa. (Q answered: SeaDrop has no immutable cap; setMaxSupply/maxSupply/getMintStats/multiConfigure non-virtual; hook is the lever.)
- Done: MNT-8, MNT-103
## MNT-9 COL-3 (presented)
- I-1 Info: unchecked ++ on uint64 — wrap needs 2^64 transfers, infeasible.
- I-2 Info: a transfer to oneself advances the counter and voids the holder's own level/link — per spec ("every transfer"), a UI foot-gun; DEL-6 client should refuse from==to.
- I-1, I-2 ACCEPTED (I-2 → DEL-6: client refuses from==to; portal warns). Done: MNT-9
- DEL-6 notes so far: BurnDisabled for any zero destination (MNT-14 I-2); reset event precedes Transfer in logs (MNT-10 I-1); self-transfer resets (MNT-9 I-2).
## MNT-12 COL-6 (presented)
- I-1 Info/test: RoyaltyAddressCannotBeZeroAddress refusal untested and absent from tree.
- I-2 Info/ops: no RUNBOOK step for setting royalty (500 bps, pot ≠ admin/vault) before the first sale; royaltyInfo reads (0,0) until set, so enforced royalties (COL-7) would enforce zero.
- I-1 FIXED 00ef213, I-2 FIXED (RUNBOOK) 7bac96b; Defect MNT-104, merge 0d44da2. Tests now 220.
- Done: MNT-12, MNT-104
## MNT-13 COL-7 (presented)
- I-1 Info: mock/tests model SignedZone as the moving operator; real flow: Seaport 1.6 is caller (conduit not deployed, conduitKey 0), SignedZone authorizes on the validator. Fork-2 wording should name it.
- I-2 Info: SeaDrop reports isViewFunction=false but calls validateTransfer via a `view` interface (STATICCALL); if V3's authorizer path writes state, authorised fills revert. Fork-2 must confirm.
- I-1, I-2 FIXED (docs), Defect MNT-105, 6f0d65e / merge ef76db0.
- Done: MNT-13, MNT-105
## MNT-16 COL-10 (presented; adversarial running)
- I-1 Info/ops: renounceOwnership (TwoStepOwnable:91, public virtual onlyOwner) unguarded; "never call it" only in CLAUDE.md, not RUNBOOK/HANDOVER. Options: runbook line, or override to refuse (spec change).
- I-2 Info/test: "Calea holds no role" samples 6 owner functions; omits renounceOwnership, cancelOwnershipTransfer, multiConfigure, setProvenanceHash, setContractURI, SeaDrop updaters (shared modifier, so low value).
- adversarial: F1 Low — handover never verified; pre-accept owner writes (extra allowed SeaDrop, signer, payer, payout, own V3 list) persist; no RUNBOOK check. F2 Low/Info — renounceOwnership one-step, irreversible, does NOT clear potentialOwner (verified TwoStepOwnable:91-93 vs :60,:66) → pending owner can revive a renounced contract.
- Spec COL-10 amended 3196c01 (change col-10-no-renounce), board refreshed MNT-16. L-1 FIXED (override) 5c1a148; L-2 FIXED (RUNBOOK handover + Deploy test) & I-2 FIXED 3986df5; Defect MNT-106, merge 98bf22d. Tests 222.
- Done: MNT-16, MNT-106
## MNT-92 docs (presented)
- I-1 MintABear row (CLAUDE.md:28, README.md:17) "two-step ownership" omits never-renounced (post MNT-106).
- I-2 CLAUDE.md:44 "the runbook sets maxSupply to exactly 4,444" — the deploy script sets it; runbook only reads it in the handover; no "never raise it" line.
- I-3 CLAUDE.md test conventions don't say neighbours open a bare Scenario: (the rule MNT-101 applied).
- I-4 CLAUDE.md "finding written up in the contract's NatSpec" — PoC findings are in the PoC's own NatSpec.
- I-1..I-4 FIXED, Defect MNT-107, a10eb04 / merge 1ad8e09.
- Done: MNT-92, MNT-107
## MNT-22 WL-3 (presented; adversarial running)
- I-1 Low/consistency: WhitelistClaim keeps Solady renounceOwnership (+ single-step transferOwnership, handover fns); renounce freezes signer & window (no rotation after key compromise). "never renounce" not in RUNBOOK.
- I-2 Info/trust: signer (or owner via setSigner) can issue vouchers to wallets it controls with fresh account hashes — all 1,000 spots; not in HANDOVER Accepted risks.
- I-3 Info: setWindow can reopen after the export; WhitelistExport compare catches the divergence.
- adversarial: F1 Medium — allocationIndex is wallet-relative; a $50 account can get index-1 vouchers for two wallets (both valid) → 2 spots at tier 1; contract caps 2/account but not the tier. F2 Low = my I-1 (+ handover fns). F3 Info — locked-ether NatSpec wrong: requestOwnershipHandover/cancelOwnershipHandover payable by anyone (also Activation, HANDOVER accepted-risk text). F4 Info — spec type string has spaces; DEL-6 viem known-answer test.
- Spec WL-3 amended a9bac7e (change wl-3-account-allocation), board refreshed MNT-22. M-1, L-1, I-2 FIXED 5017d7d; I-3, I-4 (HANDOVER/RUNBOOK) ccbd1cd; I-5 in spec. Defect MNT-108, merge ee9f389. Tests 225.
- DEL-6 notes: viem known-answer test for the WL voucher (exact type string, domain name/version/chainId/verifyingContract); signer signs account's allocation number.
- Done: MNT-22, MNT-108
## MNT-20 WL-1 (presented)
- I-1 Info/spec: WL-1 attributes thresholds to wallets ("a wallet at $100 holds two", "Reaching a threshold makes a wallet eligible") — since WL-3's amendment the tier is the account's.
- I-2 Info/tree: WL-1 tree note says thresholds have no leaf; the account's tier order does now (and the PoC) — cross-reference.
- Spec WL-1 wording c45f056 (change wl-1-account-tier), board MNT-20. I-1, I-2 FIXED, Defect MNT-109, tree 8d1f1ae / merge 5c62561.
- Done: MNT-20, MNT-109
## MNT-23 WL-4 (presented) — findings: none. DEL-6 note: mirror builds proofs from the same list. Test tree builder (MerkleTreeLib) ≠ script's AllowListTree → check at MNT-93.
- Done: MNT-23 (DEL-6 note: proof builder = Studio's sorted tree)
## MNT-24 WL-5 (presented)
- I-1 Info: the Scenario's Given (close ≥48h before stage) is asserted against the test's own constant — tautological; the real check is Deploy.s.sol (deploy test). Tree says "checked by the deploy script and the runbook" — the RUNBOOK has no 48h line, and a later setWindow bypasses the deploy-time check.
- I-2 Info: test_deployment_setsSignerAndWindowBeforeTheCampaign's Then "a claim waits for openAt" is not asserted.
- I-1, I-2 FIXED, Defect MNT-110, cdd273b / merge e2a7f9c.
- Done: MNT-24, MNT-110
## MNT-93 export script (presented)
- L-1/I-1 Low: export/compare don't refuse while claims are still possible (now ≤ closeAt && spotsLeft > 0) → an incomplete export passes its own checks.
- I-2 Info: HANDOVER rehearsal item 3 doesn't name compare's pass against Studio's root, nor the per-wallet limit (a one-allocation wallet refused a second mint) — Studio may set one uniform limit.
- I-3 Info: pinned merkletreejs vector has no recorded generator; could not regenerate offline.
- L-1, I-2, I-3 FIXED, Defect MNT-111, 7d6ffd6 / merge 929231b. Vector generator not run (no npm fetch). Tests 226.
- Done: MNT-93, MNT-111
## MNT-94 docs (presented)
- I-1 CLAUDE.md:51 "48-hour gap ... a deploy value, not enforced on-chain" — omits that the deploy checks it once and a later setWindow is the runbook's rule (MNT-110).
- I-2 CLAUDE.md:37/:51 and README:41 don't say export/compare refuse while claims are open (CampaignStillOpen, MNT-111).
- I-1, I-2 FIXED, Defect MNT-112, 10752d4 / merge 71e860b.
- Done: MNT-94, MNT-112
## MNT-26 ACT-1 (presented; adversarial running)
- I-1 Info: ACT-1 spec, ACT-7 spec and Activation NatSpec:12-14 say the adapter burns then credits; the adapter credits first (accepted risk in HANDOVER). Prose contradicts code.
- I-2 Low/consistency: Activation allows renounceOwnership when unpaused (ACT-11 as specified); after it the crediter and pause are frozen — unlike MintABear/WhitelistClaim now. Decide at ACT-11/12 or now.
- adversarial ACT-1: no C/H/M. L-1 Low: owner can setCrediter to own address and mint levels without burn (spec Purpose "no key can forge"); I-1 order prose; I-2 renounce while unpaused; I-3 one-step transferOwnership in Deploy.s.sol:150; I-4 approved operator can self-transfer to wipe level (by design; DEL-6/portal note). snapshot over 4,444 ids may be heavy (ERC721A ownerOf scan) — caller pages.
- noted for OPS-6 (#36): pre-existing forge-lint note unused import MintABear in test/Enforcement.t.sol:7
## ARCHITECTURE CHANGE (grilled 2026-09-24): Activation burns MNTD; adapter removed
- Spec v2.2 174fa96 (change act-burn-in-activation; 71 board bodies refreshed). Code/tests e3e6e71, docs d65f619, merge 899d131. Task MNT-113. Tests 208. Fixes ACT-1 L-1, I-1, I-2.
- ACT-1's findings are settled by the architecture change: L-1, I-1, I-2 fixed (MNT-113); I-3 (one-step `transferOwnership` of `Activation` in `Deploy.s.sol`) deferred to OPS-2 (#34); I-4 (an approved operator's self-transfer wipes a level) a DEL-6 note. MNT-26 itself is re-reviewed against the new code when the review resumes.

## Carried forward

- **DEL-6 notes** (for `docs/prompts/del-6-client.md`): `BurnDisabled` answers any zero destination (MNT-14 I-2); `TransferNonceAdvanced` precedes `Transfer` in the logs (MNT-10 I-1); the client refuses `from == to` and the portal warns before transferring an activated bear, and an approved operator's self-transfer resets a bear too (MNT-9 I-2, MNT-26 I-4); a viem `signTypedData` known-answer test for the whitelist voucher — exact type string, domain `WhitelistClaim` / `1` / chainId / verifyingContract — and the signer signs the account's allocation number (MNT-22); the mirror's Merkle proofs use Studio's sorted-leaf tree, as `script/lib/AllowListTree.sol` builds it (MNT-23, MNT-93); approve `Activation`, not an adapter, and `BearActivated` carries no `ref` (MNT-113); page `snapshot` over large id ranges (MNT-26).
- **Open at the end of the review:** refresh the test count in `docs/HANDOVER.md` and `docs/prompts/tranche-1-rehearsal.md`; run `test/fixtures/merkletreejs-vector.js` once npm access is agreed (MNT-111); the pre-existing forge-lint note (unused `MintABear` import, `test/Enforcement.t.sol:7`) at OPS-6 (#36); the v2.2 client document is built only when the reviewer asks (Q13).
