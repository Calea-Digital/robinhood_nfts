# Integrity check — 2026-10-14 (final, after MINT's answers of 12 October)

**Scope:** the spec, the register, the prose views, the client documents, the board, both
repositories, and the two Task branches in review.
- **NFT:** `feat/contracts` = `release/1.1` = `f1f9ce6` (PR #13 merged, 13:25 UTC; `feat/contracts`
  restored and pushed). MNT-160 `mnt/NONE-wl-removal` at `22c1120` and MNT-161 `mnt/NONE-every-bear`
  at `01b5f91`, local worktrees, not pushed.
- **Here:** `main`, every change of the session committed. The question-by-question checks are in
  `reports/integrity-check-2026-10-14.md`.

## Automated checks

| Check | `feat/contracts` (`f1f9ce6`) | MNT-161's branch (holds MNT-160 too) |
|---|---|---|
| `forge fmt --check` | pass | pass |
| `forge build --force --sizes` | 0 warnings | 0 warnings |
| `forge test` | 328 passed | 246 passed |
| Coverage (lines, statements, branches, functions) | 100 / 100 / 100 / 100 | 100 / 100 / 100 / 100 |
| Slither | 51, no High or Critical | 41, no High or Critical |
| `test/verify.test.sh` | pass | pass |
| Client `pnpm run check` | — | ABIs current (5), 104 tests passed |
| `check_scenario_quotes.py` | 37 / 3 (expected: RAF-16, 27, 28 change with MNT-161) | 40 / 0 |
| `check_tree_tests.py` | 26 / 0 | 26 / 0 |

| Spec-side check | Result |
|---|---|
| `openspec validate --specs` | 6 passed, 0 failed |
| `lint_spec.py` | OK: 60 active requirements, 24 decisions |
| `render_calea_prose.py --check` | both views current |
| `build_client_doc.py --check` | §10's open items match the register |
| `board.sh --dry` | 0 to create, 0 to refresh; WL-1 and WL-5 tracked but excluded (informative) |
| Bridge validator (last write, 12:53 UTC) | no traceability problems: 89 requirements, 24 decisions |

## Register, §10 and board

- **Register:** 22 resolved or closed. **CQ-2** is in follow-up (the mainnet $MNTD address,
  19 October). **CQ-22** is open (prize delivery, needed by 17 October; options A, B and C with
  MINT).
- **§10:** O1 CQ-22 (17 October), O2 CQ-2 (20 October), in date order. HANDOVER's table matches.
- **Board decisions:** MNT-139 (CQ-22) Open, due 17 October; MNT-73 (CQ-2) In Progress, due
  20 October. Every other decision is Done.
- **Board work:**
  - In Review: MNT-160, MNT-161, both tranche-2 line 0.1 and 0.2, ticked.
  - Open and free: RAF-14 (MNT-55), OPS-4 (MNT-64), OPS-1 (MNT-61), OPS-5 (MNT-65).
  - Open and gated by CQ-22: RAF-18 (MNT-59).
- **Session spec changes**, all archived and on the board:
  - `prize-wallet-short-form`, `cq-12-admin-confirmed`, `renumber-open-items`,
    `ops-5-owner-rotation`;
  - `wl-mint-on-opensea`, `opensea-checks-on-mainnet`, `wl-register-rules`,
    `ops-2-box-draw-constructors`;
  - `raf-every-bear-plays`, `drop-open-item-numbers`, `raf-33-prize-chains`;
  - `cq-17-calea-subscription`, `cq-23-mint-runs-worker`, `wl-5-dates-settled`.

## Findings

**Fixed in this check:**
- **F-1.** HANDOVER's "For the portal team" still had mint proofs from the CSV with
  `buildAllowList`. Now: holders mint on OpenSea's drop page, and the page reads the mint's
  progress.
- **F-2.** HANDOVER called WL-7 (MNT-134) In Review. It is Canceled (retired in v2.5).
- **F-3.** HANDOVER's "Next" list was from 9 October (RAF-14 gated by CQ-23, a tooling item
  already done). It is rewritten for 15 October.
- **F-4.** The box's and the draw's deploy entry points are needed by 29 October and were no
  `tasks.md` line. `Deploy.s.sol` has only `runCollection` and `runActivation` besides the
  registries' entries that MNT-160 removes. Added as tranche-2 line 0.4 (a Defect against OPS-2,
  which is Done).
- **F-5.** The rehearsal on 16 October had no `tasks.md` line for its preparation (configs, the
  SeaDrop allowlist script with proofs). Added as line 0.5, on OPS-4's Task.

**Open, by owner:**

| # | Finding | Owner | When |
|---|---|---|---|
| O-1 | Review and merge MNT-160, then MNT-161. Until then `feat/contracts` holds the registries and the exclusion, and the quote check reads 37/3 there. CLAUDE.md already describes the branches | the person, with Calea | 15 Oct |
| O-2 | Send the prize-delivery message (CQ-22) | the person | by 17 Oct |
| O-3 | Test $MNTD for the rehearsal wallet | the person asks MINT | before 16 Oct |
| O-4 | PR B is stale. Rebuild it over MNT-160, MNT-161 and MINT's #14 and #15 (whose lockfile change is now on `feat/contracts`) | Calea, then Lorenzo | 20–21 Oct |
| O-5 | The bridge keeps "depends on" links from `→ CQ-n` text after the decision resolves (MNT-55, MNT-61 to Done CQ-23, CQ-17, CQ-11). They gate nothing | ai-stack bridge (W6 sweep) | any time |
| O-6 | MNT-154 (the move into NFT) has been In Progress since 7 October. It closes with PR B, as does MNT-71 (DEL-9) | the person | with PR B |
| O-7 | Human tasks open on the board: MNT-146 (multisig, left as is), MNT-145 and MNT-133 (Rayco's and Sergio's) | the person | — |
| O-8 | Which Calea wallet holds the VRF subscription (CQ-17), and the payout key's creator if CQ-22 is C | Calea; MINT | at `PrizeDraw`'s deployment |
| O-9 | `?since=` on MINT's wager API (WL-1) | MINT | — |
| O-10 | `MintABear-Specification-v2.6.pages`, the last specification MINT received, prints the prize wallet as `0xf6c0…e3e3`; the next client document corrects it | Calea | next client document |
| O-11 | Untracked `lib/` here (forge-std, seadrop, solady), left from the port. Not committed, not touched | the person | — |

## Verdict

The spec, register, prose, board and code agree. The one known gap is O-1: two Task branches
in review that the spec already describes. Development can continue tomorrow in the order of
HANDOVER's "Next".
