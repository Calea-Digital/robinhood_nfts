Start this session in `~/trees/robinhood_nfts` with `../NFT` added (`claude --add-dir ../NFT`).

The session has two parts. **First, an integrity check** of the internal docs, YouTrack and the code
against each other: a report, with nothing fixed without my word. **Then `/mnt:next`**, working
through the work loop in CLAUDE.md ("The work loop") one Task at a time, with a merge into
`feat/contracts` only when I accept the Task. Plant a deliberate breakage for each property you
test before `/mnt:done`.

**Read first, in this order:**
1. `docs/HANDOVER.md`: "Session of 15 October (the follow-up)" and "Next, in this order (written at
   the end of 15 October)".
2. `reports/integrity-check-2026-10-15.md`: the last check's format and its open items (IC-n).
3. `openspec/changes/tranche-2/tasks.md`: the pick order. 3.7 (Defect MNT-170) is first, then 0.3
   (PR B), 5.1–5.6 (the prize vault) and 4.2 (RAF-18).

**Where things are (end of 15 October):**
- `feat/contracts` is at `5afada1`, pushed, and is the head of open PR mintdotio/NFT#17 into
  `release/1.1` (`f1f9ce6`). It is checked out in the worktree `~/trees/NFT-every-bear`, which also
  holds the untracked testnet broadcasts under `packages/contracts/broadcast/` (keep them; do not
  commit them).
- The main checkout `~/trees/NFT` is on `feat/contracts-client-workspace` (PR B, `7087acc`, 13
  behind). `~/trees/NFT-wl-removal` is on `mnt/RAF-14`, already merged.
- The testnet contracts are live and owned by the rehearsal wallet `0x7672…04Aa` (HANDOVER,
  "Verified on-chain facts"). Its keystore was removed after the rehearsal.
- No Task is In Review. MNT-59 (RAF-18) is In Progress with a plan made before CQ-22 was resolved.

## Part 1: the integrity check

Report to `reports/integrity-check-2026-10-16.md` in the format of the 15 October report: each
finding as IC-n with what disagrees with what, the evidence (file:line, issue id, command output),
and a proposed fix with its owner. Fix nothing yet; I decide item by item. Check:

1. **Spec ↔ board.** Run `docs/tools/board.sh --dry`: expect 0 created and 0 refreshed after
   15 October's write. Also:
   - every `tasks.md` line's issue is in the state its tick says: ticked means In Review or Done,
     unticked means Open or In Progress;
   - MNT-166, 167 and 168 sit under the RAF milestone with the Tranche 2 tag;
   - CQ-22 (MNT-139) is resolved and gates nothing;
   - MNT-164 (the mainnet checks, a Subtask of MNT-64) and MNT-95 are Open;
   - MNT-170 is Open and named in `tasks.md` 3.7.
2. **Spec ↔ code.** For every requirement the code claims, run
   `python3 docs/tools/check_scenario_quotes.py` and `python3 docs/tools/check_tree_tests.py`.
   - Expect stale or missing coverage for what 15 October's change modified (RAF-14, 16, 17, 18, 32,
     33, 34, OPS-2, 3, 7, DEL-6, 8). Say which are covered by the vault lines 5.1–5.6 and which are
     not covered by any line.
   - RAF-35, 36 and 37 have no code yet: confirm the checks report them as not quoting rather than
     failing.
3. **Docs ↔ code ↔ spec.** Check each of the following for statements the code or the spec no
   longer support:
   - `CLAUDE.md`'s architecture table and paragraphs;
   - `docs/HANDOVER.md`;
   - `docs/SPECIFICATION.md`'s narrative and §10;
   - NFT's `packages/contracts/README.md`, `docs/DESIGN.md` and `docs/RUNBOOK.md`;
   - `packages/contracts-client/README.md`;
   - the three `docs/client/MINT-prompt-*.md`.

   Watch especially for "no vault", "no contract on a prize chain", "prizes in MINT's wallet",
   "paid by transfer", "a win with no `PrizePaid` is a prize still owed", and test counts.
4. **Board ↔ git.** For every Done Task merged since 14 October (MNT-160 to 165, 169, 55, 64):
   - the accept comment's merge commit is on `feat/contracts`;
   - its tree equals the reviewed head.

   Also, no `mnt/*` branch is unmerged without an In Review or In Progress Task, and nothing
   private is in NFT's history since `f1f9ce6` (an `MNT-n` id, `openspec`, `robinhood_nfts`,
   HANDOVER).
5. **PRs.**
   - #17's state, head, mergeability, and whether its description matches `feat/contracts`.
   - #16 (MINT's) does not touch our paths.
   - PR B is still 13 behind and merges cleanly.
6. **Tooling.**
   - CLAUDE.md and the board hook name `docs/tools/spec_tools/fold_archive.py`, which does not exist
     (on 15 October the decisions fold was done by hand). Propose either building it in ai-stack or
     changing the instruction.
   - Confirm `check_tree_tests.py` is in the ai-stack `/mnt:done` template.
7. **The worktrees** listed above: say which can be removed. Remove nothing.

End Part 1 by showing me the IC list, sorted by what blocks the next Task first.

## Part 2: `/mnt:next`

After I have answered the IC items, run `/mnt:next`. It should take `tasks.md` 3.7, **Defect
MNT-170**: the client refuses a malformed or bad-checksum address with `INVALID_ARGUMENT` before
any RPC call, at every address input on the facade, and `planTransfer` never returns `ok` for a
recipient it cannot encode. The issue's body has the reproduction and the fix shape. Its branch is
`mnt/DEL-6-170` off `feat/contracts`. A merge into `feat/contracts` after my accept adds it to PR
#17 only when I say push.

Then continue down the pick order on my word: 0.3 (PR B), then the prize vault 5.1 (RAF-35,
MNT-166). For the vault:
- read `openspec/changes/archive/2026-10-15-raf-prize-vault-claims/`, including the proposal's
  grilling record and out-of-scope list and the design's risks: they are binding;
- the skills are `openzeppelin-skills:develop-secure-contracts` for patterns (Solady wins where it
  differs, as in the box and the draw) and `evm-internals` for storage and gas;
- no fuzz or invariant harnesses.
