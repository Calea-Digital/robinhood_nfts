# Integrity check, the PR into release/1.1, and MINT's questions: session prompt

Open a fresh Claude Code session in `~/trees/robinhood_nfts` on `main`, with `~/trees/NFT` added
(`claude --add-dir ../NFT`). The YouTrack connector must be connected, and `gh` logged in for
`mintdotio/NFT`. Paste everything below the line.

---

Four jobs this session, in order, each shown to me before the next:
1. a system integrity check;
2. bring `feat/contracts` level with `release/1.1`;
3. open the PR;
4. a Pages document of every question MINT must answer to unblock us.

The document goes to MINT **today**, and we expect a meeting with their answers on **Monday
12 October 2026**.

**Where things stand (2026-10-09, end of day).**
- **Code.** `feat/contracts` in `~/trees/NFT` is at `bc89abb`, **pushed** (`origin/feat/contracts`
  = `bc89abb`).
  - It contains all of `origin/release/1.1`: 0 commits behind, as of the push.
  - Every gate is green: fmt; 0 warnings; 328 tests; coverage 100/100; Slither 51 with no High or
    Critical; `verify.sh` and `test/verify.test.sh`; the client's 180 tests; quotes 40/0.
  - No Railway-watched path changed since PR A (NFT#12, merged 7 October).
- **Done since PR A** (every Task Done on my accept):
  - **The whitelist fixes:** `compare` decides UTF-8 from the bytes, and the client's input edges are
    handled (Defects MNT-155, MNT-156).
  - **`MysteryBox` on 4663:** RAF-32, RAF-27, RAF-28, RAF-34.
  - **`PrizeDraw` on Arbitrum One:** RAF-8, RAF-29, RAF-30, RAF-33, and Defect MNT-157.
  - **Both contracts:** RAF-16 (events), RAF-17 (every read, both interfaces pinned), RAF-19 (every
    acceptance case has a test).
  - **The client's mystery-box calls** (Defect MNT-158, DEL-6, `tasks.md` line 3.5): the play page,
    MINT's admin page on both chains, and the worker.
- **Not built yet:**
  - **The deploy entry points** for `MysteryBox` and `PrizeDraw`. They aren't a `tasks.md` line yet.
  - **RAF-14 and RAF-18**, gated by CQ-23 (RAF-18 also by CQ-22).
  - **OPS-4, the rehearsal**, waiting on the testnet $MNTD.

**Read first:**
- `CLAUDE.md`: the two repositories, the work loop, and the rules for NFT.
- `docs/HANDOVER.md`: "Next session", "Open questions with the client", "Unknowns to settle by
  rehearsal", "Accepted risks".
- `reports/integrity-check-2026-10-09.md`: the last check's format, and its open items (IC-n).
- `openspec/decisions.md`: the `CQ-n` register.
- `docs/OPEN-QUESTIONS.md`: the generated view of the register.
- `reports/del-6-158-diff-review.md`.

## 1. The system integrity check

Check that the spec, the board and the code agree, and that every document says what is true now.
Write `reports/integrity-check-<date>.md` in the 9 October report's format: findings IC-n by
severity, each with its evidence and a **Route**.

**Spec ↔ board:**
- `docs/tools/board.sh --dry`, then `validate --check-issues`.
- Every requirement Task's State matches `tasks.md` (ticked means In Review or Done).
- Every decision Task's State matches the register.
- The gating links match the register's `Blocks`.
- MNT-158 (DEL-6) sits as tranche-1 lines 6.2 and 6.3 do.

**Spec ↔ code:**
- Each Done requirement's technical note names what the code has: functions, errors, events, reads.
- Pay most attention to RAF-17's "no other public read exists" against the interface pins, and to
  RAF-29's `InsufficientGas`.
- Every Scenario has its test and tree leaf (`python3 docs/tools/check_scenario_quotes.py`).
- Every test a tree names exists. The RAF-19 review set this check aside as tooling: do it by hand
  here, and propose the tool.

**Code ↔ docs:**
- `CLAUDE.md`'s architecture table and contract descriptions. It has no `MysteryBox` or `PrizeDraw`
  rows yet, and no client rows for them.
- NFT's `README`, `docs/DESIGN.md`, `docs/RUNBOOK.md` (IC-7: they lacked the mystery box).
- The client's `README`.
- `docs/HANDOVER.md`.

**Housekeeping:** the open IC items from 9 October (IC-4, IC-6, IC-7, IC-8, IC-9, IC-17, IC-18).
Say which still stand.

**Fixing:**
- Fix stale docs in **this** repository as you go, and commit them.
- A fix in NFT's docs goes on a branch off `feat/contracts`, merged only on my word, the same as a
  Task.
- Spec changes go through `/opsx:propose` with my go.
- Show me the report and the fix list before step 2.

## 2. Bring `feat/contracts` level with `release/1.1`

I asked for a rebase. `CLAUDE.md` forbids rebasing or force-pushing the pushed `feat/contracts`, and
the documented route is a merge (`git merge origin/release/1.1` on `feat/contracts`).

- `git fetch origin`, then count what `origin/release/1.1` has that `feat/contracts` lacks.
- **If nothing,** as at the end of 9 October, there is nothing to do: say so.
- **If something,** merge it, re-run the full gates on the result, and push only on my word.
- **Never rebase or force-push without my explicit word in this session,** and tell me what it would
  rewrite first.

## 3. Open the PR into `release/1.1`

1. Check that no PR from `feat/contracts` is already open (`gh pr list --repo mintdotio/NFT --head
   feat/contracts`).
2. Scan the diff and the commit messages for private references: an `MNT-n` id, `openspec`,
   `robinhood_nfts`, `tasks.md`, `decisions.md`, HANDOVER, outside `lib/`.
3. Re-run the full gates on the head.
4. Open the PR with `gh pr create --base release/1.1 --head feat/contracts`. The body has:
   - what it adds, by Spec Ref, in plain words for MINT's developers:
     - the mystery box on Robinhood Chain;
     - the draw on Arbitrum One;
     - the client library's new calls for the play page, the admin page and the worker;
     - the whitelist fixes (no `MNT-n` ids anywhere);
   - "no Railway-watched path; merging does not redeploy staging";
   - the gates' results;
   - the checks to run on staging and the testnets after merge:
     - a real Chainlink callback after a worker relay, on 46630 and Arbitrum Sepolia;
     - the admin page's `scheduleCycle` with one Privy wallet;
     - the deploy entry points are still to come, so the contracts are not deployed by this PR;
   - the PR footer from the attribution rules.
5. Give me the URL. Merging is mine.

## 4. The questions for MINT, as a Pages document

Compile everything we need from MINT to be unblocked. The sources:
- **The register:** every decision in `openspec/decisions.md` that is open or in follow-up. At the end
  of 9 October these were CQ-1, CQ-2, CQ-12, CQ-17, CQ-20, CQ-22 and CQ-23. Read each one's
  remaining item, its `Needed by` and what it blocks.
- **The board:** every MNT Task that is **Open** or **In Progress**.
  - `search_issues` for `project: MNT State: Open` and `project: MNT State: {In Progress}`, paging
    past 20.
  - For each, say whether it waits on MINT and for what. Leave out what doesn't.
- **The handover:**
  - "Open questions with the client";
  - "Unknowns to settle by rehearsal";
  - the hand checks the reviews deferred (Studio, OpenSea's handling of a validated collection on
    4663, Privy chain switching).
- **Values the code needs before deployment:**
  - the addresses for `script/config/<chain>.json`: admin, the testnet and mainnet $MNTD, the worker,
    the prize wallet's chains;
  - the 222 excluded ids;
  - the VRF subscription's holder and its funding;
  - the dates.

**The document:**
- **Audience:** written for MINT's decision-makers. The house style is plain, short and not
  repeated: a plain statement, then what we need.
- **Grouping:** by what each answer unblocks, ordered by urgency, with dates: the mint on
  29 October, the whitelist freeze, the mystery box's first cycle.
- **Per question:**
  - the question;
  - why it blocks, and what;
  - the options, with Calea's recommendation;
  - the default we'll assume if there's no answer by Monday;
  - its `CQ-n` id where it has one.
- **Ids:** no `MNT-n` ids. They are our board's, and MINT's own tracker uses the MNT key.
- **The end:** a short checklist MINT can tick in the meeting.
- **Build it the way `docs/tools/build_whitelist_options.py` builds its brief:**
  - the text in a `docs/tools/build_<name>.py` script;
  - the layout from `build_client_doc.py`'s WordprocessingML builder;
  - Pages saving it as `docs/client/MintABear-Questions-2026-10-12.pages` via AppleScript.
- **Verify it:**
  - export to PDF;
  - extract the text and check every question is present;
  - check no page is sparse (a heading stranded above a table).
- **Show me** the outline before building, and the PDF's page list after.
- **Don't send it.** I send it. Commit the script and the `.pages` here.

**Never:**
- touch `release/1.0` or `main` in NFT, or merge the PR;
- put a fuzz or invariant harness in NFT;
- put an `MNT-n` id or a private path into NFT or into the document for MINT;
- edit a bridge-owned field on the board by hand.

**At the end:** update `docs/HANDOVER.md` "Next session" and the memory pointer, with the PR's URL
and the document's path.
