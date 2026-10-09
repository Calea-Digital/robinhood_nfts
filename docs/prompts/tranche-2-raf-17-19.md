# Tranche 2 — RAF-17 and RAF-19 session prompt

Open a fresh Claude Code session in `~/trees/robinhood_nfts` on `main`, with `~/trees/NFT` added
(`claude --add-dir ../NFT`). The YouTrack connector must be connected. Paste everything below the
line.

The board is the bookmark. If a Task below is already In Progress with this loop's claim, resume it
with `/mnt:resume`. If it is In Review, start at `/mnt:review`.

---

Build and review RAF-17 (MNT-58, reads) and then RAF-19 (MNT-60, acceptance cases), one Task at a
time, through the established loop: `/mnt:next` → work → `/mnt:done` → `/mnt:review` with me. A Task
merges into `feat/contracts` only on my accept.

**Where things stand (2026-10-09, end of day).**
- **Code.** `feat/contracts` in `~/trees/NFT` is at `4e74b71`, local and not pushed. Every gate is
  green: fmt, 0 warnings, 321 tests, coverage 100/100, Slither 51 with no High or Critical,
  `verify.sh`, client 141, quotes 38/0.
- **Done in tranche 2:**
  - `MysteryBox`: RAF-32, RAF-27, RAF-28, RAF-34.
  - `PrizeDraw`: RAF-8, RAF-29, RAF-30, RAF-33 (the payout record: `recordPayout`, `payoutOf`,
    `PrizePaid`, `NotAWin`, `AlreadyPaid`, `InvalidPayout`) and Defect MNT-157 (`applyOutcomes`
    refuses with `InsufficientGas`).
  - Both contracts: RAF-16.
- **Next.** `openspec/changes/tranche-2/tasks.md` lines 3.3 RAF-17 and 3.4 RAF-19 are the next
  unticked lines. Neither is gated.
- **Further on, with MINT's answers:** line 3.5 (DEL-6) still needs its own Task (MNT-69 is Done
  from tranche 1; integrity check IC-2). RAF-14 and RAF-18 wait on CQ-23 (and CQ-22 for RAF-18).

**Read first:**
- `CLAUDE.md`: the two repositories, the work loop, the test conventions.
- `docs/HANDOVER.md`: "Next session", the review recipe, "Decisions that should not be
  relitigated", "Accepted risks".
- `reports/integrity-check-2026-10-09.md`: IC-15 is about RAF-17.
- `openspec/specs/mystery-box/spec.md`: RAF-17 and RAF-19, and the requirements they cite.
- In NFT: `packages/contracts/src/MysteryBox.sol`, `src/PrizeDraw.sol`, `test/MysteryBox.t.sol`,
  `test/PrizeDraw.t.sol` and both trees.

## RAF-17 — every read answers (MNT-58)

**Done when:** every listed read is called during an open cycle, each returns without reverting,
and `odds(cycleId)` returns `(prizesLeft, idsLeft)`.

The listed reads (RAF-17's technical note):
- **Hub:** `MAX_BEARS`, `PLAYABLE`, `EXPECTED_PLAYABLE`, `MAX_CYCLE_LENGTH`, `isExcluded`,
  `currentCycle`, `cycle(id)`, `isOpen`, `opened`, `openCount`.
- **Draw:** `PLAYABLE`, `cycle(id)`, `nextToResolve`, `nextToApply`, `outcomeOf` with its
  `tokenId`, `payoutOf`, `odds`.

Settle with me before writing, with your recommendation:
1. **The reads the spec doesn't name** (IC-15):
   - hub: `excludedCount`, `paused`, `owner`, `BEARS`;
   - draw: `worker`, `paused`, `lastCycleResolved`, `openingOfRequest`, `RESOLVE_APPLY_LIMIT` and
     the VRF constants (`COORDINATOR`, `KEY_HASH`, `SUBSCRIPTION_ID`, `CALLBACK_GAS_LIMIT`,
     `REQUEST_CONFIRMATIONS`, `NATIVE_PAYMENT`).

   Name them in RAF-17's note (a small spec change, as ACT-14 names every `Activation` read), or
   accept them as unnamed.
2. **Whether to pin the public interface** of both contracts, as ACT-12's test pins
   `Activation`'s from its artifact. If pinned, a new public function fails the suite until the
   spec allows it.
3. **"Each read costs a fixed amount, whatever the number of bears".** Decide whether to assert it
   (gas of each read with 1 and with many bears, deterministic) or leave it as an INV-n line.

Then:
- The Scenario test reads every listed read in an open cycle, with meaningful state behind it:
  - exclusions done;
  - a cycle open;
  - openings on both contracts;
  - one win applied and paid;
  - one loss.

  Check values, not only "does not revert".
- `odds` must read `(prizesLeft, idsLeft)` in that order. Test it with values that tell the two
  apart.
- Tree leaves in both trees.

## RAF-19 — every acceptance case has a test (MNT-60)

**Done when:** every listed case has a passing deterministic test.

Many cases are already covered by earlier Tasks.
1. First build a table: case → existing test (file:line) → the clause it proves → a planted
   breakage that makes it fail. Show it to me.
2. Write new tests only for the gaps, and for any existing test whose breakage doesn't fail it.
3. Then the one Scenario test, or a tree section mapping each case to its test, as you and I agree.
   The quote check must pass.

Cases most likely to need work:
- "a cycle in which every playable bear is opened awards exactly its prize count, and the pool
  neither empties early nor is left over". This needs a draw with a small `PLAYABLE`; the
  constructor allows it.
- "a scheduled cycle's terms cannot change once it has started, **on either chain**";
- "a holder who sells a bear after opening it keeps its outcome";
- "an opening is asked for once, and the first word delivered for it is the one used".

## How each Task is worked

**Before `/mnt:done`:**
- Plant a deliberate breakage for every property a test claims (a mutation, then restore from a
  scratch copy, never with `git checkout` over uncommitted work). Report each one.
- Run the full gates. `/mnt:done` lists them.

**At `/mnt:review`:**
1. Code review (the `code-review` skill, medium).
2. Adversarial QA: run the cases and show a table.
3. A local run through the real entry points, read back with `cast`:
   - **`MysteryBox`:** a 46630 fork, with the collection from `Deploy.s.sol runCollection` and
     bears minted by impersonating SeaDrop. Use fresh wallets (`cast wallet new` +
     `anvil_setBalance`): anvil's default accounts carry EIP-7702 code on public testnets, so a
     mint to them reverts.
   - **`PrizeDraw`:** an Arbitrum Sepolia fork against the real coordinator
     `0x5CE8…3D61`, with:
     - a native-funded subscription;
     - an `ArbSys` stand-in at `0x64`
       (`anvil_setCode 0x…64 0x366004146013576004354060005260206000f35b4360005260206000f3`);
     - key hash `0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be`;
     - words delivered by impersonating the coordinator with an explicit `--gas-limit 300000`.
       An estimated limit applies nothing; that was MNT-157.
4. Hand checks.
5. A one-line verdict.

Then stop for my word.

**Pitfalls seen on 9 October:**
- **A test that uses only cycle 1** can't tell a cycle id from an opening index or a prize index.
  Read events and values in a second cycle.
- **Gas-dependent tests** must find the least gas that succeeds, as `_leastGasToSucceed` does,
  never a literal figure.
- **Every value in an event test** should differ from its neighbours.
- **The accept comment's time** comes from the merge commit (`/mnt:review` gives the command).

**Never:**
- fuzz, invariant or fork harnesses in the suite (an INV-n or Fork-n line for the auditor instead);
- `MNT-n` ids or private paths in NFT;
- pushing, or opening the PR into `release/1.1`, without my word;
- touching `release/1.0` or `main` in NFT.

**At the end of the session:**
- Update `docs/HANDOVER.md` "Next session" and the memory pointer.
- Ask me whether `feat/contracts` goes to `release/1.1`. It is ready whenever every merged Task is
  Done and the gates are green.
