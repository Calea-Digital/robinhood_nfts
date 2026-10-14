Start this session in `~/trees/robinhood_nfts` with `../NFT` added (`claude --add-dir ../NFT`).

We are implementing every remaining feature except the mystery box's prize distribution, which waits on MINT's answer to CQ-22. Work one Task at a time through the work loop in CLAUDE.md ("The work loop"): `/mnt:next` or `/mnt:review`, the Task's gates through `/mnt:done`, and a merge into `feat/contracts` only when I accept the Task. Before you mark anything done, plant a deliberate breakage for each property you tested, then restore it.

**Read first, in this order:**
1. `docs/HANDOVER.md`: "Next (written 14 October, for 15 October)" is the plan for this session.
2. `reports/integrity-check-2026-10-14-final.md`: the state of every gate and the open items by owner.
3. `openspec/changes/tranche-2/tasks.md`: the pick order. Lines 0.1 and 0.2 are ticked and In Review; 0.3, 0.4, 0.5, 4.1 and 4.2 are open.

**Where the code is:**
- `feat/contracts` = `release/1.1` = `f1f9ce6`. PR #13 is merged, and the branch was restored and pushed.
- MNT-160: `mnt/NONE-wl-removal` at `22c1120`, in the worktree `~/trees/NFT-wl-removal`. It removes the whitelist registries and the client's mint calls. In Review.
- MNT-161: `mnt/NONE-every-bear` at `01b5f91`, in `~/trees/NFT-every-bear`. It removes the mystery box's exclusion. It is stacked on MNT-160. In Review.

**Order for this session:**
1. **`/mnt:review` MNT-160.** That means code review, adversarial QA and the gates re-run, done with me. On my accept, set it Done and merge it into `feat/contracts` with `--no-ff`.
2. **`/mnt:review` MNT-161**, the same way. Its scenario quotes take `feat/contracts` from 37/3 to 40/0.
3. **`tasks.md` 0.5, the rehearsal preparation (OPS-4, MNT-64), for the 16 October rehearsal on 46630:**
   - `script/config/46630.json` and `4663.json` for the collection;
   - a script that sets SeaDrop's allowlist from a CSV and prints each wallet's proof (`AllowListTree.proof`), because OpenSea does not support 46630.
   The test $MNTD is `0x15CF…211C`. I am asking MINT for a balance for the rehearsal wallet.
4. **`tasks.md` 0.4, the deploy entry points for `MysteryBox(owner, bears)` and `PrizeDraw(…, playable 4444, firstOpenIndex 1)`.**
   - Each reads back every constructor value, and `PLAYABLE` on both chains.
   - It is a Defect against OPS-2, which is Done. It is needed by 29 October.
5. **RAF-14** (MNT-55): roles. It is free.
6. **RAF-18's worker service** (`apps/box-worker` in MINT's repository, packaged like the whitelist API, run by MINT), built only up to prize distribution:
   - relaying each opening in order;
   - applying outcomes;
   - stateless restarts;
   - the gas and stall alarms;
   - instructions for MINT to create and fund its key with ETH on Arbitrum One.

   Leave out how a win is paid and recorded. Design the payout step as a seam that A, B or C of CQ-22 can fill. RAF-18 stays In Progress; it does not go to In Review or Done until CQ-22 is answered.
7. **`tasks.md` 0.3, PR B** (the client joins MINT's workspace):
   - rebuild it on `feat/contracts` after 1 and 2, over MINT's #14 and #15 lockfile change;
   - prove each Dockerfile's install, the apps' tests and a Privy login on staging;
   - Lorenzo merges it into `release/1.1` around 20–21 October, before the worker.

**Out of scope until MINT answers CQ-22:**
- prize vaults;
- the payout wallet;
- claim signing;
- any change to RAF-33's payout record.

`docs/client/MINT-message-prize-delivery-2026-10-14.md` is with MINT. If the answer arrives during the session, record it first through the spec process, then plan the work.

**Rules that bit us last session:**
- In this repository, never `git commit -a`. `.memsearch/` and `lib/` hold my own uncommitted files, so stage named paths or use `--only`.
- In `../NFT`:
  - no MNT-n ids;
  - no push, PR or merge into `release/1.1` without my word;
  - merging a PR on GitHub can delete `feat/contracts`, so check that it still exists before branching.
- Fork agents work in their own worktrees and never touch this repository. You do the `tasks.md` ticks, the HANDOVER and the board.
- After every spec or register edit, commit and run `/mnt:board`.

**At the end of the session:**
- update HANDOVER's "Next";
- add a short integrity entry to a new `reports/integrity-check-2026-10-15.md`;
- tell me what is ready to go to staging in a follow-up PR from `feat/contracts` into `release/1.1`.

First step: run `/mnt:review` on MNT-160.
