# Tranche 1 — integrity check, then the rest of the review

Paste this into a fresh Claude Code session in `~/trees/robinhood_nfts`, on branch `tranche-1`.

---

We are part-way through the paired review of MintABear tranche 1. Before continuing it, check that
everything that describes the system still agrees with everything else — the review changed code,
spec and board in several places. Then resume the review where it stopped.

**Where things stand (2026-09-24).** Branch `tranche-1` (off `main` at `746acbe`, not pushed, not
merged). Review log: `reports/tranche-1-review-log.md` — read it whole; it records every finding,
how it was settled, the Defects and their commits, and the notes carried forward. Done: the COL
family (MNT-7…16, 18, 19), the WL family (MNT-20, 22…24), MNT-92…94, and Defects MNT-99…112. In
Review, still to review: MNT-26…39 (ACT-1…14), MNT-62, 63, 66 (OPS-2, 3, 6), MNT-96…98, MNT-113, MNT-114.
Spec is v2.2. Suite 208 tests, 100 % coverage, no build warnings, Slither no High or Critical.

**What the review changed, so the check knows where to look.**
- Spec amended through archived OpenSpec changes (`openspec/changes/archive/2026-09-24-*`):
  COL-10 (never renounced, `3196c01`), WL-3 (the voucher's `allocationIndex` is the account's;
  renounce refused, `a9bac7e`), WL-1 (wording, `c45f056`), and v2.2 (`174fa96`): `Activation` burns
  $MNTD itself — `DirectBurnAdapter`, `credit`, the crediter and refs are gone; ACT-1, ACT-4, ACT-7
  renamed; ACT-2, 6, 8, 11–14, OPS-1, 2, 4, DEL-8 modified; CQ-2, CQ-3, CQ-12 edited by hand in
  `openspec/decisions.md`; four ACT Scenario titles retitled by hand after archive (the validator
  refuses a Scenario title change in a delta — reviewer's choice).
- Code: `MintABear.renounceOwnership` reverts; `WhitelistClaim` checks `allocationIndex` against
  `accountClaims` and refuses renounce; `Activation` rewritten around `burn` (MNT-113);
  `WhitelistExport.s.sol` refuses while claims are open; `Deploy.s.sol` has no adapter.
- Docs: `docs/RUNBOOK.md` gained "Ownership handover", "Whitelist export" and "Royalties";
  `docs/HANDOVER.md` accepted risks and portal notes changed; `CLAUDE.md` and `README.md` follow.
- Board: 71 Task bodies refreshed by `board.sh` for v2.2; Defects MNT-99…112 and Task MNT-113
  created by hand (Claude-owned).
- The client document `docs/client/MintABear-Specification-v2.1.pages` was built at `746acbe`,
  before any of this. v2.2 has not been built — deliberately (the reviewer builds it on request).

**Read first:** `CLAUDE.md`, `docs/HANDOVER.md`, `reports/tranche-1-review-log.md`, and
`docs/prompts/tranche-1-review.md` (the review's procedure and rules — they all still apply).

## Part A — integrity check

Five artefacts: **(1)** `openspec/` (specs, `decisions.md`, `config.yaml`), **(2)** the prose views
`docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md`, **(3)** the client document in `docs/client/`,
**(4)** the code (`src/`, `script/`, `test/` and its trees), **(5)** the YouTrack board (project MNT).
Also the working docs `CLAUDE.md`, `README.md`, `docs/HANDOVER.md`, `docs/RUNBOOK.md`,
`openspec/changes/tranche-1/tasks.md`. Check every pair that can disagree, and say for each check
what you ran and what it returned. Read-only: change nothing until I have seen the findings.

1. **Spec ↔ prose.** `python3 docs/tools/spec_tools/lint_spec.py --root .`;
   `/usr/bin/python3 docs/tools/spec_tools/render_calea_prose.py --root . --check`. Then the
   narrative *outside* the generated markers, which no tool checks: contract counts and lists, the
   flow, the calendar, §10's open items, the version and date lines — read against the specs.
2. **Spec ↔ code.** For every tranche-1 requirement (COL-1…13, WL-1, 3, 4, 5, ACT-1…14, OPS-2, 3, 6):
   every function, error, event, read and check order the statement names exists in the code with
   that name, signature and order, and the code has nothing the spec does not name (read the ABI
   from `out/<Contract>.sol/<Contract>.json`: `methodIdentifiers`, and the `abi` entries of type
   `error` and `event`). `python3 docs/tools/check_scenario_quotes.py` (every id-carrying test block
   quotes its Scenario); every Scenario has a tree leaf citing its id; the INV-N / Fork-N numbering
   header is the same in every tree and matches the obligations listed. `tasks.md` ticks match the
   requirements implemented.
3. **Spec ↔ board.** `source ~/trees/ai-stack/.env; docs/tools/board.sh --dry` must show nothing
   drifted and nothing to create. Then, beyond what the bridge checks: every Task's State against
   the review log (Done / In Review exactly as listed above); the Defects MNT-99…112 Done and MNT-113
   In Review, each with Work Kind, Spec Ref, parent milestone, the `MNT Claude` tag and its
   `relates to` link; decision States against `openspec/decisions.md` (CQ-3's changed resolution
   in particular); no Task still describing the adapter or the crediter in a Claude-owned comment
   that a reader would take as current.
4. **Spec ↔ working docs.** `CLAUDE.md`, `README.md`, `docs/HANDOVER.md`, `docs/RUNBOOK.md` and the
   `config.yaml` context against the specs and the code: search for what the review removed or
   renamed (`DirectBurnAdapter`, adapter, crediter, `credit(`, `ref`, `setCrediter`, `mntdDecimals`,
   `DecimalsMismatch`, `NotOwner`, `BurnedForBear`, `CannotRenounceWhilePaused`, a wallet-relative
   `allocationIndex`, "never call `renounceOwnership`") and read each hit; final-state prose only.
   Session prompts in `docs/prompts/` other than this one and the rehearsal prompt are records —
   note staleness there, do not treat it as a defect.
5. **Client document.** Confirm the v2.1 `.pages` is a faithful build of the source at `746acbe`:
   export it to PDF through `osascript` and extract its text with a short Swift PDFKit script (see
   `docs/HANDOVER.md`, "Where things stand"), and compare it with
   `git show 746acbe:docs/SPECIFICATION.md` and `…:docs/OPEN-QUESTIONS.md`. Then list what MINT's
   document no longer says correctly: `git diff 746acbe tranche-1 -- docs/SPECIFICATION.md
   docs/OPEN-QUESTIONS.md`, summarised by requirement. Do not build v2.2 — ask me.

Report the findings in the audit format (Title / Severity / Impact / Root Cause with file:line /
Recommendation), grouped by pair, or "none" per check. Settle them with me as in the review's
step 3: a real defect becomes a Defect issue (Spec Ref = the requirement, or `NONE`) fixed on its
own branch through every gate; a spec problem goes through `/opsx:propose` → lint → my go →
archive → render → commit → `board.sh --dry` → `board.sh`. Append Part A's findings and their
settlement to `reports/tranche-1-review-log.md` under "Integrity check".

## Part B — resume the review

Then continue the review, one Task at a time, exactly as `docs/prompts/tranche-1-review.md` steps
1–4 say (present → independent review with the lens → settle → Done only on my word, with the
`Reviewed — Done (reviewer + Claude, <date>)` comment and logged time). Append each Task to the log.

| # | Task | Spec | Merge | Where to look | Lens |
|---|---|---|---|---|---|
| 20 | MNT-26 | ACT-1 | `ef8c41b` → rewritten by `899d131` | `src/Activation.sol` whole; `test/BaseTest.t.sol`; `ActivationOneTokenTest`, `ActivationBurnTest` | logic ⚑ |
| 21 | MNT-27 | ACT-2 | `6a931ed`, `899d131` | constructor scaling, `DECIMALS`; `ActivationThresholdsTest`, `ActivationConstructionTest` | tests + dimensional |
| 22 | MNT-28 | ACT-3 | `c08785e` | weights; `ActivationWeightsTest` | tests |
| 23 | MNT-29 | ACT-4 | `8b8f664`, `899d131` | `burn`; `ActivationReentrancyTest.test_burn_isRecordedOnce`; `test/mocks/HookedMNTD.sol`, `ReentrantHolder.sol` | tests ⚑ |
| 24 | MNT-30 | ACT-5 | `f2a18bd` | reset; `ActivationResetTest`; spec change `4ed0e4b` | tests |
| 25 | MNT-31 | ACT-6 | `1d53fa4` | `lifetimeBurned`; `ActivationLifetimeTest` | tests |
| 26 | MNT-32 | ACT-7 | `8c52275` → replaced by `899d131` | `burn` route, record-then-burn, `nonReentrant`; `ActivationBurnTest` | logic ⚑ |
| 27 | MNT-33 | ACT-8 | `f0e314f`, `899d131` | `Overshoot`; `ActivationOvershootTest` | tests |
| 28 | MNT-34 | ACT-9 | `267cdfa` | link; `ActivationLinkTest` | tests |
| 29 | MNT-35 | ACT-10 | `e600278` | `snapshot`; `ActivationSnapshotTest` | tests |
| 30 | MNT-36 | ACT-11 | `41a6fe4`, `899d131` | pause, renounce refused; `ActivationPauseTest`, `ActivationOwnershipTest` | tests |
| 31 | MNT-37 | ACT-12 | `e4d2063`, `899d131` | roles; `ActivationRolesTest` (interface pinned from `out/`); `test/poc/ForgedLevelRegression.t.sol` | tests ⚑ |
| 32 | MNT-38 | ACT-13 | `002e618`, `899d131` | events; `ActivationEventsTest` | tests |
| 33 | MNT-39 | ACT-14 | `a4ab688`, `899d131` | reads; `ActivationReadsTest` | tests |
| 34 | MNT-62 | OPS-2 | `dbb505b`, `899d131` | `script/Deploy.s.sol`, `script/config/example.json`; `Deploy.t.sol`; spec change `20be8fe`; ACT-1's deferred I-3 (one-step `transferOwnership` of `Activation`) | scripts ⚑ + dimensional |
| 35 | MNT-63 | OPS-3 | `4ffbdda`, `899d131` | `script/verify.sh`, `test/fixtures/`, the CI step | scripts |
| 36 | MNT-66 | OPS-6 | `b8f57eb` | `script/Enforcement.s.sol`, `docs/RUNBOOK.md`; `Enforcement.t.sol` (forge-lint note: unused import, `:7`) | scripts |
| 37 | MNT-96 | NONE | `b16a75b` | `CLAUDE.md`, `README.md` (whole) | docs |
| 38 | MNT-97 | NONE | `17a5097` | `test/*.tree.md` | docs |
| 39 | MNT-98 | NONE | `c44f4bb` | `docs/HANDOVER.md`, `docs/prompts/` | docs |
| 40 | MNT-113 | ACT-7 | `174fa96`, `899d131` | the whole v2.2 change: spec delta, `Activation`, deploy script, docs | logic ⚑ |
| 41 | MNT-114 | NONE | this handover | `docs/HANDOVER.md`, this prompt, `reports/tranche-1-review-log.md`, `docs/tools/check_scenario_quotes.py` | docs |

ACT-1's review was presented and its findings settled by MNT-113 (see the log); present MNT-26
again against the new code, briefly, and review it independently from scratch. MNT-32's original
code is deleted: review ACT-7 as the burn route `Activation.burn` now is.

**Then, as `docs/prompts/tranche-1-review.md` "When every Task is Done" says:** two or three narrow
`solidity-auditor` passes over `src/`; `reports/tranche-1-review.md` from the log (offer it, publish
nothing); refresh the counts in `docs/HANDOVER.md` and the rehearsal prompt; tell me `tranche-1` is
ready to merge; write `docs/prompts/del-6-client.md`, folding in the log's "DEL-6 notes".

**Never:** set Done without my word for that Task; push; merge into `main`; build the client
document without my word; silence a Slither finding or a lint; write a fuzz, invariant or fork
harness; relitigate a settled decision (HANDOVER's list, and every settlement in the log); edit a
bridge-owned field.
