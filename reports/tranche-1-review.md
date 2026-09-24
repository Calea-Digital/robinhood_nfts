# MintABear tranche 1 — review report

Paired review of branch `tranche-1` (off `main` at `746acbe`) by the reviewer and Claude,
2026-09-23 and 2026-09-24, from `docs/prompts/tranche-1-review.md` and
`docs/prompts/tranche-1-integrity-and-review.md`. The finding-by-finding record, with every
commit, is `reports/tranche-1-review-log.md`; this report is its summary.

## Result

- **Every tranche-1 Task is Done** on the board: COL-1…13, WL-1, 3, 4, 5, ACT-1…14, OPS-2, 3, 6 and
  the non-spec MNT-92…94, 96…98 — 39 Tasks — each with a `Reviewed — Done` comment and logged time.
- **No Critical, High or Medium finding survived** in the contracts. One Medium (MNT-22, a
  wallet-relative allocation index) and the Lows were fixed or accepted; the tranche-end
  `solidity-auditor` passes found nothing above Low, and nothing Low in the contracts' own code.
- **29 Defects** raised and fixed (MNT-99…112, 115…118, 120…130), each on its own branch through
  every gate and merged `--no-ff`; one architecture change (MNT-113: `Activation` burns $MNTD
  itself, spec v2.2).
- **State at the end:** 214 tests, 100 % line, branch and function coverage, no build warnings,
  Slither no High or Critical (the two accepted `locked-ether` Mediums remain), spec lint and
  generated prose current, `board.sh` read-back with no traceability problems.

## Method

For each Task: presented (spec block and Scenario, code, tests, tree, history); reviewed
independently with the lens the Task called for — `differential-review` with the
`adversarial-modeler` on value- or role-moving Tasks, the `dimensional-analysis` validator on
scaled arithmetic, mutation checks on test-only Tasks (name the code change that would survive;
where one did, the gap became a Defect), scripts run and dry-run, docs read against the code;
settled with the reviewer; Done only on the reviewer's word. Before the second half, an integrity
check compared spec, prose views, client document, code and board with each other. At the end,
three narrow `solidity-auditor` runs over `src/`, one per contract.

## Findings by family

### Collection (`MintABear`)

| Task | Finding | Settled |
|---|---|---|
| COL-9 MNT-15 | Scenario block not the spec's text; absence checked against old selectors only | Fixed, MNT-99 |
| COL-5 MNT-11 | Bare `expectRevert` in the provenance test; artwork immutability is off-chain | Fixed, MNT-100; immutability accepted |
| COL-8 MNT-14 | 42 COL test blocks did not quote their Scenario | Fixed, MNT-101 (sweep; checker `check_scenario_quotes.py`) |
| COL-1 MNT-7 | Canonical SeaDrop wiring never asserted; owner can add a minter | Fixed, MNT-102; minter accepted (HANDOVER) |
| COL-2 MNT-8 | Bare `expectRevert` on SeaDrop's cap error | Fixed, MNT-103 |
| COL-6 MNT-12 | Zero-receiver refusal untested; no runbook step for royalties | Fixed, MNT-104 |
| COL-7 MNT-13 | Fork-2 wording (Seaport is the caller; STATICCALL question) | Fixed, MNT-105 |
| COL-10 MNT-16 | `renounceOwnership` unguarded and one-step; handover never verified | Spec amended (never renounced); fixed, MNT-106 |
| COL-3, 4, 12, 13 | None beyond Informational notes | Accepted |

### Whitelist (`WhitelistClaim`, export script)

| Task | Finding | Settled |
|---|---|---|
| WL-3 MNT-22 | **Medium**: `allocationIndex` was wallet-relative — a $50 account could claim tier 1 in two wallets; renounce froze the signer | Spec amended (the index is the account's; renounce refused); fixed, MNT-108 |
| WL-1 MNT-20 | Thresholds attributed to wallets, not accounts | Spec wording; tree, MNT-109 |
| WL-5 MNT-24 | 48-hour gap asserted against the test's own constant; runbook silent | Fixed, MNT-110 |
| MNT-93 | Export and compare did not refuse while claims were open | Fixed, MNT-111 (`CampaignStillOpen`) |
| MNT-92, 94 | Docs behind the code | Fixed, MNT-107, MNT-112 |
| WL-4 MNT-23 | None | — |

### Activation

The first review of ACT-1 found the owner could point the crediter at itself and record levels
without a burn (Low). The reviewer and Claude changed the architecture instead of patching it:
`Activation` takes $MNTD in its constructor and burns it itself (MNT-113, spec v2.2), and the
ACT family was then reviewed against the new code.

| Task | Finding | Settled |
|---|---|---|
| ACT-1 MNT-26 | Record-before-`burnFrom` unpinned (swapping them passed the suite) | Fixed, MNT-116 |
| ACT-4 MNT-29 | Check order `NotBearOwner` / `AlreadyAtMaxLevel` unpinned; unminted-id revert undocumented | Fixed, MNT-117 |
| ACT-9 MNT-34 | No test linked a bear that had changed hands (the link's counter write survived mutation) | Fixed, MNT-118; CQ-21 raised (an account's several links) |
| ACT-10 MNT-35 | `snapshot` is quadratic over an untransferred mint batch (measured: 56.2M gas for 1..4444) | Documented, MNT-120; accepted risk; split-script and mint-batch rules |
| ACT-12 MNT-37 | The interface pin could not see a `fallback` or `receive` (a level-writing fallback passed) | Fixed, MNT-121 |
| ACT-13 MNT-38 | `BearActivated`'s `previousLevel` and argument order unpinned | Fixed, MNT-122 |
| ACT-14 MNT-39 | `THRESHOLD_1…5` public reads the spec does not name | Fixed, MNT-123 (internal) |
| ACT-2, 3, 5, 6, 7, 8, 11 | Typos and carried items only (ACT-7's HANDOVER line went to OPS-2) | Fixed in MNT-117, MNT-124 |

### Operations (scripts)

| Task | Finding | Settled |
|---|---|---|
| OPS-2 MNT-62 | `Activation`'s immutable inputs unchecked (a wrong collection deploys); config array lengths; no runbook read-back | Fixed, MNT-124 (`NotTheCollection`, `ConfigLength`, runbook "Activation") |
| OPS-3 MNT-63 | `verify.sh` passed on an empty broadcast set; verdict branches untested | Fixed, MNT-125 (offline verdict test in CI) |
| OPS-6 MNT-66 | `enable` could not restore V3 over another validator | Fixed, MNT-126 |

### Docs and trees

MNT-96 (CLAUDE.md, README), MNT-97 (trees; OPS-3 had no leaf), MNT-98 (HANDOVER, rehearsal
prompt): fixed in MNT-127, MNT-128, MNT-129.

## Integrity check

Run before the second half. It found the bridge blocked (a duplicated Spec Ref), 16 Tasks whose
comments still described the pre-v2.2 design, stale narrative in the specification's §10, stale
`tasks.md` lines, and — in the v2.1 client document — two callouts clipped at the page edge
(CQ-18, CQ-9). Fixed through the board and MNT-115; the rest carried to their Tasks.

## Tranche-end pass

Three narrow `solidity-auditor` runs (`Activation`; `MintABear`; `WhitelistClaim`):

- **T-1 Low:** SeaDrop's allowlist limit counts every mint to a wallet, so a claimant who minted in
  an earlier stage loses whitelist mints. WL-4 amended (the whitelist stage comes first); runbook
  and rehearsal follow (MNT-130).
- **T-2 Low:** SeaDrop pre-approves OpenSea's conduit for every holder, irrevocably; not deployed
  on 4663. Accepted as a risk; Fork-2 and the rehearsal check it.
- **T-3 Info:** at level 0 a sale arranged outside a marketplace pays no royalty. COL-7 reworded.
- **T-4…T-6 Info:** backend voucher rules and the split's reading rules — into the DEL-6 prompt.
- One lead closed (the counter advances before the owner changes, but only a `view` validator
  call runs in the gap).

## Specification changes

All through archived OpenSpec changes with the reviewer's go: COL-10 (never renounced), WL-3 (the
account's allocation; renounce refused), WL-1 (wording), v2.2 (`Activation` burns $MNTD; ACT-1,
2, 4, 6, 7, 8, 11–14, OPS-1, 2, 4, DEL-8), ACT-9 (→ CQ-21), CQ-2 and CQ-21 `Blocks`, WL-4 (stage
order), COL-7 (what enforcement covers). New decision **CQ-21** (open).

## Accepted risks added by the review

The owner can add a minter (COL-1); reading owners over an untransferred mint batch is expensive
(ACT-10); OpenSea's conduit is pre-approved (T-2); a sale outside a marketplace pays no royalty
(T-3). The earlier accepted risks stand (`docs/HANDOVER.md`).

## For MINT, with the v2.2 document

The stage order (CQ-18: the whitelist stage first); how Status counts an account's several links
(CQ-21); the conduit preapproval; what royalty enforcement covers; and — when v2.2 is built — the
two callouts clipped in v2.1.

## Open

- The v2.2 client document, built on the reviewer's word, with its callouts fitted to their pages.
- The OPS-4 rehearsal (MNT-64, MNT-95) and the internal auditor's INV-N and Fork-N obligations.
- `test/fixtures/merkletreejs-vector.js` run once npm access is agreed (MNT-111).
- Board, by hand: MNT-124's extra parent (MNT-4); MNT-127's parent (MNT-3); links MNT-113 ↔ MNT-31
  and MNT-114 ↔ MNT-26.
