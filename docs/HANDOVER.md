# MintABear — handover

Written 2026-09-15, current as of the session of 20 October, evening. Read this first when resuming; the next session starts from "Next, in this order (written 20 October, evening)" below.

## Where things stand

**The code now lives in MINT's repository, `~/trees/NFT` (`github.com/mintdotio/NFT`)**, as
`packages/contracts` (Foundry) and `packages/contracts-client`. This repository is the private
workspace: the spec, the board tooling, the `/mnt:*` commands and these docs. Start sessions here
with `../NFT` added (CLAUDE.md, "Two repositories", has the rules). The port is in two PRs:
- **PR A, `feat/contracts`**: merged into `release/1.1` as mintdotio/NFT#12 (2026-10-07). It holds
  the contracts and the client, with the client kept outside the pnpm workspace, so `pnpm-lock.yaml`
  and every Railway-watched path are untouched; Railway therefore built nothing for it, and the
  first build that clones the repository with its submodules is the next change under a watched
  path. `feat/contracts` is the code integration branch Task branches come off.
- **PR B, `feat/contracts-client-workspace`**: merged into `release/1.1` as mintdotio/NFT#20
  (17 October). The client is in MINT's pnpm workspace; no app imports it yet. MNT-154 is Done
  (the person's Privy login on staging, 19 October).
- **The vault PR, mintdotio/NFT#25**: merged into `release/1.1` on 19 October at 11:03 UTC by
  lcampanis (`d860438`), with `feat/contracts` `dbd2c66`: the prize vault (RAF-35…37),
  `runPrizeVault` (OPS-2) and `verify.sh` for the vault (OPS-3).
- **The client PR, mintdotio/NFT#26**: merged into `release/1.1` on 19 October at 12:17 UTC, with
  `feat/contracts` `6cc0708`: the client's vault calls and list builder (DEL-6, MNT-174) and
  RAF-27's quote.
- **The worker PR, mintdotio/NFT#28**: merged into `release/1.1` on 20 October at 13:49 UTC.
  It holds `apps/box-worker` in the pnpm workspace (RAF-18, MNT-59) and the mainnet config
  (`be600b9`). MINT creates the worker's Railway service from `apps/box-worker/railway.json`.
- **The hardening PR, mintdotio/NFT#32**: merged into `release/1.1` on 20 October at 15:21 UTC by
  lcampanis (`ff2468f`). It carries the six fixes from the pre-production review ("Pre-production
  review", below). MINT merged its own fix of the `/claim` path just before, as #31 (`b1edbc0`,
  Iñigo); the two changes are the same line, and both tests remain.
- **`feat/contracts`** is `ff2468f`, level with `release/1.1`, in the worktree `~/trees/NFT-fix`,
  and pushed. GitHub deletes the branch when a PR from it merges, so the next push recreates it.

`release/1.0` is production and is never touched. Nothing of the code remains in this
repository, and its CI runs only the spec checks.

**The specification lives in `openspec/`** (v2.6: the MINT–Calea calls of 21 and
28 September 2026, MINT's replies of 28 and 29 September, the tranche-1 review of 23–24 September,
and the readability pass of 29 September):
- `openspec/specs/<family>/spec.md` carries every requirement with its Kind and its Scenario.
- `openspec/decisions.md` is the `CQ-n` register that belongs to MINT.
- `docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md` are the prose views MINT reads. The
  narrative is edited in place; the requirement and register blocks are generated between markers
  by `docs/tools/spec_tools/`, and CI fails when they are stale.

MINT has one combined document in `docs/client/`, generated from those two files by
`docs/tools/build_client_doc.py`. Never edit the `.pages` by hand. The output name carries the
version line in full, suffix included, so each draft is its own file.
- **The current one** is `MintABear-Specification-v2.6.pages` (built 29 September 2026, 25 pages,
  down from v2.5's 48). It is written for MINT's decision-makers: §10 first, with what is settled
  and the open items O1–O7 soonest first, then where the work stands and the changes since v2.5.
  Each requirement is a plain statement; its `*Technical note.*` stays in `openspec/` and on the
  board. Settled questions get no callout, an open one gets one yellow line pointing to §10, and
  the retired requirements are an appendix. `MintABear-Whitelist-Options.pages` is the brief on the two registry
  options MINT answered with the off-chain register; its source is
  `docs/tools/build_whitelist_options.py`.
- **`MintABear-Operational-v2.6.pages`** is its extract for a call: everything before §1 Scope,
  built with `build_client_doc.py --operational`.
- **`v1.0` to `v2.5`** stay beside them as the records MINT answered, decided against and last
  received.

**The board (YouTrack MNT) follows `openspec/`** through `docs/tools/board.sh`. The work loop that
picks requirements off it is in `CLAUDE.md` ("Specification and board"), and its pick order is
`openspec/changes/tranche-2/tasks.md` (tranche 1's has only OPS-4 left).

To check a client-document build without opening Pages, export it to PDF through `osascript` and
render or count text per page with a short Swift PDFKit script. A table that does not fit the rest
of a page moves whole to the next one, so a heading left alone on a page means the table after it
is too tall; a one-cell callout taller than the space left is clipped at the page edge instead —
v2.1's CQ-18 and CQ-9 callouts are cut off that way — so read each callout's last line too.

Both calls are folded in.

**The call of 28 September** answered most of v2.3's O1–O9:
- **Mystery box:** cycles the owner schedules; 222 excluded ids (which ones, to follow); the draw
  on Arbitrum One; prizes in MINT's own wallet (superseded on 15 October: prize vaults, CQ-22).
- **Status links** are off-chain, so ACT-9 is retired.
- **Addresses:** the admin `0x1530…6141` and the royalty receiver `0xf7E7…0e63`.
- **$MNTD's interface** is known from the reference token.
- **The repository recommendation** is accepted.
- **The whitelist** is off-chain, in MINT's backend: no contract (MINT's reply, same day).

MINT first asked for a whitelist its admin imports from a CSV. Calea built that as a variant,
WL-7 `WhitelistImport`, beside the voucher registry WL-3 `WhitelistClaim`, and sent a brief on
both (`docs/client/MintABear-Whitelist-Options.pages`). MINT answered with an off-chain register,
which Calea accepted with five conditions (WL-8, CQ-18 resolved): a free signature for pasted
wallets, one merged row per wallet, a counter that cannot over-claim, a freeze 48 hours before the
whitelist stage, and the whitelist stage first. Both contracts stay in the repository, unused.
Spec v2.5 records it. In v2.6, §10 lists seven open items, O1–O7, soonest first, each with what it holds up and Calea's fallback; `build_client_doc.py` refuses to build when they disagree with the register.

**29 September** (spec v2.6):
- **CQ-14 resolved:** the repository is `https://github.com/mintdotio/NFT`, and Calea has access.
- **CQ-13 withdrawn, DEL-7 retired:** no existing MINT contract is reviewed. Tranche 1's internal
  audit runs on 30 September and 1 October.
- **CQ-18, other channels:** getminted.io is a general whitelist checker. Spots from
  collaborations and giveaways come on top of the 1,000 wagering spots, which keep two per wallet
  and two per account.
- **CQ-24 resolved:** the 1,000 wagering spots are guaranteed, and the other channels are capped
  at 3,222. The CSV totals at most 4,222, and with the team's 222 minted first every row has a
  bear. `compare` is to refuse a CSV over 4,222 (`tasks.md` 2.6).
Two decisions are new: CQ-22 (who sends a payout, push or request) and CQ-23 (who operates the
worker).

**The mystery box runs in cycles** (§6):
- `MysteryBox` on 4663 records each cycle's window, prize count and prize-list hash. Every bear
  plays, the team's 222 included (CQ-20, 12 October). It checks ownership and spends a bear for the cycle.
- `PrizeDraw` on Arbitrum One carries the same cycle terms, takes one VRF word per open in
  `openIndex` order, applies a fixed pool drawn without replacement per cycle, and records each
  payout (`recordPayout` → `PrizePaid`; RAF-33).
- Prizes sit in a `PrizeVault` on each prize chain (Robinhood Chain, Ethereum, ApeChain; Base when
  a cycle first uses it), funded from MINT's prize wallet `0xf6c0…83e3` during cycle setup. A
  winner claims with the worker's signed ticket until one hour after the cycle's end; unclaimed
  prizes carry over (CQ-22, 15 October; RAF-35 to RAF-37, not built yet).

RAF-32 (cycles), RAF-27 to RAF-30, RAF-8, RAF-33 (custody and the payout record) and RAF-34
(pause) carry it. RAF-2 to 6, 11, 15 and 24 to 26 and 31 are retired.

**Tranche 1's code** is on `main` up to `8fc37ac` (merged, never pushed). `tranche-1` carries
WL-7 and specs v2.4, v2.5 and v2.6 on top. **The paired review of every tranche-1 Task is complete**
(`reports/tranche-1-review-log.md`):
- COL-1…13, WL-1, 3, 4, 5, ACT-1…14, OPS-2, 3, 6 and the non-spec MNT-92…94, 96…98 are Done;
- with them, the Defects the review raised (MNT-99…112, 115…118, 120…130);
- and the architecture change MNT-113 (`Activation` burns $MNTD itself, spec v2.2).

An integrity check of spec, prose, client document, code and board ran first (the log's
"Integrity check"), and three tranche-end `solidity-auditor` passes after (the log's
"Tranche-end pass"); `reports/tranche-1-review.md` summarises it all.

**WL-7** (MNT-134, merge `451554c`, Canceled: retired in v2.5) was built on 28 September by the developer, with
tests and self-review (`reports/wl-7-diff-review.md`). It is not deployed: the whitelist went off-chain the same day (WL-8). With it:
242 contract tests and 133 client tests; 200 rows cost 14.0M gas to add.

OPS-4's testnet rehearsal ran on 15 October (MNT-64, Done; Sourcify on 46630 for MNT-95); its mainnet
half is Subtask MNT-164.

Each Task carries a claim comment, a summary with its commits and gates, a `Reviewed — Done`
comment and logged time. The human merges `tranche-1` into `main`.

| | |
|---|---|
| Contracts | `MintABear`, `Activation`; tranche 2 is `MysteryBox` (4663), `PrizeDraw` (Arbitrum One) and `PrizeVault` (every prize chain, one CREATE2 address). No whitelist contract: `WhitelistClaim` and `WhitelistImport` are removed (MNT-160) |
| Scripts | `Deploy.s.sol` (OPS-2: `runCollection`, `runActivation`, `runMysteryBox`, `runPrizeDraw`, `runPrizeVault`), `verify.sh` (OPS-3), `Enforcement.s.sol` (OPS-6), `WhitelistExport.s.sol` (WL-4), `RehearsalAllowList.s.sol` (OPS-4, 46630 only); `packages/contracts/docs/RUNBOOK.md` in NFT: ownership handover, whitelist into Studio, transfer enforcement, royalties, Activation, the mystery box, the testnet rehearsal |
| Tests | 313 contract tests, 15 `verify.test.sh` cases and 134 client tests on `feat/contracts` `dbd2c66` (2026-10-19), all passing; 100% line, branch and function coverage (gate ≥90 / ≥80). Work-item Scenarios with no quoting test: the operational OPS-1, OPS-3 (live), OPS-4 (run on the testnets, below) and OPS-5; DEL-3 (the auditor's) and DEL-9 (the repository); DEL-6 (the client's tests carry tree leaves under DEL-6 but none quotes its Scenario); RAF-18 (the worker, on `mnt/RAF-18`) |
| Gates | in NFT, run locally by `/mnt:done` (MINT's CI, since 17 October, never builds `packages/contracts*`): `fmt --check`, `build --sizes` (no warnings), `test`, coverage, Slither, `verify.sh` dry run and verdict test, the client check (`pnpm install --frozen-lockfile` at the workspace root with pnpm 12, then `pnpm run check`); here, in CI: spec lint and generated prose; the scenario-quote check (44/0) and the tree check (26/0) — all green (2026-10-17, `c5f053b`). The two checks default to `~/trees/NFT`; pass `--code-root <worktree>/packages` when the branch is elsewhere. Slither refuses to overwrite a `--json` file: delete it first |
| Slither | 47 results on `feat/contracts` `dbd2c66`, no High or Critical; 4 accepted Mediums: `locked-ether` on `Activation`, `MysteryBox`, `PrizeDraw`, and `reentrancy-no-eth` on `PrizeDraw.resolve`'s request (both below and in the NatSpec); `PrizeVault` adds only `timestamp` Lows (its windows) |

Requirements amended since v2.1, each through an archived OpenSpec change:
- **23 September:** ACT-5 (after a transfer the weight reads the level-0 weight) and OPS-2
  (`WhitelistClaim` takes MINT's admin as owner).
- **24 September, in the tranche-1 review:**
  - COL-10 (ownership is never renounced);
  - WL-3 (the voucher's index is the account's allocation; renounce refused);
  - WL-1 (thresholds make the account eligible);
  - spec v2.2: `Activation` burns $MNTD itself (ACT-1…14, OPS-1, 2, 4, DEL-8).
- **28 September:**
  - WL-7 (the owner-imported registry);
  - spec v2.5, MINT's reply: the whitelist off-chain (WL-8 added; WL-3, WL-6, WL-7 retired;
    WL-1, 2, 4, 5, COL-11, OPS-1, 2, 4, 5, DEL-6, 8, 9, 10 modified);
  - spec v2.4, the call of that day: RAF-32 to RAF-34 added, RAF-2…6, 11, 15, 24…26, 31 retired,
    RAF-8, 14, 16…19, 27…30 modified; ACT-9 and ACT-11 retired, ACT-15 added, ACT-5, 12, 13, 14
    modified; WL-2…5, COL-3, 6, 8, OPS-1…5, 7 and DEL-6, 8, 9, 10, 12 modified.
- **29 September:** spec v2.6, the readability pass and MINT's replies of that day: every active
  requirement restated as a plain statement plus a `*Technical note.*` (Scenarios unchanged),
  COL-7 renamed "Enforced royalties", DEL-7 retired, and the new Purpose line of every family
  (`openspec/changes/archive/2026-09-29-client-readability-v2-6/`).

Submodule pins: `forge-std` `bf647bd` (v1.16.2), `seadrop` `757590f`, `solady` `acd959a`
(v0.1.26). The chain's contract size limit is ~96 KB; every contract clears even Ethereum's
24,576.

**The external security review of 6 October** (`packages/contracts/audit/Mint-Security-Audit-Report.md` in NFT,
its links re-pointed there: no Critical, High or Medium; three Low, three Informational) is
answered in `packages/contracts/audit/Audit-Response.md` beside it. Every finding is fixed on `tranche-1`, one Defect each,
MNT-147 to MNT-152, all Done on the reviewer's word (2026-10-06). The one contract change is L-01 (spec change
`act-two-step-ownership`): `Activation` is constructed owned by MINT's admin and paused, and
ownership moves only by Solady's two-step handover. Its constructor is therefore
`Activation(owner, bears, mntd, thresholdsWhole, weights)`, and this is the bytecode the internal
audit takes.
Agreed at the review, still to act on:
- `spec_version` stays 2.6 until the next client document; the ACT-12, ACT-15 and OPS-2 changes
  ride with it.
- `WhitelistClaim` and `WhitelistImport` are removed (CQ-18, 12 October), with the client's
  mint calls (CQ-19): MNT-160, Done. Every bear plays (CQ-20, 12 October): MNT-161, Done.
- CLAUDE.md is to point to NFT's `packages/contracts/docs/DESIGN.md` rather than restate it, now
  that the contracts have moved (CQ-14).

## Next session — tranche 2 continues

**Where the code is** (2026-10-09, end of day). `feat/contracts` in `../NFT` is at `7bf67e8`
(the mystery-box docs merged onto `bc89abb`), pushed, and in PR #13. Every gate is green there:
- fmt, 0 warnings;
- 328 tests, coverage 100/100;
- Slither 51 with no High or Critical;
- `verify.sh` and its test;
- the client's 180;
- quotes 40/0.

Since PR A (NFT#12) it holds, all Done on the person's accept:
- the whitelist fixes: `compare` decides UTF-8 from the bytes (MNT-155), and the client's input
  edges (MNT-156);
- `MysteryBox` (4663): cycles of at most 90 days (RAF-32), every bear playing (RAF-27; the exclusion
  removed on MNT-161's branch, CQ-20), one shot per bear per cycle (RAF-28), the pause
  (RAF-34);
- `PrizeDraw` (Arbitrum One): worker relays strictly in order, one Chainlink VRF v2.5 word per
  opening and never re-requested, a callback that only stores the word, outcomes applied in order
  (`applyOutcomes` for anyone; `resolve` applies at most 16), the win rule, a constructor
  `firstOpenIndex` so a replacement draw continues the sequence, terms fixed from the cycle's
  start, the pause (RAF-8, RAF-29, RAF-30, RAF-34);
- every event of both contracts checked against its documented signature through two cycles
  (RAF-16);
- `applyOutcomes` refuses with `InsufficientGas` when it stops for gas with the next word stored,
  so a wallet's gas estimate applies every ready outcome (Defect MNT-157, found in RAF-16's fork
  run; INV-29);
- the payout record on `PrizeDraw`: `recordPayout` by the worker, once per applied win, refused
  with `NotAWin`, `AlreadyPaid` or `InvalidPayout`, readable with `payoutOf`, not suspended by the
  pause (RAF-33, ungated from CQ-22 on 9 October; INV-30);
- every public read of both contracts asserted by value in an open cycle (RAF-17, MNT-58):
  - RAF-17's note names every read, and says no other public read exists (change
    `raf-17-name-every-read`, which also names `InsufficientGas` in RAF-29).
  - Both interfaces are pinned from their artifacts through `BaseTest._assertInterface`, which
    ACT-12's pin now uses too, and which refuses a duplicated entry.
  - The fixed cost of each read is INV-31, for the auditor.
- a deterministic test for every RAF-19 acceptance case (MNT-60):
  - `MysteryBox.tree.md`, "Acceptance cases (RAF-19)", maps all 12 cases to their tests.
  - The gaps filled: a second word for a stored opening; a full cycle of losing words, forced
    wins at the tail, then `CycleExhausted`; and, on both contracts together, a started cycle's
    terms fixed and a sold bear's outcome kept with the seller.
  - The box-and-draw suites share `MysteryBoxAndDrawBase`.
- the client's mystery-box calls (Defect MNT-158, DEL-6, `tasks.md` line 3.5), widened at the person's word to the admin page and the worker:
  - the page: `open`, shots left (one Multicall3 call over the wallet's bear ids; ERC721A cannot list them), outcomes, odds, payouts;
  - MINT's admin page: a cycle on both chains (the draw's half simulated first), pauses, `setWorker`;
  - the worker: `nextOpening` and `relay` (checked against the box's `BoxOpened`, looked up backwards in pages of `logBlockRange`; nothing scanned before `openCount` reaches it), `applyOutcomes`, payout records.
  - The draw is a second client, `draw: { publicClient, walletClient?, address }`, on Arbitrum One. Every draw write asks the wallet's chain first.
  - `ContractPaused` and `InvalidWindow` are decoded by function; `explainError(error, functionName?)` for calls sent outside the library.
  - Self-review report: `reports/del-6-158-diff-review.md`.

The PR from `feat/contracts` into `release/1.1` is mintdotio/NFT#13 (below); it touches no
Railway-watched path.

**14 October: PR #13 is merged.** mintdotio/NFT#13 merged into `release/1.1` as `f1f9ce6` (the
person, 13:25 UTC), approved by lcampanis on `7bf67e8`. The merge deleted the remote
`feat/contracts`; it was restored by fast-forwarding to `f1f9ce6`, which also brings MINT's #14
(`apps/claim`) and #15 (RainbowKit, and a `pnpm-lock.yaml` change). `feat/contracts` and
`release/1.1` are the same commit, and `packages/` is unchanged since `7bf67e8`. MNT-160 and MNT-161
(based on `7bf67e8`) merge into it after review and reach staging in a follow-up PR. The two
post-merge checks, a real Chainlink answer after a worker relay and the admin page's
`scheduleCycle` from one Privy wallet, run in the rehearsal (22–28 October).

**9 October, evening: the PR is open and the questions are ready for MINT.**
- **PR into `release/1.1`:** https://github.com/mintdotio/NFT/pull/13, from `feat/contracts` at
  `7bf67e8` (pushed; 0 commits behind `release/1.1`). Merging is the person's.
  - Every gate is green on that head: fmt; 0 warnings; 328 tests; coverage 100/100; Slither 51 with
    no High or Critical; `verify.sh` and its test; the client's 180; quotes 40/0; tree check 26/0.
  - No Railway-watched path, so merging does not redeploy staging.
  - After merging: a real Chainlink callback after a worker relay (46630 and Arbitrum Sepolia),
    and the admin page's `scheduleCycle` with one Privy wallet.
  - Then `git merge origin/release/1.1` on `feat/contracts`.
- **The questions document:** `docs/client/MintABear-Questions-2026-10-12.pages`, 9 pages, built
  by `docs/tools/build_mint_questions.py`.
  - 15 questions, each with Calea's recommendation and the default if MINT doesn't answer on
    Monday, then a checklist.
  - The person sends it. After the meeting:
    - fold the answers into `decisions.md`;
    - run `/mnt:board`;
    - act on the defaults for anything left unanswered.
- **Integrity check:** `reports/integrity-check-2026-10-09-b.md`.
  - Done: IC-2 (NFT's README, DESIGN and RUNBOOK describe the mystery box; MNT-159, merged
    `7bf67e8`), IC-3 (CLAUDE.md) and IC-7 (`docs/tools/check_tree_tests.py`, in `/mnt:done`).
  - Still standing: IC-1 (decisions overdue), IC-4 (MINT's multisig task MNT-146 against CQ-12),
    IC-5 (MNT-154 and PR B), IC-6 (WL-1/WL-5 Tasks), IC-9, IC-10.
- **The whitelist register is live** on `nft.getminted.io` (API `mintabear-api.mint.io`) since
  1 October; 147 of 1,000 wagering spots claimed on 14 October. Its rules are WL-1 and WL-8, and
  the 27 October hand-off is WL-5: other channels loaded before 12:00 UTC, freeze and export by
  MINT's CTO at 12:00, list and sha256 to Iñigo and Calea by 14:00. CQ-1 records the window.
  Open with MINT: `?since=` on the wager API.
- **Not yet in the ai-stack templates:** `check_tree_tests.py`'s line in `/mnt:done`.

**Session of 15 October (run 14 October): done.** Report: `reports/integrity-check-2026-10-15.md`.
- MNT-160 and MNT-161 reviewed and accepted; `feat/contracts` is `10279d5` (local, not pushed).
- In Review, each with its gates green:
  - `mnt/OPS-4-prep` `8e8203b`: MNT-162 (simulations on Cancun) and `tasks.md` 0.5 (`46630.json`, `4663.json`, `RehearsalAllowList`);
  - `mnt/OPS-2-163` `55fc4bc`: MNT-163 and 0.4, the box's and the draw's deploy entry points, the draw always 4,444. Stacked on `mnt/OPS-4-prep`;
  - `mnt/RAF-14` `73273fa`: MNT-55 and 4.1.
- In Progress:
  - `mnt/RAF-18` `ce7606a`: MNT-59, the worker up to prize distribution, gated by CQ-22;
  - `feat/contracts-client-workspace` `7087acc`: PR B, MNT-154. Its lockfile is +345 / −0 with no version moving, the images build and the apps' tests pass.

**Session of 15 October (the follow-up): done.** Prompt for the next session:
`docs/prompts/2026-10-16-integrity-then-next.md`.
- **Reviewed, accepted and merged into `feat/contracts`, all Done:** MNT-162 `98aa18f`, MNT-163
  `56edbd4`, MNT-55 (RAF-14) `08f33ef`, MNT-64 (OPS-4) `3649aad`, MNT-165 (RUNBOOK: the burn
  command, the record check within Robinhood Chain's 10,000,000-block log range) `5300d35`, MNT-169
  (DEL-6: `units.balanceOf`) `5afada1`.
- **PR mintdotio/NFT#17** is open from `feat/contracts` (`5afada1`, pushed, 20 commits, 0 behind
  `release/1.1` `f1f9ce6`) into `release/1.1`. It carries MNT-160, 161, 162, 163, 55, 64, 165 and
  169, touches only `packages/contracts` and `packages/contracts-client` (no Railway-watched path),
  and its description lists them by Spec Ref with the gates on `5afada1`. Merging is the person's
  or lcampanis's. Afterwards `git merge origin/release/1.1` on `feat/contracts`, never a rebase:
  the branch is pushed. MINT's own PR #16 (`feat/swap`) is also open against `release/1.1` and
  touches none of our files.
- **The testnet rehearsal (OPS-4) ran end to end** on 46630 and Arbitrum Sepolia:
  `reports/ops-4-rehearsal-2026-10-15.md`.
  - The collection, the whitelist on SeaDrop, a burn through `Activation` and its reset on
    transfer.
  - Two mystery-box cycles with real Chainlink words: three losses and three wins, each paid on
    46630 and recorded. Every outcome was recomputed from its word.
  - The six `BoxOpened` match the six `OutcomeRecorded`, and all four contracts are Sourcify
    `exact_match`.
  - The Sepolia leg was skipped on the person's word: the payout was on 46630, which OPS-4's note
    allows.
  - The mainnet half is Subtask MNT-164 (Studio takeover, `compare` against Studio's root, one
    team-bear sale, `verify.sh 4663`), on 19 October before the drop page.
- **The testnet contracts stay live,** listed under "Verified on-chain facts". They are owned by the
  rehearsal wallet `0x7672…04Aa`, which holds bears 1–3 and 998,334 test $MNTD. `Activation` is
  paused. The draw's worker is a deleted throwaway key, so set it again (`setWorker`) before RAF-18's
  testnet run. The keystore was removed; re-import it with `cast wallet import rehearsal --interactive`,
  and keep a mode-600 password file passed by path.
- **CQ-22 resolved, option B: winners claim from a prize vault** (MINT, 15 October). The change is
  archived as `2026-10-15-raf-prize-vault-claims`, with the grilling record in its proposal.
  - RAF-35, 36 and 37 were added (board MNT-166, 167, 168). RAF-32, 33, 14, 16, 17, 34 and 18,
    OPS-2, 3 and 7 and DEL-6 and 8 were modified.
  - `/mnt:board` ran: 3 created, 12 refreshed, the validator OK. Manifest
    `MNT-20261015T133143Z-2f44947b.json` in the bridge's `manifests/`.
  - MNT-59 (RAF-18) is In Progress with a stale plan: its payout step now signs tickets, serves them,
    watches `PrizeClaimed` and records claims.
- **MINT's prompts for building UI on the client:** `docs/client/MINT-prompt-1-contracts-client-general.md`,
  `-2-mystery-box-admin.md` and `-3-level-up-page.md`. They are self-contained for MINT's AI
  assistant and follow MINT's `AGENTS.md`. They state that PR #17 and PR B must land before an app
  can import the client. Not yet sent to MINT; that is the person's call.
- **Defect MNT-170** (DEL-6): the client accepts a malformed address. `planTransfer` returns `ok`
  for `to: '0x123'`, and the reads answer `UNKNOWN_ERROR`. It is `tasks.md` 3.7, first in the pick
  order.
- Name and symbol confirmed: `MintABear` / `BEAR`. VRF settings confirmed: ETH payment, 300,000
  callback gas, 3 confirmations.

**Session prompted for 16 October (run 15 October): done.** Report: `reports/integrity-check-2026-10-16.md`.
- **The integrity check** found IC-1 to IC-18, sorted by what blocks the next Task. The board, `tasks.md` and git agree. The drift is in prose: the vault change of 15 October did not reach RAF-27, OPS-1, OPS-4, three register entries (CQ-8, CQ-11, CQ-20), NFT's README, DESIGN, RUNBOOK, the client README, `PrizeDraw`'s NatSpec, this file or the SPECIFICATION narrative.
  - **Fixed on the person's word** (`e3954b8`): IC-1 (`../NFT` means the worktree holding the branch, `--code-root` for the checks), IC-2 (the client gate is `pnpm run check` in the package), IC-3 (`/mnt:done` allows the tree check) and IC-4 (PR B is pushed).
  - **Still open, each waiting on the person's word:** IC-5 to IC-18. The ones that need a decision: IC-6's OPS-3 (Sourcify or Arbiscan on Arbitrum), IC-9 (re-run ai-stack's `install.sh` here: it brings `fold_archive.py`, `schema_drift.sh` and `board.sh`'s synced-tree marker, without which the board-reminder hook fires after every commit touching `openspec/`), IC-10 (`PrizeDraw`'s NatSpec now or with 5.2: it changes the bytecode against the rehearsal deploy), IC-16 (MNT-95's state) and IC-18 (worktrees).
- **Done, reviewed and merged into `feat/contracts`:**
  - **MNT-170** (DEL-6, `tasks.md` 3.7), merge `ba32aac`, pushed and in #17. The client refuses a malformed, bad-checksum or all-caps address with `INVALID_ARGUMENT` before any RPC call (`requireAddress`). `bears`, `activation` and `mntd` are checked at creation; `mysteryBox`, `draw.address` and `seaDrop` when a call uses them, an empty one counting as absent. The exported plans and reads check the addresses people supply. Two review rounds.
  - **MNT-171** (DEL-6, `tasks.md` 3.8, filed in MNT-170's review), merge `6eccd31`, **local, not pushed**. Every write asks the wallet its chain first through the exported `checkWalletChain`, the draw's included: `WRONG_CHAIN` for another network (also when the wallet switches as it signs), `NO_WALLET` for a wallet that cannot be asked. A wallet with no `chain` (Privy's provider) now writes; before, every write failed as `UNKNOWN_ERROR`. The draw's wrong-chain refusal changed from `INVALID_ARGUMENT` to `WRONG_CHAIN`.
- **PR mintdotio/NFT#17** is at `ba32aac`: MNT-170 is in, MNT-171 is not. Still approved by lcampanis (14:14 UTC, on `5afada1`; GitHub kept the approval after the push), mergeable and clean. Its description lists the address checks, and says the rehearsal ran these contracts and the address checks ran on a fork.
- **Waiting on MINT, by the person's decision:** the merge of #17 and of MINT's own #16 (`feat/swap`, which changes `pnpm-lock.yaml` and `pnpm-workspace.yaml`, the same files as PR B).
- **Worktrees:** `~/trees/NFT` is on PR B (`feat/contracts-client-workspace` `7087acc`). `~/trees/NFT-every-bear` holds `feat/contracts` `6eccd31` and the untracked testnet broadcasts (keep them). `~/trees/NFT-wl-removal` holds `mnt/DEL-6-171`, merged; reuse it for the next Task branch. Two anvil forks from an earlier session still run on ports 8547 (46630) and 8548 (Arbitrum Sepolia).

**Session of 16 October: done.**
- **#17 merged** into `release/1.1` as `617217f` (15 October, 17:51 UTC), with `ba32aac`. GitHub deleted the remote `feat/contracts` again.
- **`feat/contracts` is `e67bd96`, local and not pushed:** `git merge origin/release/1.1` onto `6eccd31`. The tree is unchanged, and every gate is green (259; coverage 100/100; Slither 41; `verify.sh` and its test; client 134; quotes 41/0; trees 26/0). It is 4 ahead of `release/1.1`: MNT-171 and the merge.
- **PR B is mintdotio/NFT#20,** from `feat/contracts-client-workspace` `363b269` (pushed) into `release/1.1`, carrying MNT-171 on the person's word. The person judged that MNT-171 does not deserve a PR of its own: no app can import the client before PR B.
  - The lockfile is +345 / −0 against `617217f` with no version moving, and `--frozen-lockfile` passes.
  - Both images build (they need `VITE_PRIVY_APP_ID` and `VITE_WHITELIST_API_URL` as build args), and both Dockerfile installs pass in a clean export.
  - `pnpm -r test` passes: whitelist-api 68 needs its Postgres (`pnpm db:up`, Docker running).
  - Merging redeploys staging, since `pnpm-lock.yaml` is Railway-watched. Then: a Privy login, plus MNT-170's and MNT-171's hand checks. MNT-154 has the comment.
- **#16 is not a prerequisite** (IC-5). It shares only the lockfile with PR B (its `pnpm-workspace.yaml` edit is a different hunk), and whichever merges second regenerates it. #18 (`feat/privy-wallets`) touches only `apps/mintabear/src/host/privy.tsx`.
- **Spec change `vault-prose-alignment`, archived** (`c01ef31`, board manifest `MNT-20261016T140712Z-2ce2986a.json`: 8 refreshed, 0 created, validator OK). It closes IC-6 and IC-7:
  - RAF-27, OPS-1, OPS-4 and OPS-5 describe the vaults;
  - OPS-3 is Sourcify on Arbitrum too (the person's choice; `verify.sh` already does it);
  - CQ-8, CQ-11 and CQ-20 carry "Superseded (MINT, 15 October 2026, CQ-22)";
  - `config.yaml`'s context names `PrizeVault`.
  R-2 (RAF-27's Scenario title "Opening freezes the odds") is not done. `openspec validate` treats a renamed Scenario as a dropped one, so it needs a separate change plus the quote at `MysteryBox.t.sol:224`.
- **IC-8:** `tranche-2/tasks.md` 5.1–5.3 now name RAF-32's and RAF-33's vault clauses and RAF-16's vault events, and the Tests row above lists every requirement with no quoting test. Still open: `check_scenario_quotes.py` printing them.
- **Cleanup:** worktree `~/trees/NFT-wl-removal` removed. Every merged local branch is deleted in NFT (six kept: `main`, `release/1.0`, `release/1.1`, `feat/contracts`, `feat/contracts-client-workspace`, `mnt/RAF-18`) and here (only `main`). Remote branches are untouched. The ones not in use: here `tranche-1`, `chore/foundry-project-setup`, `mnt/none-client-doc-v2.2`, `audit/security-review`; in NFT, `feat/whitelist-backend`.
- **Worktrees:** `~/trees/NFT` is on PR B. `~/trees/NFT-every-bear` holds `feat/contracts` and the untracked testnet broadcasts (keep). Give each new Task its own worktree off `feat/contracts`.

**Session of 16–17 October (after the 16 October block above): done.** Prompt for the next session: `docs/prompts/2026-10-18-integrity-then-next.md`.
- **The prize vault contract is complete and accepted.** It is merged into `feat/contracts`, local and not pushed:
  - **MNT-166, RAF-35** (the vault and the cycle's prize list): merge `bc7642f`. The self-review's hardening went through spec change `raf-35-review-hardening`: `InvalidPrize`, a 90-day `InvalidWindow`, `KindMismatch`, a bounded balance read, and CQ-11's `setSigner` limit, accepted below.
  - **MNT-167, RAF-36** (the claim): merge `48470a3`. Spec change `raf-36-claim-window-from-start`: the window runs from `start`, and RAF-17 names `eip712Domain()`. The review asked for stronger tests, now in.
  - **MNT-168, RAF-37** (carry-over and withdrawal): merge `6517f4e`. Spec change `raf-37-release-and-withdraw-refusals`, plus `released()` in RAF-17. The self-review fixed F1: a withdrawal of more than the vault holds is refused, because some tokens read the maximum as "everything". The review asked for helpers, the released flag in `Cycle` (about 19,600 gas saved per release) and the reserved native and ERC-1155 withdrawals pinned, now in.
  - Each has a report in `reports/raf-3{5,6,7}-diff-review.md`, an adversarial pass, a fork run in review, and planted breakages: every one caught.
- **PR #20 (PR B) merged on 17 October at 08:37 UTC**, with MINT's #18, #19, #21 and #22. MNT-171 and the client-in-workspace are in `release/1.1`. `feat/contracts` was brought level with `git merge origin/release/1.1`:
  - It is now **`c5f053b`**, 0 behind and 10 ahead (the vault). Local, **not pushed**.
  - Gates green there: 308 tests, coverage 100%, Slither 47 with no High or Critical, `verify.sh`, quotes 44/0, trees 26/0.
  - The client passes 134 tests **inside MINT's workspace** after `pnpm install --frozen-lockfile`.
- **MINT's workspace is on pnpm 12** (`packageManager: pnpm@12.14.0`, `allowBuilds`, `minimumReleaseAge`). This machine's Corepack can't verify pnpm 12's key, so use `npx pnpm@12.14.0` until `npm install -g corepack@latest`, which is the person's call. CLAUDE.md and `/mnt:done` now give the workspace install.
- **Integrity check of 16 October:** `reports/integrity-check-2026-10-16-b.md`. IC-19 (CQ-10's resolution), IC-20 (the lockfile) and IC-21 (`mnt/RAF-18`'s base).
  - IC-20 is moot: the PRs have merged.
  - IC-21 stands: `mnt/RAF-18` is now far behind `release/1.1`.
- **The operating rules the reviews produced are on `tasks.md` 5.4 (runbook) and 5.6 (list builder):**
  - compare each vault's `cycle(cycleId)` with the box's and the draw's terms before `start`;
  - never pause the vault after `end`;
  - re-issue tickets after `setSigner`;
  - never list a token that reaches one ledger through two addresses (DN404, ERC-404, double-entry-point);
  - the list builder refuses unknown kinds, wrong standards (ERC-165) and chains with no vault.
- **Hand checks deferred** to 5.4 (the vault on 46630: register, claim, release, withdraw) and to staging after 5.6 (MINT's admin page `manifestHash` against the box and the vault; a claim from the play page). Still to do for PR #20 on staging: a Privy login, MNT-170's pasted address, and MNT-171's `WRONG_CHAIN`. After them the person ticks `tasks.md` 0.3 and closes MNT-154.
- **Worktrees:** `~/trees/NFT` (still on `feat/contracts-client-workspace`, now merged; switch it to `feat/contracts` and move the broadcasts there, then remove `NFT-every-bear`) and `~/trees/NFT-every-bear` (`feat/contracts` `c5f053b`, with the untracked testnet broadcasts and a pnpm workspace install).
- **Commits here** are on `main` and not pushed this session.

**Session of 19 October: done.** Report: `reports/integrity-check-2026-10-18.md`.
- **Integrity check** (IC-22 to IC-26): MINT's restructure of 17 October (#21, #22: one Next.js
  `apps/webapp`, Node 24, pnpm 12, CI that skips our packages) had left our descriptions of NFT
  stale. Board, `tasks.md`, git and the specs agreed; nothing private in NFT.
- **MNT-172, OPS-2 (5.4), Done**, merge `40a66d8`: `runPrizeVault` through the CREATE2 deployer
  from `vault.json` (4663, 1, 33139, 8453; MINT's admin; signer unset until MINT's worker key
  exists) or `vault-testnet.json` (the four testnets; the rehearsal wallet as owner and signer);
  refuses an unlisted chain, a missing deployer, a moved `expectedVault`; reads back address,
  owner, signer, pause, EIP-712 domain. RUNBOOK "Prize vault" with the review rules and the
  lost-admin-key fallback (a new salt, a per-chain address). Self-review
  `reports/ops-2-172-diff-review.md`.
- **MNT-173, OPS-3 (5.5), Done**, merge `dbd2c66`: `verify.sh` reads the vault's `CREATE2`, on every
  prize chain and testnet (all on Sourcify); a contract created inside a call is reported after the
  known ones are checked, never skipped. Fixtures are forge's own `runPrizeVault` records.
- **PR mintdotio/NFT#25** merged (11:03 UTC). **MNT-174, DEL-6 (5.6), Done**, merge `244eec0`: the
  client's vault calls (`src/prizeVault.ts`; facade `vaults`, `prizeVault`, `vaultAdmin`,
  `worker.signTicket`; 23 error codes). Review fixes: USDT-style funding, a duplicate NFT refused,
  `register` held to the box's cycle, signatures read as the vault reads them (64-byte compact yes,
  v 0/1 no). Self-review `reports/del-6-174-diff-review.md`. `feat/contracts` then merged
  `release/1.1` (`6cc0708`, gates green: 313, client 143) and is **PR #26**. IC-10 closed with it.
- **The vault on real 46630** (the person's hand check, from the rehearsal wallet, keystore
  `rehearsal`): `0xAE51fA4E8f5089fE0D3017589fDa851475bF383d`, Sourcify `exact_match` with the
  other three (`verify.sh 46630 --check` exit 0). Cycle 1 (11:08–11:13 UTC, claims to 12:13:02):
  funded 0.001 ETH and 10 test $MNTD; registered (manifest
  `0xc185…70be`); prize 2 claimed with a signed ticket (tx `0x1838…b9af`), a replay refused
  `AlreadyClaimed`. An early `release` was refused with `ClaimWindowOpen`. After the window: `release` (tx `0x7e5a…f9fa`; a second one refused with `AlreadyReleased`) and `withdraw` of the freed 0.001 ETH (tx `0x3ce6…7851`); the vault is empty and reserves nothing. MNT-172's and MNT-173's hand checks are closed.
- **Docs:** CLAUDE.md and `/mnt:review` describe `apps/webapp`, Railway's watch paths and MINT's CI
  (IC-22), the vaults (IC-13) and the vault's lint note (IC-26); the SPECIFICATION narrative
  describes the vault (IC-15); CQ-10's resolution names the claim window (IC-19, change
  `cq-10-vault-resolution`, board refreshed); MINT's three prompts target `apps/webapp` and the
  built vault (IC-24, `9368c9f`; not sent).
- **Spec tools re-installed** from ai-stack `49d235e` (IC-9): `board.sh` records the synced tree,
  so the reminder hook is quiet once the board carries `openspec/`. `fold_archive.py` is installed
  but **must not run here**: it replaces a register entry whole, and this project's decisions
  deltas list changed fields only (it would drop CQ-10's history — dry-run shown). Fold by hand;
  the hook and `/mnt:grill` say so. The schema copy is left older than ai-stack's master for the
  same reason.
- **R-2 stays open:** OpenSpec 1.13 refuses a renamed Scenario in a MODIFIED block (no escape in
  its validator). Options for the person: edit `spec.md` and `MysteryBox.t.sol:224`'s quote
  directly, outside the flow, or keep the title.
- **Housekeeping:** MNT-95 Done (the person). Worktrees: only `~/trees/NFT`, on `feat/contracts`,
  with the testnet broadcasts in `packages/contracts/broadcast/` (keep; `runPrizeVault` for 46630
  is there now). `apps/claim/` in it is MINT's old build output, untracked; leave it.

**Session of 19 October, afternoon and evening: done.**
- **MNT-59, RAF-18 (4.2), Done**, merge `a4f89fc`:
  - The worker branch was brought level: `feat/contracts` merged in, with `pnpm-workspace.yaml`
    resolved to `feat/contracts`' version.
  - The worker joins the pnpm workspace on Node 24 and pnpm 12. The lockfile is +22 / −0; pnpm
    re-resolved `@scure/bip32`'s `@noble/curves` to 1.9.1, and I held it at 1.9.7.
  - New payout step `vaultClaims`. It signs a winner's ticket only when the prize chain's vault
    carries the draw's `manifestHash`, its cycle has started, and it trusts the worker. Tickets are
    served at `GET /tickets/:openIndex` and `?wallet=`.
  - It records each claim with `recordPayout` and the claim's own transaction, and retires wins
    once recorded or expired.
  - Each chain is read once per pass and a failing chain is contained. At start it refuses a chain
    without the vault, or a chain listed twice.
  - New alarms: `not-the-signer`, `prize-chain-unconfigured`, `prize-chain-failing`,
    `terms-mismatch`.
  - The Docker image links the client's `viem` peer to the worker's.
  - Self-review: `reports/raf-18-diff-review.md`. The review's fixes A–I are in `74a5105`.
- **RAF-18's Scenario passed on the testnets** with the person, 18:00–18:30 UTC. Box and vault
  were on 46630; the draw on Arbitrum Sepolia was a test `PrizeDraw` at
  `0x1E0F58140e30FFEf81A050f0079309c124290823` with `PLAYABLE` 4 so that wins occur, on the
  rehearsal subscription.
  - Cycles 3 and 4 ran: four wins were claimed and recorded with their claims' transactions, a
    relay out of turn was refused with `OutOfOrder`, and bear 1 opened in both cycles.
  - Gas measured: about 135,000 per relay and 75,500 per record (now in the worker's README).
  - Left there: the test draw is still a consumer of the rehearsal subscription, and cycles 3 and 4
    each hold one unwon prize (1 test $MNTD) until released.
- **PR #26 merged** (12:17 UTC). **`feat/contracts` `9643adc` is PR #28**, the worker. Gates green
  there: 313 forge tests, coverage 100/100, Slither 47, verify 15/15, client 143, worker 28,
  webapp 89, Docker image built.
- **The person's keystore `rehearsal`** (the rehearsal wallet) signs every testnet step; Claude
  prepares the commands and reads the chains.
- **`tasks.md` for tranche 2 has no unticked line.**

**Mainnet deploy: MintABear and Activation (20 October, done).** Prompt:
`docs/prompts/2026-10-20-mainnet-deploy.md`.
- **Deployer: the rehearsal wallet `0x7672D1F3C832796D378827019a9f9Bf4D80404Aa`** (keystore
  `rehearsal`), not `0x0e15…6ff2`: the person's choice on the day. It holds no role afterwards.
  It had 0.01 ETH on 4663; both deploys cost about 0.00013 ETH, and it is at nonce 5.
- **Config:** `4663.json`'s `mntd` is MINT's $MNTD `0x62Ed…a967` (CQ-2, resolved), with the
  config test pinning it: NFT `mnt/OPS-2-mainnet` at `3cb2c27`, merged into `feat/contracts` as
  `be600b9` on the person's approval and pushed (20 October), so it is in the open PR #28 (head
  `feat/contracts`). 313 tests pass; both checks here pass.
- **Read back on 4663:**
  - `MintABear`: `maxSupply` 4444, validator V3, owner the deployer, pending owner MINT's admin
    (`PotentialOwnerUpdated`), no drop configured, royalties and URIs empty.
  - `Activation`: `BEARS`, `MNTD`, 18 decimals, thresholds 1,666…41,666 × 10^18, weights 100…200,
    owner MINT's admin, paused.
  - `verify.sh 4663 --check`: both `exact_match`.
- **Broadcast files:** NFT's untracked `broadcast/Deploy.s.sol/4663/` holds only the real runs
  (`run-1792496308501.json`, `run-1792496478742.json` and the `-latest` copies). An anvil fork of
  4663 also reports chain id 4663, so a fork rehearsal writes into the real directory. Its files
  are moved to the session scratchpad. Rehearse on a fork with a different `--chain-id`, or move
  the files out after.
- **Forge's broadcast mislabels hashes:** `runCollection-latest.json` pairs some transaction
  hashes with the wrong call (all four landed in one block). The hashes in "Verified on-chain
  facts" are read from the chain.

**Pre-production review of `release/1.1` (20 October, afternoon).**
- **Scope:** every surface a user can reach on staging, MINT's code included:
  - the webapp's `/nft`, `/claim`, `/mntd`, `/swap` and their API routes;
  - `apps/whitelist-api` and the shared packages;
  - our client and `apps/box-worker`;
  - the 4663 deployment, read back.
- **Report:** `reports/2026-10-20-release-1.1-review.md`. The attack scripts and the stack launcher
  are in `reports/2026-10-20-phase2/`.
- **Phase 1, static review** (three parallel reviewers, each finding verified by hand): 2 High,
  8 Medium, 11 Low, 6 Info.
  - **The worst, H-1:** `/claim` fetched `/api/vesting`, while the route is `/api/claim/vesting`, so
    nobody could load an allocation, on staging or app.getminted.io. The bug came in with the
    consolidation `d81a1fe` (16 October).
  - **The whitelist register held up:** row locks, DB constraints, single-use challenges, the
    freeze and the CSV caps.
- **Phase 2, adversarial QA:** run on a local stack, the webapp as a production build on testnet
  46630, through the public routes only.
  - The whitelist path held against 23 attacks: auth forgery, route escapes, body tricks, wallet
    theft and replay, races (8 parallel claims give exactly 2 spots; two accounts racing for one
    wallet give one winner), and per-visitor limits.
  - The claim, transaction-status and Relay routes held against 29 of 30. The 30th was Info: a
    mis-checksummed address is normalised on a public read.
- **Fixes:** six branches, each with a test that fails without it. The person accepted each one;
  they were merged into `feat/contracts` and shipped as #32:

  | Branch | Findings |
  |---|---|
  | `mnt/defect-claim-vesting-path` | H-1 |
  | `mnt/defect-worker-hardening` | H-2 (a malformed request killed the worker), M-5, M-6, M-7, L-4, L-10 |
  | `mnt/defect-claim-minblock` | M-2 |
  | `mnt/defect-proxy-hops` | M-3: production refuses `APP_TRUSTED_PROXY_HOPS=0` |
  | `mnt/defect-swap-stale-quote` | M-1 |
  | `mnt/defect-swap-token-override` | L-11: production refuses a foreign `SWAP_MNTD_ADDRESS` |

- **Gates on `ca8235e`:**

  | Suite | Result |
  |---|---|
  | forge | 313 |
  | client | 143 |
  | webapp | 95, now 96 with #31 |
  | worker | 34 |
  | whitelist API | 69 |
  | core / server-kit / whitelist-client | 12 / 7 / 3 |

  `next build` also passes with no env set.
- **Board:** 21 Defects (Work Kind Defect, `MNT Claude`).
  - MNT-175 to 185 are fixed and In Review; Done is the person's.
  - MNT-186 to 196 are Open. Three wait on MINT: MNT-187 (smart-account openers on prize chains,
    RAF-36, a decision), MNT-188 (what a wager-API 404 means, WL-1) and MNT-186 (staging env).
    The rest are Lows to schedule.
- **MINT's answers today:**
  - Production's whitelist API keeps the live register's database. `release/1.0` and `1.1` share
    migrations 001 to 003, so there is no schema change. Testing app.getminted.io therefore writes
    to the real register.
  - The production claim env is `CLAIM_CHAIN_ID=4663`, Distributor `0xFC53…B601` (checked: its
    `TOKEN()` is $MNTD). `CLAIM_CLAIMS_ENABLED` is MINT's switch for when releases open.
  - Calea told MINT to drop `SWAP_MNTD_ADDRESS`, `CLAIM_TOKEN_ADDRESS` and
    `LOCKED_STAKING_ADDRESS` from production (all redundant or dangerous), and that
    `SWAP_RELAY_API_KEY` and `MNTD_POOL_ID` are missing.
- **Worktrees:**
  - `~/trees/NFT-qa`: detached, the integration checkout of the stack.
  - `~/trees/NFT-worker`: the merged worker branch.
  - `~/trees/NFT-fix`: `feat/contracts`.
  - Remove the first two when Phase 4 is done. The six `mnt/defect-*` branches are merged and can
    be deleted.
- **Lesson:** every suite was green on `release/1.1` while H-1 was live. No test tied a browser
  call to a route. Both #31 and #32 now add one.

**After #32 (20 October, evening).**
- **Both hosts serve #32**, confirmed at 15:34 UTC:
  - app.getminted.io: `/ready` ready, claim on 4663; `/api/claim/vesting` answers mainnet
    allocations, so MINT's "We could not load your allocation" is fixed in production.
  - Staging: `/ready` ready, claim and `/mntd` staking on 46630.
  - Both `/ready` answers mean MINT set `APP_TRUSTED_PROXY_HOPS=1` and cleared
    `SWAP_MNTD_ADDRESS`; either missing would have kept the old build.
- **MetaMask pass, `/nft` on staging** (the person signs, from `0x7672…04Aa`, logged in with that
  wallet through Privy). Every check passed with no console error:
  - the signed-out view;
  - the login (`/me` 200);
  - binding the NFT wallet with a free signature (challenge → signature → bind, shows ✓);
  - the binding surviving a reload;
  - a pasted wallet the person doesn't own (`0xA10D…`), refused in the browser before any request
    ("You connected 0x7672…, not the pasted wallet…");
  - cancel restoring the panel;
  - logout resetting to the signed-out view.

  The nav's network reads "Robinhood Chain" (mainnet) on staging, which is MNT-186.
- **Pricing report for the CEO:** `reports/2026-10-20-MintABear-work-for-MINT.pdf`, with its HTML
  source beside it; regenerate with Chrome headless `--print-to-pdf`. It has three parts:
  - the contracted scope, delivered;
  - DEL-10's items, beyond the SoW but already listed;
  - extras A–G: the whitelist register, whitelist and TGE go-live support, the web-app review,
    rework from MINT's changes, the monorepo move, decision support.

  Board-logged time covers only E and F (about 23 h, a lower bound). A–D and G need the person's
  day estimates.
- The local QA stack is stopped (`docker compose stop`, no volumes removed).

**Next, in this order (written 20 October, evening):**
1. **Fund the QA wallet (MINT, asked):**
   - `0x7672…04Aa` needs testnet MNTD **`0x15CF…211C`**, the token staging's claim and
     LockedStaking `0x33ae…f283` use. It holds only `0x6357…`, which staging doesn't use.
   - It also needs an allocation. Quickest is `transferOwnership(0x7672…)` from `0xA10D…04B5` on
     vesting wallet `0x6810…148C` or `0xAA22…1471`.
   - At 18:20 UTC neither was done: 0.021 ETH, 0 `0x15CF…`, Distributor still 4 rows.
2. **Resume the MetaMask pass once funded:**
   - `/claim`: view, claim, rejection, wrong network, pending across reload.
   - `/mntd`: approve, lock, unlock on 46630.
   - `/swap`: UI only. Change the amount after a quote; the button must drop to "Getting a
     quote…" (MNT-184).
   - `/nft`: claims at $50 and $100. These need wagering on mintstage.io by the `0x7672…` account,
     or MINT's credit.
   - `/nft`: an account switch with a second login.
   - Check the chain before starting (`cast` balance of `0x15CF…` and `/api/claim/vesting` for
     the wallet).
3. **Board:** the person sets MNT-175 to 185 Done once staging confirms. MINT answers MNT-187 and
   MNT-188. Schedule the Lows (MNT-189 to 196).
4. **Waiting on MINT:**
   - MINT's admin `acceptOwnership` on `MintABear` `0x655e…cB28`, then the RUNBOOK's "Ownership
     handover" (reset the allowed-SeaDrop list, read SeaDrop's state). Calea reads back `owner`.
     At 15:00 UTC the owner was still the rehearsal wallet.
   - Studio (Iñigo): provenance, metadata, royalties (5% to `0xf7E7…0e63`, COL-6), drop stages.
     `baseURI` is empty and royalties are unset today.
   - The worker's Railway service: MINT's key, funded on Arbitrum One, then `setWorker` and
     `setSigner`. The mainnet key also goes into `vault.json`'s `signer`.
   - MNT-146's multisig, against CQ-12. With vaults, moving the admin is also a handover on every
     vault.
   - MNT-164, OPS-4's mainnet checks, when MINT announces the mainnet deployment.
5. **Calea:**
   - The `Activation` burn on mainnet (rehearsal item 4), in a window MINT's admin opens and closes
     again, before 29 October.
   - The VRF subscription on Arbitrum One (CQ-17), into `42161.json`.
   - The worker's hand checks:
     - the client's fund, register and claim for a new cycle on the 46630 vault;
     - a ticket signed by the real worker key;
     - a wrong second prize RPC, which now retries under `startup-failed` instead of being refused
       at start;
     - an RPC that stops answering mid-run (`prize-chain-failing`; the other chain carries on).
   - Send MINT's prompts when the person says.
   - Optionally, remove the test draw from the rehearsal subscription.
6. **Dates:**
   - The whitelist campaign closes 27 October 12:00 UTC. The CSV goes to Iñigo and Calea by 14:00,
     then `compare`.
   - The stage opens 29 October 12:00 UTC.
   - `Activation` is deployed and paused; MINT's admin unpauses it at switch-on, 29 October (ACT-15).

### Tranche 2 — the mystery box

- **Done** (on `feat/contracts`): RAF-32, RAF-27, RAF-28, RAF-34 (`MysteryBox`); RAF-8, RAF-29,
  RAF-30, RAF-33 and Defect MNT-157 (`PrizeDraw`); RAF-16, RAF-17, RAF-19 and RAF-14 (both); the
  client's calls for the page, the admin page and the worker (Defect MNT-158, DEL-6); MNT-160
  (the whitelist registries removed), MNT-161 (every bear plays), MNT-162 and MNT-163
  (`Deploy.s.sol`: Cancun simulations, the box's and the draw's entry points); OPS-4's testnet
  rehearsal (MNT-64), two cycles included.
- **Done since:** RAF-35…37 (`PrizeVault`), OPS-2's and OPS-3's vault Defects (MNT-172, MNT-173),
  DEL-6's vault calls (MNT-174) and RAF-18, the worker (MNT-59): all of tranche 2's lines.

The things to get right:
- **`PrizeDraw` must refuse an `openIndex` out of turn**, so the worker cannot choose which open
  meets which state of the pool.
- **The win rule** is `(word mod idsLeft) < prizesLeft` per cycle, with both counters
  decremented on every resolution.
- **Each cycle's terms are fixed from its `start`**, and match across the two chains
  (`CycleScheduled` on both).
- **A bear is spent per cycle**, not for good.

### Integration

DEL-6 is built (MNT-69; usability pass MNT-131): `packages/contracts-client`, the typed TypeScript client
over the tranche-1 ABIs (viem 2, tested against anvil), and the reference royalty split with the
dead-address exclusion (`bin/split.ts`). Its `README.md` is the portal team's reference: a quick
start through the `createMintABearClient` facade, the error codes with the message each shows a
holder, the voucher backend's rules, events and indexing, and the split. `examples/` holds one
runnable file per flow (mint, whitelist, burn, transfer, errors, indexing and split).
It moves unchanged into MINT's repository, `github.com/mintdotio/NFT` (CQ-14). The mystery
box's calls for the play page, MINT's admin page and the worker are in it too (Defect MNT-158). Its whitelist claim and import modules are not delivered. Calea's part of the UI is the call
surface, review of contract-touching pull requests, and clarifications; the rest is MINT's.

## For the portal team

The call surface after tranche 1 is ACT-14 and COL-12 in the spec, plus the mint's reads; after
tranche 2, RAF-17. Four constraints:

0. **The client library is Calea's deliverable and it is TypeScript** (DEL-6, D9). It is typed
   against the ABIs, covers every call the app makes, and carries its own tests and the revert
   reasons a caller has to handle. MINT builds the page on getminted.io against it. It lives in
   `packages/contracts-client`, and its `README.md` is the reference for everything below.
1. **The whitelist is MINT's backend** (WL-8), and holders mint on OpenSea's drop page, which
   serves each wallet's proof (CQ-19). getminted.io sends no mint; it reads the mint's progress
   (`mint.publicStage`, `mint.allowListRoot`, `mint.stats`).
2. **Activation is approve, then one click.** Approve `Activation` on $MNTD, then call
   `burn(tokenId, amount)` with `amount` from `costToReach(tokenId, targetLevel)`. Anything above
   the level-5 remainder is refused, so nothing is destroyed for nothing. Status links are MINT's,
   kept against the Privy account; `levelOf` is what Status reads.
3. **Reads are free; poll them.** `levelOf`, `weightOf`, `costToReach`, `snapshot`; after tranche 2, `odds`, `outcomeOf` and, per bear, `opened`, from which the client library counts a wallet's shots left in one Multicall3 call (a scan of all 4,444 bears on-chain would cost about 23M gas per read).
4. **There is a reset event.** `TransferNonceAdvanced` fires on every non-mint transfer, in the
   same transaction as `Transfer`. Index it as the reset.

## Decisions that should not be relitigated

- **The transfer counter, not a callback.** A callback fails open or bricks transfers; the
  counter can do neither. The client accepted it on 2026-09-15.
- **`solc 0.8.17`.** Forced by SeaDrop's exact pragma. See `CLAUDE.md`.
- **Transfer validator set at deploy; the fallback is one owner call.** MINT wants royalties
  enforced always. Limit Break V3 is on 4663 and OpenSea's SignedZone is an authorizer on its
  default list; OpenSea's off-chain handling on this chain is proven on testnet and with one
  team-bear sale on mainnet before the drop page is published. Never security level 5 or above.
  COL-7, OPS-6.
- **No burn.** MINT's decision; `BurnDisabled` stays. Supply is 4,444 forever.
- **Supply capped in code.** `MAX_BEARS` on the mint path refuses the mint whatever the
  Studio-writable `maxSupply` says, so raising it cannot increase the supply delivered (COL-2).
- **`Activation` burns $MNTD itself.** $MNTD is native to Robinhood Chain (CQ-2), so the token is
  a constructor argument and there is no crediter to point elsewhere: no key can record a level
  without a burn. Calea's decision of 24 September (spec v2.2); a different token address means a
  new `Activation`.
- **A burn is recorded only for the bear's current owner.** `burn` reads `ownerOf` and the
  counter in the same call, so an approved operator cannot spend an owner's $MNTD, and a burn
  never lands on a bear that has changed hands.
- **Cycles set by the owner, one shot per bear per cycle.** MINT's decision of 28 September:
  the owner schedules each cycle's window and prizes, and every bear gets a shot again in the
  next cycle. Exclusions are fixed for good before the first cycle.
- **Instant reveal, one word per open.** MINT's decision of 21 September, confirmed on the
  28th. Robinhood Chain makes
  no randomness, so the only arrangement in which an instant outcome is unpredictable to
  everyone — MINT included — is a fresh Chainlink word per open. A pre-committed seed was
  offered and refused for that reason. The cost is one VRF request per open.
- **Resolution strictly in `openIndex` order.** It is what stops the worker choosing which open
  meets which state of the pool. Without it the worker could reorder relays and shift individual
  odds. Do not relax it for latency.
- **A fixed pool drawn without replacement, per cycle.** `(word mod idsLeft) < prizesLeft`. It
  gives every holder the same odds going in. A cycle that ends with bears unopened awards fewer
  prizes, and the rest roll forward (MINT's option (a), 28 September).
- **Winners claim from a prize vault** (MINT, 15 October, CQ-22, option B). One `PrizeVault` per
  prize chain at one address; the full prize list registered on every vault against
  `manifestHash`, funded before registration; the worker's key signs tickets; only the winner
  claims, paying gas there; the window closes one hour after the cycle's end and unclaimed prizes
  carry over. `PrizeDraw` still records each claim with `recordPayout`.
- **Fuzz and invariant harnesses are the internal auditor's.** The developer writes
  deterministic unit tests; the SoW's "fuzzing report" is the auditor's output.
- **Final-state prose in specs and docs.** No "was / now".

## Accepted risks

- **The collection's owner can add a minter.** `updateAllowedSeaDrop` is SeaDrop's owner-only
  setting, so the owner — Calea until `acceptOwnership`, then MINT's admin — could allow its own
  address and mint bears outside Studio's stages, without fee or allowlist, up to `MAX_BEARS`.
  Canonical SeaDrop as the only allowed minter (COL-1) is a deployment and ownership property,
  not a constant. MINT's admin is one EOA, `0x1530…6141` (CQ-12, confirmed 12 October), not a Safe, so the mitigation
  is that key alone and the runbook's handover, which resets the list to canonical SeaDrop
  straight after acceptance.
- **One EOA owns every contract** (MINT, 12 October 2026, CQ-12). A compromise of `0x1530…6141` controls the
  collection's settings, the pause of `Activation`, and
  the mystery box's cycles. It cannot move a holder's bear, record a level
  without a burn, or change an outcome.
- **The whitelist is MINT's word** (WL-8). The register, its counter and its rules are in MINT's
  backend, and nothing public shows how the list was made. The one check is that Studio's root is
  exactly MINT's final CSV (WL-4). MINT's decision, 28 September.
- **Slither "locked ether"** on `Activation`, `MysteryBox` and `PrizeDraw` : Solady marks ownership
  functions `payable`, and anyone can call `requestOwnershipHandover` and
  `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value; neither
  contract withdraws it. The loss is only ever the sender's own. Accepted, and said in each
  contract's NatSpec.
- **Slither "reentrancy-no-eth"** on `PrizeDraw`: `openingOfRequest` is written after the
  coordinator's `requestRandomWords`, since the request id is its return value. The coordinator is
  Chainlink's, fixed at construction, answers in a later transaction, and a callback made during
  the request would find no opening and be ignored. Accepted, and said in the NatSpec.
- **`Activation` calls $MNTD, which is outside this codebase.** The record is written before
  `burnFrom`, and `burn` is `nonReentrant`: a token that calls back cannot burn again, and any
  revert undoes the record. The reference token is OpenZeppelin 5.5 `ERC20Burnable`, which reverts
  on failure (CQ-2); Fork-3 confirms the deployed one.
- **Reading owners over an untransferred mint batch is expensive.** ERC721A records one owner
  per mint batch, and `ownerOf` walks back to the batch's start, so `snapshot` (which reads the
  owner of every id) costs roughly the square of an untransferred batch's length. Measured on the
  unit fixture: `snapshot(1..4444)` 56.2M gas when wallets mint two each; with all 4,444 in one
  batch, 50 ids at its end cost 55.9M and the full range runs out of gas. `weightOf` does not walk
  (2,451 gas). A holder cannot lengthen a batch; the mint pattern decides it. Accepted; the
  mitigations are the split script's (DEL-6: owners from indexed `Transfer` events at the closing
  block and weights from `weightOf`, or `snapshot` paged by a gas budget) and team and treasury
  mints of at most about 200 bears per transaction (ACT-10).
- **Every holder pre-approves OpenSea's conduit.** SeaDrop's base (`ERC721AConduitPreapproved`)
  answers `isApprovedForAll(anyHolder, 0x1E0049783F008A0085193E00003D00cd54003c71)` with true, and
  no holder can revoke it. The conduit is not deployed on 4663 (verified read-only, 2026-09-24),
  and only OpenSea's conduit creator can deploy it at that address; if it ever exists, its owner
  could move any bear — each move still advancing the counter. Accepted as trust in OpenSea, like
  Studio itself; Fork-2 and the rehearsal check that the address still has no code, or who owns it
  and what the validator's list allows it.
- **A sale arranged outside a marketplace pays no creator earnings.** At level 0 the holder's own
  transfers pass, so a direct or escrow-mediated sale settles without royalties (COL-7). Inherent
  to every level that lets holders move their bears; the level is settled.
- **The worker's key signs claim tickets** (the person's choice, 15 October). Whoever holds it can
  sign tickets naming their own address and claim the current cycle's unclaimed registered prizes,
  on every chain, until the window closes; nothing outside the registered list, nothing twice.
  Such a claim matches no `OutcomeRecorded`, so it is visible. Mitigation: the key is a secret in
  MINT's Railway project; on a suspected leak, pause the vaults, `setSigner` and `setWorker`.
- **The owner's `setSigner` is immediate** (the person's choice, 16 October, MNT-166's
  self-review; CQ-11). The rule that the owner withdraws only what is not reserved binds
  `withdraw`, not the owner. A compromised admin key can name its own key as every vault's
  signer, sign tickets naming itself and claim the reserved prizes of every cycle whose window is
  open. A delay on `setSigner`, or a signer fixed per cycle, would close this, at the cost of the
  instant rotation that answers a leaked worker key. Accepted with the single admin EOA, which
  already controls every contract.
- **A token that reaches one ledger through two addresses** (DN404 or ERC-404 pairs, double-entry-point ERC-20s) gets past the vault's per-address kind lock (MNT-168's review, F2). Never listed as a prize: DESIGN says so, and the runbook (5.4) and the list builder (5.6) carry it.
- **A one-hour claim window.** A winner who is offline, or screened on Robinhood Chain, for an hour
  after the cycle's end loses the prize to carry-over; a winner needs gas on the prize's chain
  (MINT's stated requirement).
- **The worker relays each open and records each payout.** It cannot change an outcome, because
  Chainlink decides it, and it cannot reorder, because `PrizeDraw` refuses an `openIndex` out of
  turn. It can delay one, which is visible as a `BoxOpened` with no `OutcomeRecorded`. It relays an
  open once the 4663 sequencer has confirmed its block. Each relay names the bear (`tokenId`), and
  `PrizeDraw` refuses an id outside the collection, a bear already resolved in the cycle and a
  relay once the cycle has no ids left, so even an invented relay names a real bear once, cannot
  take the pool below zero, and shows as an `OutcomeRecorded` that matches no `BoxOpened`. Nothing
  on Arbitrum can prove an open happened. Accepted; the alternative is cross-chain messaging, and
  4663 has no endpoint. MINT runs it from a key MINT creates (CQ-23, 12 October); Calea builds it and keeps no role.
- **Calea holds the VRF subscription** (CQ-17, 12 October). A Calea wallet on Arbitrum One owns and
  funds it and invoices MINT, after the handover too. The holder can stop the draw's numbers (not
  funding, removing the consumer, cancelling) but cannot choose an outcome; it can hand the
  subscription to MINT with the coordinator's two-step transfer, keeping its id.
- **One VRF request per open is a real cost.** At up to one request per playable bear per cycle,
  the subscription is funded for a cycle's worth and watched with a balance alarm. On Arbitrum a
  request costs the network fee plus Chainlink's premium. Accepted as the price of an instant
  outcome nobody can foresee.
- **A holder whose address cannot receive on a prize chain** (a contract wallet on 4663) is MINT's
  to settle by hand; there is no on-chain nomination. The UI warns before the open.

## Verified on-chain facts

Measured against chain 4663 on 2026-09-10 and 2026-09-15; Chainlink and ApeChain facts on
2026-09-18; Arbitrum, MINT's addresses and the reference $MNTD on 2026-09-28. Do not re-research
these.

| | Address / value |
|---|---|
| Robinhood Chain mainnet | chain id **4663**, RPC `https://rpc.mainnet.chain.robinhood.com` |
| Testnet | chain id **46630**, RPC `https://rpc.testnet.chain.robinhood.com` |
| Canonical SeaDrop | `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` |
| Seaport 1.6 | `0x0000000000000068F116a894984e2DB1123eB395` — deployed |
| OpenSea Conduit | `0x1E0049783F008A0085193E00003D00cd54003c71` — **not deployed**; orders use conduitKey 0 |
| ConduitController | `0x00000000F9490004C11Cef243f5400493c00Ad63` — deployed |
| OpenSea SignedZone | `0x000056F7000000EcE9003ca63978907a00FFD100` — deployed; authorizer on validator list 0 |
| Limit Break validator V3 | `0x721C002B0059009a671D00aD1700c9748146cd1B` — deployed; V1/V2 absent |
| ERC-6551 registry | `0x000000006551c19487814612e58FE06813775758` — byte-identical to Ethereum |
| CREATE2 deployer | `0x4e59b44847b379578588920cA78FbF26c0B4956C` — present |
| LayerZero EndpointV2 | absent at its canonical address |
| Chainlink VRF v2.5 | Ethereum `0xD7f86b4b8Cae7D942340FF628F82735b7a20893a` (code present); Base `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634` (not used); **none on 4663, none on ApeChain** (Chainlink supported-networks page) |
| ApeChain | chain id **33139**, RPC `https://rpc.apechain.com/http`; Curtis testnet 33111 |
| Chainlink VRF v2.5, Arbitrum | Arbitrum One (42161) `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, LINK `0xf97f4df75117a78c1A5a0DBb814Af92458539FB4`; Arbitrum Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; both answer `getActiveSubscriptionIds` with 256-bit ids and `MAX_NUM_WORDS` 500 |
| MINT's admin | `0x153052B43c8fD4ec01f14D1Edd8660778daa6141` — EOA; transactions on 4663 and Ethereum |
| Royalty receiver | `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` — EOA, unused |
| Prize wallet | `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3` — EOA; active on 4663 and Ethereum, nothing on Arbitrum or ApeChain |
| OpenSea contracts on 46630 | SeaDrop, Seaport 1.6, ConduitController and validator V3 deployed; OpenSea's SignedZone not deployed; OpenSea itself does not support the chain (read 2026-10-14) |
| Testnet $MNTD (46630) | `0x63573eD184850Df903C908314Bc6aA3fD6d0128B` — the one MINT funded the rehearsal wallet from (1,000,000), named in `46630.json`; `0x15CFC2be2Dc468E3f173c560C493A71C3fE4211C` is a second deployment of the same runtime (only the EIP-712 immutables differ). Both the reference token's code, 18 decimals (read 2026-10-14 and 15) |
| Rehearsal deployments (2026-10-15) | 46630: `MintABear` `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05`, `Activation` `0x389578ECe1E63DBEe48c9b22504D1Af29E2aef2f`, `MysteryBox` `0xA15a5B96849435B0030F1F6D6E3f886c8C0d55a7`; Arbitrum Sepolia: `PrizeDraw` `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` (same address as the collection: deployer nonce 0 on both). All owned by the rehearsal wallet `0x7672D1F3C832796D378827019a9f9Bf4D80404Aa`; VRF subscription `19717353…670789` (in `421614.json`). Sourcify `exact_match` |
| Mainnet $MNTD (4663) | `0x62Ed300A5916aeD339a65E04754392763982a967` — MINT's (CQ-2): "MNTD", 18 decimals, 1,000,000,000 supply, no owner, no proxy, `burnFrom`; Sourcify `exact_match` (`src/token/MNTD.sol:MNTD`, solc 0.8.28, OZ 5.6.1); deployed by `0x928C591b9d1D79C35b85adb93Dd9634fe761F6c5`, block 92,969,522; runtime equal to the testnet $MNTD's but for the EIP-712 immutables (read 2026-10-20) |
| Mainnet deployments (2026-10-20) | 4663, deployer `0x7672…04Aa`: `MintABear` `0x655e88103f77a48E0b7875511318d3c5f79FcB28`, block 93,422,005, creation tx `0x1eaf5964e848ad78def7194c015c41cd44ad9414a4513a1fae4e12b3a995d44b`; `Activation` `0xAbd272C95F20B59659E3E21Ed75A58652e93159b`, block 93,423,642, tx `0xc62fcd3e6c74f919cf18823186f845af636f1c9affdbeac26f5baaa88eed059a`. Both Sourcify `exact_match` |
| Reference $MNTD | Base Sepolia `0xa21273093af1b3b880b73afd54514bb3d6269968`: OpenZeppelin 5.5 `ERC20 + ERC20Burnable + ERC20Permit`, 18 decimals, 1,000,000,000 minted once, no owner, no proxy; solc 0.8.28, `cancun` |

- **Contract size limit is ~96 KB**, four times Ethereum's.
- **`block.number` returns the L1 Ethereum height.** Key logic on `block.timestamp`. Block time ~100 ms.
- **The block header's `gasLimit` reads 2^50** — Arbitrum-style; the per-transaction gas limit is what binds, so long loops (the draw) are chunked.
- **No usable randomness on 4663.** `block.prevrandao` is constant; no Chainlink. Randomness lives on Arbitrum One.
- **`block.blobbasefee` reverts.** The one unsupported opcode.
- **Sequencer-level compliance screening is active.** No part of the system may break when one holder cannot transact.
- **Mainnet Blockscout's API sits behind a bot challenge.** Verify through Sourcify (4663 and 46630).
- **OpenSea supports the chain** and Studio drops run there. Creator earnings are enforced only for validated collections; otherwise the buyer chooses.

## Unknowns to settle by rehearsal

1. Does OpenSea Studio attach to and manage a contract we deployed ourselves, validator set? (mainnet, 19 October: OpenSea does not support 46630)
2. Does OpenSea emit SignedZone-restricted orders for a Limit-Break-validated collection on 4663? (mainnet: one team bear listed and sold before the drop page is published)
3. The whitelist on mainnet (19 October, before any stage opens): `compare` passes over a test CSV against the root Studio set, which shows Studio builds its tree like `script/lib/AllowListTree.sol`, each wallet's limit included (MNT-164). The 46630 half passed on 15 October: the owner set the root with `RehearsalAllowList.set`, `compare` matched, a two-spot wallet minted two and a one-spot wallet was refused its second.
4. A burn through `Activation` against the real token on mainnet between 20 and 28 October (the 46630 half passed on 15 October: a burn to level 1 against the test $MNTD, and the reset on transfer). The pause has no exemption, so that rehearsal runs in a window the owner opens and closes again; holders' access opens on 29 October (ACT-15, §8).
5. Settled on 15 October: two mystery-box cycles on 46630 and Arbitrum Sepolia, scheduling on both chains, relays in order (one out of turn refused), real Chainlink words, wins and losses, payouts recorded with `recordPayout`, the same bears opened again in the second cycle. Gas: `open` 62,112; `resolve` 155,322 for a cycle's first relay, then about 136k; `recordPayout` 75,492; a VRF request about 0.0000081 ETH at Arbitrum Sepolia's prices.
6. Moot while MINT's admin is an EOA: does Safe's web interface support chain 4663?

## Open questions with the client

Twenty-four are in `docs/OPEN-QUESTIONS.md`, each with the section it affects, when it is
needed, the answer where one exists, and the default otherwise:
- **resolved or closed (24):** all of them; CQ-2 on 20 October with the mainnet $MNTD.

§10 has no open item. Tranche 1's code is written. The whitelist root check over a CSV is
needed by 27 October; the rehearsal is ready to run; tranche 2 waits on the excluded
ids.

## Related documents

- `openspec/specs/`, `openspec/decisions.md`, `openspec/changes/tranche-2/` — the specification and the tranche's pick order.
- `docs/SPECIFICATION.md`, `docs/OPEN-QUESTIONS.md` (generated views), `docs/client/`, `docs/tools/build_client_doc.py`, `docs/tools/board.sh`.
- `packages/contracts/test/<Suite>.tree.md` in NFT — one branching tree per test suite, leaves citing requirement IDs, with
  the auditor's INV-N and Fork-N obligations numbered once across all trees.
- `packages/contracts/docs/RUNBOOK.md` in NFT — operating steps: the ownership handover (COL-10), the whitelist into Studio (WL-4), transfer enforcement (OPS-6), royalties (COL-6) and `Activation` — the read-back, the control check, the pause around rehearsals and switch-on, and the mint batch size (OPS-2, ACT-15).
- `packages/contracts/test/SeaDropIntegration.t.sol` in NFT and its tree — the boundary with OpenSea Studio.
- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire the original build answered.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — the original decision log, item by item.
- `~/.claude/plans/mutable-sparking-candy.md` — the re-specification session: fact base,
  design tree, the SoW digest.
- `~/.claude/plans/in-previous-session-we-ticklish-thacker.md` — the answer intake: MINT's
  answers mapped to questions, the v2.0 design (whitelist registry, mystery box hub, prize
  vaults), and the assumptions made.
