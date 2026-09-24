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

- Done: MNT-113, MNT-114 (2026-09-24, without separate review rows; MNT-26…39 and MNT-62 are still reviewed against MNT-113's code from #20).

## Integrity check (2026-09-24)
- Ran: lint OK (71 req, 20 CQ); render --check current; build 0 warnings; 208 tests; quotes 33/0; ABI of the three contracts vs every tranche-1 statement; Scenario → leaf/test map; INV/Fork header identical in the four contract trees; board.sh --dry; board states, links, CQ bodies and comments (sub-agent); working-docs grep; v2.1 .pages → PDF → PDFKit text vs 746acbe sources (ratio 0.991, formatting only).
- A-1 Medium/process: board.sh --dry failed — MNT-113 Spec Ref ACT-7 duplicated MNT-32. FIXED: MNT-113 Spec Ref NONE; --dry then 0 create / 0 refresh.
- A-2 Low: 16 Tasks' 2026-09-23 comments describe credit/adapter as current; MNT-113 not linked to MNT-27, 29, 31, 36, 39, 63. FIXED: "Superseded by MNT-113" comment on MNT-26…39, 62, 63; links to 27, 29, 36, 39, 63 added. Link MNT-113↔MNT-31 refused by the session's permission classifier — open for the reviewer.
- A-3 Info: MNT-114 has no relates-to (→ MNT-26: refused by the classifier, open for the reviewer); MNT-101 Spec Ref NONE (sweep) and MNT-114 under MNT-3 ACCEPTED.
- A-4 Low: SPECIFICATION.md §10 "CQ-3 the credit design" settled; §2 "credited burns"; two v2.1 typos. FIXED, Defect MNT-115, 3c23720.
- A-5 Info: Activation THRESHOLD_1…5 public, not named by ACT-14 (WEIGHT_n internal) → settle at MNT-39 (#33).
- A-6 Info: unnamed guard errors/events (ThresholdsNotAscending, WeightsNotAscending, ZeroAddress, InvalidLevel, SignerSet, WindowSet, RenounceDisabled) ACCEPTED, as ZeroSigner/InvalidWindow at MNT-22.
- A-7 Info: OPS-3 Scenario has no tree leaf (CI dry run only) → MNT-97 (#38).
- A-8 Low: tasks.md lines named the adapter/credit design. FIXED, MNT-115, 3c23720. proposal.md/design.md kept as the change's record.
- A-9 Info: rehearsal prompt "credited level". FIXED, MNT-115, 3c23720.
- A-10 Info: RUNBOOK has no Activation section (pause around switch-on, rehearsal window, ownership; OPS-5) → OPS-2 (#34) with I-3; RUNBOOK:3 "every action is an owner call" (export is read-only) → OPS-6 (#36).
- A-11 Low: v2.1 .pages clips the CQ-18 callout (p12) and CQ-9 callout (p24, hides "supply the prize count and excluded ids (CQ-20)"); Pages does not split a one-cell callout. Noted for the v2.2 build (shorten/split or build change; check page fit). v2.1 otherwise faithful to 746acbe.
- v2.1 now incorrect on: COL-10, WL-1, WL-3, ACT-1, 2, 4–8, 11–14, OPS-1, 2, 4, DEL-8; §1.1, §2 tables and flow, §8 three rows, §10 O5; CQ-1, 2, 3, 12.
- Note: the bridge .env is ~/trees/ai-stack/scripts/youtrack-bridge/.env (the handover prompt names ~/trees/ai-stack/.env).

## MNT-26 ACT-1 (re-presented against MNT-113's code)
- differential-review 899d131 + adversarial-modeler (holder, sale, admin, snapshot griefer): no C/H/M/L; the property holds (only `burn` writes records, owner and counter read in the same call, `burnFrom(msg.sender, amount)`). Slither: locked-ether (accepted), calls-loop (views), naming.
- ACT1-I-1 Info/test: record-before-burnFrom unpinned — swapping them passed the suite. FIXED, Defect MNT-116, cd96984 (observing holder; mutation fails only the new test). Tests 209.
- ACT1-I-2 Info: an unminted id reverts OwnerQueryForNonexistentToken, not NotBearOwner (`:200`, `:224`) → ACT-4 (#23).
- Carried: decimals ≥78 Panic / 0 decimals untested → #21; weights[0] == 100 unchecked → #22 / #34; no post-deploy read of MNTD/DECIMALS/thresholdFor(5) (the deploy's decimals check left with MNT-113) and Activation's own one-step transferOwnership → #34.
- DEL-6 notes: warn/cancel open listings before a burn (a filled listing after a burn costs the seller, buyer gets level 0); snapshot in ~500-id chunks at the closing block from an archive node (one 1..4444 call ≈ 40–45M gas, estimated), ids exactly 1..4444 (duplicates return duplicate rows); contract-held bears keep weight — only 0x…dEaD excluded (MINT's policy).
- Done: MNT-26, MNT-116
## MNT-27 ACT-2 (presented)
- Tests lens: each assertion breaks under a named mutation (`>=`→`>` in `_levelFor`; hard-coded 10^18; constant DECIMALS; `<=`→`<` in the ascending check). costToReach(1,4) = 8,333e18 alone would pass `return cumulative` or T4−T3 — caught by test_costToReach_atEveryLevel at level 5.
- dimension-validator (read-only): no mismatch in Activation.sol, Deploy.s.sol loadConfig/deployActivation, example.json; scaling once, in the constructor.
- ACT2-I-1 Info: "a bear burned for to 8,333" (test_costToReach_atEveryLevel) — fold into the next Activation test Defect.
- ACT2-I-2 Info: decimals 34–72 → SafeCast Overflow, ≥73 → Panic 0x11, 0 untested — ACCEPTED (reverts, never truncates; CQ-2 / Fork-3).
- Carried to OPS-2 (#34): a pre-scaled thresholdsWhole passes at 6 decimals (10^6× too high) — guard in loadConfig or runbook; loadConfig does not check array lengths.
## MNT-28 ACT-3 (presented)
- Tests lens: Scenario test breaks under a swapped weight, weightOf → weightFor(level+1), a broken _levelFor; neighbour pins the reset to 100; InvalidLevel above 5 pinned (:775).
- ACT3-I-1 Info: "burned for to" in four Scenario blocks (test/Activation.t.sol:767, 870, 911, 1254; MNT-113's rewording of "credited to"; includes ACT2-I-1) — fold into the next Activation test Defect.
- ACT3-I-2 Info: constructor does not require weights[0] == 100 (only ascending) — contract as specified; post-deploy read of weightFor(0..5) at OPS-2 (#34).
- Done: MNT-27, MNT-28, MNT-115
## MNT-29 ACT-4 (presented)
- Tests lens (the ⚑ adversarial pass on `burn` ran at #20): Scenario test breaks without nonReentrant, without the lifetime add, with a wrong event argument or amount; effect order pinned by MNT-116.
- ACT4-I-1 Info/test: check-order test did not pin NotBearOwner before AlreadyAtMaxLevel. FIXED (bob burns for the level-5 bear; the mutant fails).
- ACT1-I-2 settled here: an unminted id reverts OwnerQueryForNonexistentToken in the collection's ownerOf — FIXED, NatSpec on burn and linkBear, test, tree leaf.
- ACT2-I-1 / ACT3-I-1: four "burned for to" blocks reworded.
- Defect MNT-117 (all of the above). Tests 210.
- DEL-6 note: an unminted id answers `OwnerQueryForNonexistentToken` (ERC721A), not `NotBearOwner`.
- Done: MNT-29, MNT-117
## MNT-30 ACT-5 (presented) — findings: none (nonce checks in cumulativeOf, burn :204, linkOf, level-0 weight, no call into Activation each pinned by a mutation-breaking assertion).
- Done: MNT-30
## MNT-31 ACT-6 (presented) — findings: none (`+= amount`, no reset, reverted burn not counted).
- Done: MNT-31
## MNT-33 ACT-8 (presented, ahead of MNT-32) — findings: none (check removed, `>=` off-by-one, wrong costToReach each fail a test).
- Done: MNT-33
## MNT-32 ACT-7 (presented) — reviewed as `Activation.burn`, reusing #20's differential-review and adversarial pass.
- No contract finding; token trust stays CQ-2 / Fork-3 (HANDOVER accepted risk).
- ACT7-L-1 Low/doc: HANDOVER:94 (O5 row) says Deploy.s.sol refuses a token whose decimals differ from the config — removed by MNT-113 (the Part A grep missed the prose). Folded into the OPS-2 (#34) Defect with the post-deploy reads.
- Done: MNT-32
## MNT-34 ACT-9 (presented)
- ACT9-I-1 Info/test: no test linked a bear that had changed hands — `_linkedAtNonce = 0` (`:226`) passed all 210 tests, a mutant under which no traded bear could carry a new owner's link. FIXED, Defect MNT-118 (test_linkBear_byANewOwner_ofATradedBear; the mutant fails it). Tests 211.
- ACT9-I-2 Info: unlinkBear after the bear moved still emits BearUnlinked for a link linkOf already reads (0, 0) — ACCEPTED as specified.
- Reviewer asked who calls linkBear/unlinkBear and why not automatic: the holder, through the portal; the reset is automatic by the counter comparison on read (no callback — COL-3/COL-4); a link is a choice among a wallet's bears, and a transaction is needed to record one.
- DEL-6 notes: the portal prompts for linkBear after a purchase and after a holder's first burn (a wallet has no Status boost until it links, level 5 included) and shows a link voided by a sale; the indexer voids a link at TransferNonceAdvanced, and a later BearUnlinked for it is a no-op.
- Reviewer asked for the linking sequence by example (Alice, bears #7 and #12: burn without link gives no Status; the link follows later burns; a sale voids it with no transaction; unlink withdraws a nomination while keeping the bear). Gap found: an account with several wallets can carry several links — how Status counts them is MINT's and unspecified.
- Raised as CQ-21 (change act-9-status-per-account, 6c37f54 / merge dcc0820): open, needed by 2026-10-29, default the account's single highest-level link; ACT-9 points to it; §10 O9. Board: MNT-119 created, MNT-34 refreshed.
- board.sh check 3 then flagged CQ-2 (blocks ACT-7) and CQ-21 (blocks ACT-9) as open decisions gating only Done work. Settled: Blocks widened to what each gates downstream — CQ-2 → ACT-7, OPS-2, OPS-4; CQ-21 → ACT-9, DEL-6 (change cq-2-cq-21-blocks).
- Done: MNT-34, MNT-118
## MNT-35 ACT-10 (presented)
- Tests lens: dropping `exists`, a weight not from the level, excluding 0x…dEaD on-chain each fail a test.
- ACT10-L-1 Low/operational, measured (throwaway test, not committed): snapshot(1..4444) 56.2M gas at 2 per wallet; 1..500 3.2M; one 200-batch 1..200 6.4M; one 4,444-batch: 1..50 0.8M, 4395..4444 55.9M, 1..4444 out of gas (~1.97B); weightOf 2,451. Root cause: ERC721A ownerOf walks back to the batch start. FIXED as docs, Defect MNT-120: snapshot NatSpec, HANDOVER accepted risk. RUNBOOK team/treasury batch ≤ ~200 → OPS-2 (#34).
- DEL-6 note (replaces #20's estimate): the split script takes owners from indexed Transfer events at the closing block and weights from weightOf, or pages snapshot by a gas budget; one 1..4444 call is 56M+ and not dependable.
- Done: MNT-35, MNT-120
## MNT-36 ACT-11 (presented) — findings: none (pause checks in burn and linkBear, none on unlinkBear, no exemption, renounce refused in every state, PausedSet — each pinned by a mutation-breaking assertion).
- Done: MNT-36
## MNT-37 ACT-12 (presented)
- ACT12-I-1 Info/test: the interface pin read methodIdentifiers only — a level-writing `fallback` passed all 211 tests. FIXED, Defect MNT-121: the pin also reads `.abi[*].type` (no fallback, no receive; asserts the ABI was read). The fallback mutant fails it; a `receive` does not compile against the suite (the tests convert an address to Activation). Only Activation carries a pin.
- Checked: count + membership of the 29 named functions; out/ current (forge test compiles first); owner functions leave token, thresholds, weights, record and link unchanged. THRESHOLD_n (A-5) → #33; one-step transferOwnership (I-3) → #34.
- Done: MNT-37, MNT-121
## MNT-38 ACT-13 (presented)
- ACT13-I-1 Info/test: every checked BearActivated was a first burn (previousLevel 0, amount == cumulative) — swapping amount/cumulative, or hard-coding previousLevel 0, passed all 211 tests. FIXED, Defect MNT-122: the events test burns again (5,000 on 3,333) and reads 2 → 3, 5,000, 8,333; both mutants fail it.
- DEL-6 note: with the real $MNTD a burn transaction carries two logs — Activation's BearActivated and the token's Transfer(holder, 0x0, amount); MockMNTD emits none, so the unit tests see one. Indexers filter by emitter.
- Done: MNT-38, MNT-122
## MNT-39 ACT-14 (presented) — with Part A's A-5
- Tests lens: every listed read asserted against a value; a constant DECIMALS is caught by the 6-decimal construction test.
- A-5 settled: THRESHOLD_1…5 were public reads ACT-14 does not name. FIXED, Defect MNT-123: internal immutables, as the weights; thresholdFor is the one read; the ACT-12 pin is 24 functions; Activation runtime 7,844 → 7,529 bytes. Self-review of the diff: visibility only, no logic change; thresholdFor unchanged.
- Done: MNT-39, MNT-123
## MNT-62 OPS-2 (presented) — scripts ⚑ + dimensional (dimensional at #21, adversarial at #20); dry run: runWhitelist, runCollection OK on example.json; runActivation stops at the placeholder mntd.
- OPS2-L-1 Low: Activation's immutable inputs unchecked — a wrong `bears` deploys (the constructor never calls it), a wrong token / pre-scaled threshold / weights[0] ≠ 100 go unnoticed, one-step transferOwnership (ACT-1 I-3). FIXED, Defect MNT-124: deployActivation refuses a collection that does not answer MAX_BEARS with 4,444 (`NotTheCollection`) and prints DECIMALS, thresholdFor(1..5), weightFor(0..5); RUNBOOK "Activation" (read-back, the admin's setPaused(true) control check, rehearsal windows, switch-on, mint batches ≤ ~200). Ownership stays one-step, as WhitelistClaim's (accepted at MNT-22).
- OPS2-I-1 Info: loadConfig did not check array lengths. FIXED (`ConfigLength`).
- ACT7-L-1 (from MNT-32): HANDOVER:94 claimed a decimals guard. FIXED (final state).
- Also: README:37 "deploys the four contracts" (stale since MNT-113) → three; CLAUDE.md Deploy row. Tests 213.
- Done: MNT-62, MNT-124
## MNT-63 OPS-3 (presented) — scripts lens; dry run matches the expected file; no-broadcast chain exits 2.
- OPS3-I-1 Info: a broadcast set with no CREATE passed `--check` with exit 0 (vacuous). FIXED: exit 2 "no contract created".
- OPS3-I-2 Info: the verdict branches (verified / MISSING, exit 1) never ran. FIXED: test/verify.test.sh over recorded Sourcify answers (file:// SOURCIFY_URL; all-verified, one-missing, absent, no-create), a CI step; mutants (guard removed; "none" accepted) fail it.
- Defect MNT-125.
- Done: MNT-63, MNT-125
## MNT-66 OPS-6 (presented) — scripts lens
- OPS6-I-1 Info: with a validator other than V3 or zero, status said "on" and enable reverted AlreadyInState(true) — the runbook's restore could not run. FIXED: _set compares with the target (V3 / zero), AlreadyInState(validator), status names V3 or another; test_enable_restoresV3_overAnotherValidator.
- OPS6-I-2 Info: bare vm.expectRevert in the non-owner test. FIXED (TwoStepOwnable.OnlyOwner).
- Carried: unused MintABear import (test/Enforcement.t.sol:7, forge-lint) — FIXED; RUNBOOK:3 "every action is an owner call" (A-10) — FIXED.
- Defect MNT-126. Tests 214.
- Done: MNT-66, MNT-126
## MNT-96 docs (presented) — CLAUDE.md and README.md whole, against code, scripts, tests, CI, foundry.toml; forge build --force for the lint notes.
- MNT96-I-1 Info: CLAUDE.md:106 lint-note inventory missed ReentrantHolder's immutable naming and StubCollection.MAX_BEARS (MNT-124). FIXED: immutable renamed ACTIVATION (note gone); the stub's note listed with its reason.
- MNT96-I-2 Info: CLAUDE.md:107 "pin each contract's interface" — only Activation's. FIXED.
- MNT96-I-3 Info: CLAUDE.md:17 did not say to source the bridge .env. FIXED.
- MNT96-I-4 Info: CLAUDE.md:21 names a `/solidity` skill not present in this environment — asked the reviewer; left unchanged, OPEN.
- MNT96-I-5 Info: README Activation base without SafeCastLib; Tests paragraph said every test quotes a Scenario. FIXED.
- Folded to #38: CLAUDE.md:111 "each script has a suite and a tree" — verify.sh has a test script, no tree (A-7).
- Defect MNT-127 (parent should be MNT-3 — reviewer to move; created under MNT-5).

## Carried forward

- **DEL-6 notes** (for `docs/prompts/del-6-client.md`): `BurnDisabled` answers any zero destination (MNT-14 I-2); `TransferNonceAdvanced` precedes `Transfer` in the logs (MNT-10 I-1); the client refuses `from == to` and the portal warns before transferring an activated bear, and an approved operator's self-transfer resets a bear too (MNT-9 I-2, MNT-26 I-4); a viem `signTypedData` known-answer test for the whitelist voucher — exact type string, domain `WhitelistClaim` / `1` / chainId / verifyingContract — and the signer signs the account's allocation number (MNT-22); the mirror's Merkle proofs use Studio's sorted-leaf tree, as `script/lib/AllowListTree.sol` builds it (MNT-23, MNT-93); approve `Activation`, not an adapter, and `BearActivated` carries no `ref` (MNT-113); read the split with owners from indexed `Transfer` events at the closing block and weights from `weightOf`, or page `snapshot` by a gas budget — measured 56.2M for 1..4444 at two per wallet, and a long untransferred mint batch makes it quadratic; ids exactly 1..4444, contract-held bears keep weight (MNT-26, MNT-35); the portal warns about or cancels a bear's open listings before a burn (MNT-26); `burn` and `linkBear` for an unminted id revert `OwnerQueryForNonexistentToken` from the collection, not `NotBearOwner` (MNT-29); the portal prompts for `linkBear` after a purchase and after a holder's first burn and shows a link voided by a sale, and the indexer voids a link at `TransferNonceAdvanced` so a later `BearUnlinked` is a no-op (MNT-34); a burn transaction also carries $MNTD's own `Transfer(holder, 0x0, amount)` beside `BearActivated`, so indexers filter by emitter (MNT-38).
- **Open at the end of the review:** refresh the test count in `docs/HANDOVER.md` and `docs/prompts/tranche-1-rehearsal.md`; run `test/fixtures/merkletreejs-vector.js` once npm access is agreed (MNT-111); the v2.2 client document is built only when the reviewer asks (Q13), with the CQ-18 and CQ-9 callouts fitted to their pages (A-11); A-5 at #33, A-7 at #38, A-10 at #34 and #36.
