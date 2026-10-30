# Close the 14 In Review Defects from the 20 October review (fresh session)

Start in `~/trees/robinhood_nfts` with `~/trees/NFT` added (`/add-dir ../NFT`). Read `CLAUDE.md` and
`docs/HANDOVER.md` first. This is a review session in the `/mnt:review` spirit, but the code is
**already merged**, so there is nothing to merge. Its output is evidence on each Task and, **on the
person's explicit word, per Task or per named group of ids**, State → Done.

## Why these are In Review

These are the Defects from the pre-production review of MINT's code on 20 October 2026. Calea fixed
them, and the fixes went to staging through mintdotio/NFT **#32** (merged 20 October 15:21 UTC,
`ff2468f`) and **#33** (merged 18:11 UTC, `38cc8f3`). Nobody set them Done afterwards. Checked on
30 October:
- every fix commit, and its `feat/contracts` merge commit, is in `origin/release/1.1`;
- none is in `origin/release/1.0`, which still carries the old apps;
- production, app.getminted.io, is deployed apart from that branch (see the handover, "After #32").

| Issue | Spec Ref | What | Fix commit (merge) | PR |
|---|---|---|---|---|
| MNT-175 | NONE | `/claim` fetched `/api/vesting`; the route is `/api/claim/vesting` | `e610af6` (`2b8900e`) | #32; MINT fixed the same line in #31 (`b1edbc0`) |
| MNT-176 | RAF-18 | a malformed HTTP request crashed the box worker | `870deac` (`5593916`) | #32 |
| MNT-177 | RAF-18 | a relay or apply failure skipped the payout step | `870deac` | #32 |
| MNT-178 | RAF-18 | an RPC down at boot ended the worker before any alarm | `870deac` | #32 |
| MNT-179 | RAF-18 | deploy blocks defaulted to 0, so the healthcheck failed | `870deac` | #32 |
| MNT-180 | RAF-18 | RPC URLs with provider keys leaked into `/ready` and the webhook | `870deac` | #32 |
| MNT-181 | RAF-18 | a rival instance's relay revert raised `tick-failed` | `870deac` | #32 |
| MNT-182 | NONE | a caller-supplied `minBlock` emptied the vesting snapshot | `ab8f15b` (`0d53233`) | #32 |
| MNT-183 | NONE | `APP_TRUSTED_PROXY_HOPS=0` accepted in production | `a469da1` (`29147c8`) | #32 |
| MNT-184 | NONE | the Swap button sent the previous quote | `5de502b` (`472b05a`) | #32 |
| MNT-185 | NONE | production accepted any `SWAP_MNTD_ADDRESS` | `7d2b863` (`ca8235e`) | #32 |
| MNT-191 | NONE | a Relay outage cost every page 5 s | `8187bab` (`5d96d73`) | #33 |
| MNT-192 | NONE | `/ready` depended only on the claim RPC | `46a3207` (`eba2524`) | #33 |
| MNT-197 | NONE | the staking panel hid every failure as "could not be sent" | `eeaf600` (`b08f4ba`) | #33 |

Where each issue's evidence is:
- **MNT-175 to 185:** the description, under **Fix** (branch, commit, merge, PR). They have no
  comments.
- **MNT-191, 192, 197:** one `In Review — …` comment each, from 20 October 17:48.

## Is it safe to close them? The 30 October assessment

**Group A, safe to close after a light check (12):** MNT-175 to 183, 185, 191 and 192.
- The fixes are merged, live on staging, and each has a test that fails without it.
- The two env changes MNT-183 and MNT-185 needed from MINT are done. The handover, "After #32", says
  both hosts answered `/ready` ready at 15:34 UTC on 20 October, which needs
  `APP_TRUSTED_PROXY_HOPS=1` set and `SWAP_MNTD_ADDRESS` cleared. Re-read `/ready` on both hosts to
  confirm it still holds.

**Group B, close with a note (1):** MNT-197.
- The Defect is fixed: errors are now logged and named for the holder.
- The original "could not be sent" was never reproduced, and its cause is unconfirmed (a connector
  settling during `switchChain`). The suggested retry after `switchChain` was not done.
- Close it with that stated, and offer the person a new Defect for the retry. Don't file one
  without their word.

**Group C, not yet (1):** MNT-184.
- Its fix is in, but the component's wiring is untested. Its own note says "to check on staging in
  the MetaMask pass", and the handover's MetaMask list still has it open.
- Close it only after the person does the hand check on staging `/swap`: get a quote, change the
  amount, and the button must drop to "Getting a quote…" and never send the old quote.

**Also note:**
- MNT-191's possible follow-up, moving the Relay chain list off the shared layout, was not done.
  Mention it; it is not a reason to keep the Defect open.
- MNT-175 has two fixes, Calea's and MINT's #31, on the same line. Both tests remain.

## Steps

1. **Board snapshot.** `search_issues` for `project: MNT State: {In Review}`. Expect exactly these
   14 (MNT-211 was set Done on 30 October). Stop and report anything else, or any of the 14 already
   moved.
2. **Code.** `git -C ~/trees/NFT fetch origin`. For each fix commit,
   `git merge-base --is-ancestor <commit> origin/release/1.1`. Then run the suites that pin them, on
   a clean checkout of `origin/release/1.1` in a temporary worktree (`git worktree add --detach`;
   remove it afterwards):
   - `apps/webapp`: its `node:test` suite (175, 182 to 185, 191, 192, 197);
   - `apps/box-worker`: its tests (176 to 181).

   Use pnpm 12 (`npx -y pnpm@12.14.0`) and `install --frozen-lockfile` at the root. Name the test
   that pins each Defect: grep the tests for the behaviour, and the description or comment where it
   names the test.
3. **Live, read-only.** These reads change nothing:
   - **staging:** `/ready` returns 200 `ready`, and with the claim RPC healthy no
     `"claim": "unavailable"`; it does not echo an RPC URL or key (MNT-180 and MNT-192 shape);
   - **app.getminted.io:** `/ready`, and `/api/claim/vesting` answering (MNT-175).

   Never touch `release/1.0`, production settings, or any deployed contract.
4. **Present per group, then stop and wait:**
   - group A as one table: Defect, the test that pins it, the live read;
   - group B (MNT-197) with its note;
   - group C (MNT-184), asking the person to do the `/swap` hand check now or defer it.
5. **On the person's explicit word, naming the ids or the group:** for each Task, `update_issue`
   State → Done, and comment `Reviewed — accepted · <merge commit in release/1.1> · <UTC time of that
   merge commit>`. Read the time from git
   (`TZ=UTC0 git log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd <merge>`). Add the test
   and the live read checked, and any note (MNT-197's cause, MNT-191's follow-up, MNT-175's two
   fixes). `log_work` the review time, type Testing, split across the Tasks. MNT-184 stays In Review
   until its hand check passes.
6. **Afterwards:** update `docs/HANDOVER.md`. Remove "Board: the person sets MNT-175 to 185 Done…",
   and record what was closed and what stays: MNT-184 if deferred, and any follow-up Defect the
   person asked for. Commit only named paths here (never `commit -a`: `.memsearch/` and `lib/` hold
   the person's files).

## Never

- Never set Done without the person's word for those ids.
- Never edit bridge-owned fields (summary, description, Spec Ref, Work Kind, parent, tags, Due Date).
- Never delete issues, branches or files. Clean up only the temporary worktree you created.
- Never push, open PRs or touch `release/1.0` or `main`.
- MNT-187 and MNT-188 are not in this batch: they wait on MINT's answers.
