# Tranche 1 — review session prompt

Open a fresh Claude Code session in `~/trees/robinhood_nfts` on branch `tranche-1`. The YouTrack
connector must be connected. Paste everything below the line. The session can span several sittings:
the board is the bookmark — resume at the first Task in the table below that is still In Review.

---

Review MintABear tranche 1 with me, one In Review Task at a time, in the order of the table below.
For each Task we both review it — I manually, you independently with the stack's review tools —
and it moves to Done only when we are both satisfied.

**Where things stand (2026-09-23).** Branch `tranche-1` (off `main` at `746acbe`, not pushed, not
merged) carries tranche 1's code. 39 Tasks are In Review: 33 requirement Tasks and the non-spec Tasks
MNT-92…94 and 96…98. OPS-4 (the rehearsal, MNT-64) is postponed until MINT's $MNTD is on 46630, and
its Subtask MNT-95 waits with it — neither is in this session. Suite 218 tests, 100 % coverage, no
build warnings, Slither no High or Critical. ACT-5 and OPS-2 were amended on 2026-09-23 (archived
changes under `openspec/changes/archive/`). Earlier judgment calls the reviewer has already agreed:
COL-8's `transferFrom` override (MNT-14), the PoC kept without its ERC-6551 part (MNT-15),
`WhitelistClaim`'s owner set in the constructor, `ZeroSigner` / `InvalidWindow` /
`NewOwnerIsZeroAddress` (MNT-22), and not switching the coverage gate command.

**Read first:** `CLAUDE.md` (the architecture, the conventions, who owns what on the board),
`docs/HANDOVER.md` ("Where things stand", "Next session" — its list of points left for the reviewer —
"Decisions that should not be relitigated", "Accepted risks", "Verified on-chain facts"), and
`~/trees/ai-stack/manual/01-web3.md` W2, W4 and W7 for which skill fires when.

## For each Task, in this order

1. **Present it.** Read the Task (`get_issue` + comments: the claim plan, the summary, the points
   for the reviewer). Then show me, with file:line references I can open:
   - **Spec** — the requirement block and its `#### Scenario` (the Gherkin) from
     `openspec/specs/<family>/spec.md`, quoted.
   - **Code** — the lines in `src/` or `script/` that implement it, on `tranche-1` as it is now.
   - **Tests** — every test whose block opens `Scenario: <ID> —`, plus the neighbouring tests the
     summary names; the tree leaves citing the id.
   - **History** — the Task's merge (`git diff <merge>^1 <merge> --stat`, and the full diff on request)
     and any later commit that touched the same lines (`git log --oneline <merge>..tranche-1 -- <files>`).
     Several Tasks' code moved after their merge — COL-4 and COL-5 tests now credit through
     `Activation.credit`, ACT-1's interface grew with later Tasks' tests — so review the current code
     and use the merge only to find it.
   Then stop and let me review.
2. **Review independently while I do**, with the lens the table names:
   - **Contract logic** — `differential-review:differential-review` scoped to the Task's lines (its
     merge diff plus later changes); for the value- or role-moving Tasks marked ⚑, escalate what it
     flags to the `differential-review:adversarial-modeler` agent; `slither <file>` on the contract.
     Arithmetic in base units or decimals (ACT-2, OPS-2's scaling): the `dimensional-analysis`
     validator, read-only.
   - **Tests-only Tasks** — does the Scenario test quote the spec's Scenario exactly; does each
     assertion actually test a clause of it (name the code change that would make it fail — if none
     would, the test is weak); does the tree leaf cite the id. Never write a fuzz, invariant or fork
     harness: a property that wants one is an INV-N / Fork-N line for the auditor.
   - **Scripts** — read against OPS-2 / OPS-3 / OPS-6 / WL-4; run the unit suite and any dry run.
   - **Docs** — read against the code; final-state prose; nothing stale.
   Report findings in the audit format (Title / Severity / Impact / Root Cause with line refs / PoC /
   Recommendation), or "none". Say what you checked, not only what you found.
3. **Settle it together.** For each finding: agree it is real or not. A real defect becomes a Defect
   issue (Work Kind Defect, Spec Ref = the violated requirement, body `Reproduce` / `Expected` /
   `Observed`), is fixed on its own `mnt/<spec-ref>-fix` branch through every gate
   (`forge fmt --check`, warning-free `forge build --sizes`, `forge test`, coverage, Slither with no
   new High or Critical), merged `--no-ff` into `tranche-1`, and re-reviewed; the Task stays In Review
   until then. A spec problem goes through `/opsx:propose` → lint → my go → archive → render → commit →
   `board.sh` (preview with `--dry` first), as ACT-5 and OPS-2 did.
4. **Done.** Only when I say "done" for that Task: set its State to Done, add a comment
   `Reviewed — Done (reviewer + Claude, 2026-..-..)` with the findings or "none" and any Defect ids,
   and log the review time. That instruction is my Done; never set Done without it, and never move a
   Task I have not named.

## Order

| # | Task | Spec | Merge | Where to look | Lens |
|---|---|---|---|---|---|
| 1 | MNT-15 | COL-9 | `18efeeb` | `src/MintABear.sol`; `MintABear.t.sol` COL-9 tests; `test/poc/` | logic |
| 2 | MNT-11 | COL-5 | `f153925` | `MintABear.sol` (no `tokenURI` override); `MintABearMetadataTest` | logic |
| 3 | MNT-14 | COL-8 | `67c5ae0` | `_beforeTokenTransfers`, `transferFrom`; `test/poc/BurnStrandsAccount.t.sol` | logic ⚑ |
| 4 | MNT-10 | COL-4 | `0340fee` | `TransferNonceAdvanced` in the hook; COL-4 tests | logic |
| 5 | MNT-18 | COL-12 | `728c5d5` | `exists`; the reads test | logic |
| 6 | MNT-19 | COL-13 | `ca76fb2` | events; COL-13 tests | tests |
| 7 | MNT-7 | COL-1 | `edb76b3` | constructor, allowed SeaDrop; `SeaDropIntegration.t.sol` | logic |
| 8 | MNT-8 | COL-2 | `3f6ceee` | `MAX_BEARS`, `ExceedsMaxBears` | logic |
| 9 | MNT-9 | COL-3 | `fa56c6a` | `transferNonce` | logic |
| 10 | MNT-12 | COL-6 | `3fd6e5e` | royalty info through Studio; COL-6 test | tests |
| 11 | MNT-13 | COL-7 | `2213856` | `MintABearCreatorTokenTest`, `MockTransferValidator` | logic |
| 12 | MNT-16 | COL-10 | `15844fe` | `TwoStepOwnable`; COL-10 tests | logic ⚑ |
| 13 | MNT-92 | NONE | `9c23b61` | `CLAUDE.md`, `README.md` (MintABear parts) | docs |
| 14 | MNT-22 | WL-3 | `b271b7a` | `src/WhitelistClaim.sol`; `WhitelistClaimRegistryTest` | logic ⚑ |
| 15 | MNT-20 | WL-1 | `841e145` | `WhitelistClaimRulesTest` | tests |
| 16 | MNT-23 | WL-4 | `2d03125` | `WhitelistClaimExportTest` (real SeaDrop) | tests |
| 17 | MNT-24 | WL-5 | `81ab7b7` | `WhitelistClaimTimingTest` | tests |
| 18 | MNT-93 | NONE | `771ed40` | `script/WhitelistExport.s.sol`, `script/lib/AllowListTree.sol`; `WhitelistExport.t.sol` | scripts |
| 19 | MNT-94 | NONE | `5b1b8af` | `CLAUDE.md`, `README.md` (WhitelistClaim parts) | docs |
| 20 | MNT-26 | ACT-1 | `ef8c41b` | `src/Activation.sol` (whole contract); `test/BaseTest.t.sol`; `ActivationTokenAgnosticTest`, `ActivationCreditTest` | logic ⚑ |
| 21 | MNT-27 | ACT-2 | `6a931ed` | thresholds; `ActivationThresholdsTest` | tests + dimensional |
| 22 | MNT-28 | ACT-3 | `c08785e` | weights; `ActivationWeightsTest` | tests |
| 23 | MNT-29 | ACT-4 | `8b8f664` | `credit`; `test_credit_isRecordedOnce` | tests ⚑ |
| 24 | MNT-30 | ACT-5 | `f2a18bd` | reset; `ActivationResetTest`; spec change `4ed0e4b` | tests |
| 25 | MNT-31 | ACT-6 | `1d53fa4` | `lifetimeBurned`; `ActivationLifetimeTest` | tests |
| 26 | MNT-32 | ACT-7 | `8c52275` | `src/DirectBurnAdapter.sol`; `DirectBurnAdapter.t.sol` incl. the hostile-token tests; `test/mocks/HookedMNTD.sol`, `ReentrantHolder.sol` | logic ⚑ |
| 27 | MNT-33 | ACT-8 | `f0e314f` | `Overshoot`; `DirectBurnAdapterOvershootTest` | tests |
| 28 | MNT-34 | ACT-9 | `267cdfa` | link; `ActivationLinkTest` | tests |
| 29 | MNT-35 | ACT-10 | `e600278` | `snapshot`; `ActivationSnapshotTest` | tests |
| 30 | MNT-36 | ACT-11 | `41a6fe4` | pause; `ActivationPauseTest`, `DirectBurnAdapterPauseTest` | tests |
| 31 | MNT-37 | ACT-12 | `e4d2063` | roles; `ActivationRolesTest` (interface pinned from `out/`) | tests ⚑ |
| 32 | MNT-38 | ACT-13 | `002e618` | events; `ActivationEventsTest`, `DirectBurnAdapterEventsTest` | tests |
| 33 | MNT-39 | ACT-14 | `a4ab688` | reads; `ActivationReadsTest` | tests |
| 34 | MNT-62 | OPS-2 | `dbb505b` | `script/Deploy.s.sol`, `script/config/example.json`; `Deploy.t.sol`; spec change `20be8fe` | scripts ⚑ + dimensional |
| 35 | MNT-63 | OPS-3 | `4ffbdda` | `script/verify.sh`, `test/fixtures/`, the CI step | scripts |
| 36 | MNT-66 | OPS-6 | `b8f57eb` | `script/Enforcement.s.sol`, `docs/RUNBOOK.md`; `Enforcement.t.sol` | scripts |
| 37 | MNT-96 | NONE | `b16a75b` | `CLAUDE.md`, `README.md` (whole) | docs |
| 38 | MNT-97 | NONE | `17a5097` | `test/*.tree.md` | docs |
| 39 | MNT-98 | NONE | `c44f4bb` | `docs/HANDOVER.md`, `docs/prompts/` | docs |

The table is the board's In Review lane as of 2026-09-23 (39 Tasks). At the start, compare it with
the lane (`search_issues` `project: MNT State: {In Review}`); a Task on the board and not in the table
goes at the end of its family, and a Task in the table already Done is skipped.

## When every Task is Done

- **Tranche-end pass.** Two or three narrow `solidity-auditor` passes over `src/` (it is
  non-deterministic; one pass is not enough — W7). Findings are handled as in step 3.
- **Report.** Write `reports/tranche-1-review.md`: each Task, the findings and how each was settled,
  the Defect ids and fix commits, and the tranche-end pass. Offer it; do not publish it anywhere.
- **Merge.** Tell me `tranche-1` is ready for me to merge into `main`; I merge it. Do not merge or push.
- **Next session.** Write `docs/prompts/del-6-client.md` for session 2 — the DEL-6 integration
  package: the typed TypeScript client library over the tranche-1 ABIs (with its own tests and the
  revert reasons a caller handles) and the reference royalty-split script with the dead-address
  exclusion. Base it on `openspec/specs/deliverables/spec.md` DEL-6, `docs/HANDOVER.md` "For the
  portal team" and "Integration", and CQ-14 (the repository question is still open).

**Never:** set Done without my word for that Task; push; merge into `main`; silence a Slither finding
or a lint; write a fuzz, invariant or fork harness; relitigate a settled decision; edit a
bridge-owned field.
