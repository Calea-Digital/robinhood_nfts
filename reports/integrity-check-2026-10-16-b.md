# Integrity check — 16 October 2026, after `vault-prose-alignment`

**Scope:** the internal docs, YouTrack and the code, against each other, before `tasks.md` 5.1.
Nothing was fixed.

**State of NFT:**
- `release/1.1` is `617217f` (#17 merged).
- `feat/contracts` is `e67bd96`, in `~/trees/NFT-every-bear`, local only: 0 behind and 4 ahead
  (MNT-171 and the merge).
- `~/trees/NFT` is on `feat/contracts-client-workspace` `363b269`, PR #20, pushed: 0 behind and
  6 ahead. It contains `feat/contracts`, so MNT-171 also exists on the remote.
- `mnt/RAF-18` is `ce7606a`: 18 behind and 1 ahead.

## Checks

| Check | Result |
|---|---|
| `board.sh --dry` | 0 created, 0 refreshed; 81 CURRENT, WL-1 and WL-5 tracked but excluded; lint OK |
| Generated prose and client-document check | current; §10's open items match the register |
| `check_scenario_quotes.py` / `check_tree_tests.py` (code root `NFT-every-bear`) | 41 / 0 · 26 / 0 |
| `tasks.md` against the board | unticked lines: 0.3 MNT-154 In Progress, 4.2 MNT-59 In Progress, 5.1–5.3 MNT-166–168 Open; 5.4–5.6 have no issue yet (Defects when picked). In Progress besides those: only CQ-2 (MNT-73, follow-up). MNT-170 and 171 are Done |
| Private text in NFT since `f1f9ce6` | none on `feat/contracts`, PR #20 or `mnt/RAF-18` (the only matches are the word "handover") |
| Open PRs | #20 ours, MERGEABLE, no review yet; #16, #18 and #19 MINT's |
| Worktrees | `~/trees/NFT` (PR #20) and `~/trees/NFT-every-bear` (`feat/contracts`, untracked `broadcast/`, keep). No others |
| This repository | clean apart from `.memsearch/` and `lib/`; `main` is 2 ahead of `origin/main` (`c01ef31`, `e4aee51`), not pushed |
| Prize-wallet wording | specs clean; leftovers are listed below |

## Findings

### New

**IC-19. CQ-10's Resolution still describes the wallet model.**
- `openspec/decisions.md`, CQ-10: "there is no vault to claim from; a win is paid from MINT's
  prize wallet … a 30-day window applies only if it is requested."
- CQ-22 answered it on 15 October: a winner claims from the vault until one hour after the
  cycle's end (RAF-36), and an unclaimed prize carries over (RAF-37). The Summary already reads
  "Superseded by CQ-22"; the Resolution line and the record do not say what replaced it.
- `vault-prose-alignment` (IC-7) missed it because its search covered "no contract", "no vaults"
  and "nothing on-chain locks", not "no vault to claim from".
- It shows in `docs/OPEN-QUESTIONS.md` and in the client document.
- **Proposed:** a decisions-only change (`skip_specs: true`), the same shape as CQ-8, CQ-11 and
  CQ-20: a "Superseded (MINT, 15 October 2026, CQ-22)" paragraph and a Resolution line. Before
  the next client document; it does not block 5.1. **Owner:** Calea.

**IC-20. Three open PRs change `pnpm-lock.yaml`: #16, #19 and #20.**
- #19 (`feat/app-preview`, MINT's, opened 16 October) adds `apps/app-preview` and changes the
  lockfile, like #16.
- Whichever of the three merges after another has to regenerate the lockfile. If ours is the
  later one, merge `release/1.1` into `feat/contracts-client-workspace`, run `pnpm install`,
  check that no version moved, and re-run #20's proof (the frozen install, each Dockerfile's
  install, `pnpm -r test`).
- Railway does not deploy #20 as a preview: `jedibojan` is not in MINT's Railway workspace (the
  bot's comment on #20). The staging proof therefore comes only after the merge.
- **Proposed:** say this on #20 when one of the others merges; nothing to do now.
  **Owner:** Calea.

**IC-21. `mnt/RAF-18` is 18 commits behind `release/1.1`.**
- It branches from before #13's merge. Before 4.2 resumes, merge `feat/contracts` into it
  (never a rebase: it carries one commit), then re-run its tests.
- Not blocking 5.1. **Owner:** Calea, at 4.2.

### Carried from `integrity-check-2026-10-16.md`

| Item | Where it stands |
|---|---|
| IC-5 (#16 and PR B) | settled: #16 is not a prerequisite. IC-20 covers the lockfile |
| IC-6, IC-7 | closed by `vault-prose-alignment` (`c01ef31`), apart from IC-19 |
| IC-8 | 5.1–5.3 name every vault clause, and the HANDOVER Tests row is corrected; `check_scenario_quotes.py` still does not print the requirements with no quoting test |
| IC-9 | open. The board-reminder hook fires after every `openspec/` commit though the dry run shows nothing to write; re-run ai-stack's `install.sh` here |
| IC-10 | open, goes with 5.x. NFT's `packages/contracts/README.md:7` ("prizes are paid from MINT's wallet") and `:29` ("paid by ordinary transfer"), plus DESIGN, RUNBOOK, the client README and `PrizeDraw`'s NatSpec |
| IC-11, IC-12 | open (the client's error-table generator; the ai-stack `/mnt:done` template) |
| IC-13 | open. CLAUDE.md:7 still reads "prizes are paid from MINT's wallet on each prize chain" |
| IC-14 | mostly done in `e4aee51` |
| IC-15 | open. `docs/SPECIFICATION.md:110` says the prize wallet "holds and pays prizes", plus the rest of the narrative list; before the next client document |
| IC-16 | open. MNT-95 (Sourcify on 46630) is Open although the rehearsal verified all four contracts `exact_match` on 15 October; Done is the person's |
| IC-17 | open: MINT's prompts (prompt 1 still assumes #17 is open) |
| IC-18 | closed: worktrees and branches cleaned on 16 October |
| R-2 | open: RAF-27's Scenario title needs its own change |
| MNT-146 | open: MINT's multisig task, against CQ-12's single EOA |

## Verdict

The board, `tasks.md`, git and the specs agree, the quote and tree checks are clean, and nothing
private is in NFT. One MINT-facing register line (IC-19) and the known prose items (IC-10,
IC-13, IC-15) still describe the prize wallet; IC-10 is fixed alongside 5.x.

**Nothing blocks 5.1 (RAF-35, MNT-166).** It is Open, gated by nothing (CQ-22 is resolved), and
should get a new worktree off `feat/contracts` `e67bd96`.
