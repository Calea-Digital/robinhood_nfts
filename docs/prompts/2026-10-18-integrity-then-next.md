# Next session: integrity check, then /mnt:next

Start in `~/trees/robinhood_nfts` with `~/trees/NFT` added (`/add-dir`). Read `docs/HANDOVER.md` first,
"Session of 16–17 October" and "Next, in this order (written 17 October)".

## Part 1: project integrity check (docs, code, YouTrack)

Report only; fix nothing without the person's word. Write `reports/integrity-check-2026-10-18.md`
in the shape of `reports/integrity-check-2026-10-16-b.md`: a checks table, the findings sorted by
what blocks the next Task, the carried IC items, and a verdict.

1. **Board and specs.** `docs/tools/board.sh --dry` (source the bridge's `.env` first): what is
   created or refreshed, and the validator. Check `openspec/changes/tranche-2/tasks.md` against
   each Task's state. Run `render_calea_prose.py --check` and `build_client_doc.py --check`.
2. **NFT's state.**
   - `git fetch`; the open PRs (`gh pr list --repo mintdotio/NFT`).
   - `feat/contracts` (`c5f053b` in `~/trees/NFT-every-bear`) against `origin/release/1.1`.
   - Private text in NFT since `f1f9ce6`: `MNT-n`, openspec, robinhood_nfts, the board.
   - The worktrees and branches.
3. **Code against docs.**
   - `PrizeVault` as built against RAF-14, 16, 17 and 32–37 (every error, event and read named).
   - The vault against NFT's README, DESIGN, `PrizeVault.tree.md` (obligations, INV-32…36) and
     CLAUDE.md's file table.
   - The HANDOVER against git. MINT's prompts in `docs/client/` (IC-17) against the vault and the
     merged PR #20.
4. **Gates on `feat/contracts`.** The contracts gates, the client in the workspace
   (`npx pnpm@12.14.0 install --frozen-lockfile`, then `pnpm run check`; Corepack is too old for
   pnpm 12), the scenario-quote check and the tree check (`--code-root
   ~/trees/NFT-every-bear/packages`).
5. **Carried items.** IC-9 to IC-19, R-2, and what PR #20's merge leaves: the staging hand checks
   and `tasks.md` 0.3.

## Part 2: /mnt:next

After the person reads the report: `/mnt:next`. The candidate is 5.4, OPS-2: the vault's deploy
entry point `runPrizeVault` through the CREATE2 deployer, the RUNBOOK's vault steps and the 46630
hand check. It is a Defect against OPS-2 when picked. Branch off `feat/contracts` in a new
worktree.
