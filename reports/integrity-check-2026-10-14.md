# Integrity checks — answers from MINT's meeting of 12 October (session of 14 October 2026)

One entry per answer, after its spec and board update. Each checks the register, the generated
prose, the client document's §10, the board (validator checks 1–10), the scenario and tree checks,
and the code in `../NFT` against the answer.

## Q1 — the test $MNTD on 46630 (CQ-2)

- **Answer:** `0x15CFC2be2Dc468E3f173c560C493A71C3fE4211C` on 46630.
- **Checked on chain (14 Oct):** source verified on the testnet explorer (`MNTD is ERC20, ERC20Burnable,
  ERC20Permit`, solc 0.8.28, `cancun`). Its runtime code is the reference token's, 4,010 bytes; the
  only three differing spans are the EIP-712 immutables (address, chain id, domain separator).
  18 decimals, supply 1e9, no owner, no proxy. MINT's admin `0x1530…6141` holds none.
- **Spec:** CQ-2 stays follow-up (the mainnet address at TGE). `Blocks` drops OPS-4 and gains OPS-5,
  the mainnet deployment and handover. Without OPS-5 every Task CQ-2 blocked was Done (validator check 3).
  §0, §8 and §10 O6 updated. Commits `18f72a3`, then the OPS-5 gate.
- **Board:** MNT-73 refreshed; the CQ-2 → OPS-4 (MNT-64) link was removed and CQ-2 → OPS-5 (MNT-65) added.
  Validator: no problems (89 requirements, 24 decisions). Manifests `MNT-20261014T101724Z-8760f75f`, `MNT-20261014T101755Z-81a794f9`.
- **OPS-4 (MNT-64)** is still gated, by CQ-20 only (the excluded ids, for the mystery-box cycles of
  the rehearsal). The burn part of the rehearsal can run now.
- **Checks:** lint OK; prose current; §10 matches the register; quotes 40/0; trees 26/0.
- **Code (`../NFT` at `7bf67e8`, clean):** unchanged by this answer. No 46630 config exists yet
  (`script/config/example.json` only); `46630.json` is made when OPS-4 is prepared. No doc there
  describes the testnet token as pending.
- **Open:** the rehearsal wallet needs test $MNTD from MINT. The supply sits in MINT's wallets
  (deployer `0xA10D…04B5` holds ~212.8M).

## Q2 — the admin wallet (CQ-12)

- **Answer:** `0x1530…6141` owns and administers every contract. MINT may move to a multisig later
  and asked that ownership move in two steps.
- **Code (`../NFT` at `7bf67e8`) confirms the two steps on every deployed contract:** `MintABear`, SeaDrop
  `TwoStepOwnable` (`transferOwnership` → `acceptOwnership`, `renounceOwnership` → `RenounceDisabled`);
  `Activation`, `MysteryBox`, `PrizeDraw`, Solady handover (`requestOwnershipHandover` →
  `completeOwnershipHandover` within 48 h; `transferOwnership` → `TwoStepHandoverOnly`;
  `renounceOwnership` → `RenounceDisabled`). Pinned by `test_ownership_movesOnlyByTheTwoStepHandover`
  in `MysteryBox.t.sol` and `PrizeDraw.t.sol`, and the ACT-12 and COL-10 suites.
- **Address mismatch MINT saw (question 11):** the prize wallet's full address is right everywhere
  (`0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`, as quoted from MINT on 28 September; an EOA with
  13 transactions on Ethereum), but its short form was written `0xf6c0…e3e3`. The correct form is
  `0xf6c0…83e3`. It was wrong in 16 places: RAF-33, OPS-1, CQ-22, the prose views, HANDOVER,
  CLAUDE.md and the questions document's source. All are corrected (change
  `2026-10-14-prize-wallet-short-form`), and `MintABear-Questions-2026-10-12.pages` is rebuilt and
  reads `0xf6c0…83e3`. Every other short form was checked against its full address: `0x1530…6141`,
  `0xf7E7…0e63`, `0x15CF…211C`, `0x1E00…3c71`, `0x721C…cd1B`, `0xa212…9968` are right. Archived
  changes and `.memsearch` keep the old form as history.
- **Drift found and fixed:** RAF-14's note said "ownership transfer on both" for `MysteryBox` and
  `PrizeDraw`, but the code refuses `transferOwnership`. It now states the handover the code has
  (change `2026-10-14-cq-12-admin-confirmed`, with OPS-1).
- **Spec:** CQ-12 resolved. §10 drops O1 and renumbers O2–O7 to O1–O6, with the references in
  DEL-8, DEL-10, OPS-1 and OPS-5 (change `2026-10-14-renumber-open-items`). HANDOVER follows.
- **Board:** MNT-83 (CQ-12) resolved; its gating links to OPS-1, OPS-2 and COL-10 removed. RAF-33,
  RAF-14, OPS-1, OPS-5 and CQ-22 refreshed. Validator: no problems. Manifest
  `MNT-20261014T102631Z-42b4a0ee`.
- **Checks:** lint OK; prose current; §10 matches the register; quotes 40/0; trees 26/0.
- **Findings left open:**
  - **IC-Q2-1.** NFT's `docs/RUNBOOK.md` has owner-rotation steps for `MintABear` and `Activation`
    but none for `MysteryBox` or `PrizeDraw`. A multisig move needs them. **Acted on:** OPS-5's
    runbook list names owner rotation for all four contracts (change `2026-10-14-ops-5-owner-rotation`);
    the runbook edit is OPS-5's work.
  - **IC-Q2-2.** MNT-146 ("Crear multisig de Mint", Rayco's, Open) stands beside CQ-12's answer. A
    multisig is now optional and later. **Left as it is**, on the person's word.
  - **IC-Q2-3.** `MintABear-Specification-v2.6.pages`, the last specification MINT received, still
    prints `0xf6c0…e3e3`. The next client document carries the correction.

## Q3 — the whitelist stage's time (CQ-1), where holders mint (CQ-19), the registries (CQ-18)

- **Answers:** the campaign closes on 27 October at 12:00 UTC and the whitelist stage opens on
  29 October at 12:00 UTC; holders mint on OpenSea's drop page; the undeployed registries are
  removed now. The client keeps its mint reads and drops its mint writes and proofs (the person's
  choice).
- **Spec:** change `2026-10-14-wl-mint-on-opensea` (WL-2, WL-4, WL-5, DEL-6, DEL-8, DEL-10,
  OPS-4). WL-2's Scenario drops the mint proofs from Calea's part; no other Scenario changed.
  CQ-1 records the 1 October window and the stage time and stays in follow-up (the first cycle,
  the royalty split, the handover). CQ-18 and CQ-19 record the removal and the mint's place. §0,
  §2's end-to-end, §8's calendar and §10's settled table and O6 follow.
- **Board:** MNT-72 (CQ-1), MNT-89 (CQ-18), MNT-90 (CQ-19), MNT-69 (DEL-6), MNT-64 (OPS-4), MNT-23
  (WL-4) refreshed. Validator: no problems. Manifest `MNT-20261014T104350Z-59dbf8f7`.
- **Checks:** lint OK; prose current; §10 matches the register; quotes 40/0.
- **Code:** the removal is tranche-2 `tasks.md` line 0.1, a `NONE` Task worked on its own branch
  off `feat/contracts`. Until it merges, `feat/contracts` still holds both registries and the
  client's mint writes, which the spec no longer describes. That gap closes when the Task is accepted.
  CLAUDE.md and HANDOVER are updated with it.

## Q4 — the two checks only MINT can run, and when

- **Answer:** OpenSea does not support Robinhood Chain's testnet (seen by MINT and Calea in the
  meeting). The proposed dates are accepted, provided the work before deployment is finished by
  15 October.
- **Read on 46630 (14 Oct):** SeaDrop, Seaport 1.6, ConduitController and validator V3 deployed;
  SignedZone not. So the whitelist and enforcement can be rehearsed on-chain on 46630 (the root
  set with `updateAllowList`, proofs from `AllowListTree.proof`), and Studio and the sale cannot.
- **Spec:** change `2026-10-14-opensea-checks-on-mainnet` (COL-7, OPS-4; no Scenario changed).
  §0's status, §8's calendar (15, 16, 19, 20–21 and 22 October, basis *agreed*) and HANDOVER's
  unknowns 1 and 3 follow. CLAUDE.md's COL-7 paragraph follows.
- **Board:** MNT-13 (COL-7), MNT-64 (OPS-4) refreshed. Validator: no problems. Manifest
  `MNT-20261014T105137Z-dcf4e690`.
- **Code:** `test/Deploy.tree.md` "Rehearsal obligations" said Studio attaches on 46630. Handed to
  the removal Task, which edits that file anyway.
- **Open:**
  - **IC-Q4-1.** §8 still lists the mystery box's SoW rows (5–9 and 12–14 October), now in the
    past. They are re-dated with questions 7 and 9–12.
  - **IC-Q4-2.** The 15 October deadline covers the removal Task's review and merge, plus the
    `46630.json` and `4663.json` configs. Mainnet `4663.json` needs nothing more from MINT for the
    collection. `Activation` waits for the $MNTD address (20 October).

## Q5 — the whitelist's go-ahead for production

- **Finding:** the question was out of date when sent. The register has been in production since
  1 October (`nft.getminted.io`, API `mintabear-api.mint.io`). Read on 14 October:
  `/public/pool` gives 147 of 1,000 claimed, the window open until 27 October 12:00 UTC, not frozen.
  The questions document was built from staging notes that were already stale.
- **Answer:** the 27 October hand-off is agreed (other channels before 12:00 UTC; MINT's CTO
  freezes and exports at 12:00; list and sha256 to Iñigo and Calea by 14:00). The register's live
  rules go into the specification.
- **Spec:** change `2026-10-14-wl-register-rules` (WL-1, WL-2, WL-5, WL-8; no Scenario changed):
  the baseline rule of 1 October, the wallet lock, one account per wallet, display-only team
  spots, wallet signatures, the hand-off, and the production addresses. §8 has the hand-off rows.
  This closes the spec delta the whitelist memory had left open since 29 September.
- **Checks:** lint OK; prose current; §10 matches; quotes 40/0.
- **Open:**
  - **IC-Q5-1.** `?since=` on MINT's wager API is still asked for. Until then the 1 October
    baseline rule applies (WL-1).
  - **IC-Q5-2.** The register's code has no `NONE` Task on the board (the work of 29 September to
    1 October). It is on `release/1.0` in MINT's repository, outside the `feat/contracts` flow.
    Logging it as a `NONE` Task for the record is the person's call.

## The removal Task (MNT-160) — after Q3

- **Branch** `mnt/NONE-wl-removal` at `22c1120` off `feat/contracts` `7bf67e8`, worktree
  `~/trees/NFT-wl-removal`; 71 files, +318 / −7,673. In Review, not merged.
- **Gates (fork's run):** fmt; 0 warnings; 252 contract tests; coverage 100/100; Slither 43, no High
  or Critical; `verify.sh` dry run and its 6 cases; client check, 104 tests; quotes 40/0; trees 26/0.
- **Drift it found and fixed here:** OPS-2's technical note gave `MysteryBox(owner, bears)` and a
  `PrizeDraw` with a worker argument. Corrected to the built constructors, with `setWorker` after
  (change `2026-10-14-ops-2-box-draw-constructors`).
- **Here:** `tasks.md` 0.1 ticked; CLAUDE.md's architecture table, whitelist paragraph, commands and
  `fs_permissions` note follow the branch; HANDOVER's contracts, tests and Slither rows give the
  branch's numbers. CLAUDE.md describes the branch, which is ahead of `feat/contracts` until the
  merge.
- **Left as history:** `packages/contracts/audit/` (the external report and our response) still
  names the registries.

## Q6 — $MNTD on mainnet (CQ-2)

- **Answer:** MINT deploys $MNTD on mainnet 24 hours before TGE, so on 19 October. Investors'
  allocation wallets may delay it; MINT says the drop could slip if the two fall out of step.
- **Recorded:** CQ-2 (still follow-up: the address itself), §8 (19 October row), §10 O5, HANDOVER.
  The register notes that the collection doesn't depend on $MNTD: a late token moves `Activation`
  and the burn opening, not the mint.
- **Checks:** lint OK; prose current; §10 matches.

## Q7 — the 222 team bears (CQ-20)

- **Answer:** every bear plays the mystery box, the team's 222 included. Team bears can win (the
  person's confirmation). The exclusion code is removed rather than deployed unused (the person's
  choice): an `excludeRange` called by mistake before the first cycle would make
  `ExclusionsIncomplete` permanent.
- **Spec:** change `2026-10-14-raf-every-bear-plays`. RAF-27 is renamed "Every bear plays, and the
  prize pool". Its Scenario keeps its title, since OpenSpec refuses to drop one, and now reads: a
  box deployed with no other call schedules its first cycle with `PLAYABLE` 4,444, and team bear 1
  opens. RAF-8, 14, 16, 17, 18, 19 and 28, DEL-6, OPS-2 and OPS-4 follow, along with the Purpose
  line. CQ-20 records the answer, keeps ApeChain open (needed by 29 October), and now blocks
  RAF-18 instead of RAF-27 and OPS-4, so OPS-4 has no gate left.
- **Process fix:** change `2026-10-14-drop-open-item-numbers`. Requirements cite decisions
  (`→ CQ-n`), not §10's O-numbers, which every answer renumbered. §10 is re-ordered by Needed by
  (the checker requires it): O1 CQ-22, O2 CQ-17, O3 CQ-23, O4 CQ-2, O5 CQ-1, O6 CQ-20.
- **Narrative:** §0's status, §1.3's wallets and "who can do what", §2's contract table and §10's
  settled table no longer exclude team bears.
- **Checks:** lint OK; prose current; §10 matches.
- **Expected failure until line 0.2 lands:** the code's tests quote RAF-27's old Scenario lines and
  RAF-19's two exclusion cases. `check_scenario_quotes.py` reports 37/3 (RAF-16, RAF-27, RAF-28 in `MysteryBox.t.sol`), and `feat/contracts`
  still holds the exclusion code. Line 0.2 is the `NONE` Task that closes both.

## Q8 — ApeChain, and Base (CQ-20)

- **Answer:** ApeChain is a prize chain. MINT wants Base as an option for later cycles, not the first.
- **Read in code:** `PrizeDraw.recordPayout` takes any non-zero `chainId`, and the client passes it
  through. No chain list exists anywhere, so a new prize chain costs no code. The prize wallet is
  an EOA, so it has the same address on every EVM chain.
- **Spec:** change `2026-10-14-raf-33-prize-chains` (RAF-33; no Scenario changed). CQ-20 resolved.
  §2's chain table gains Base, §10's settled table updated, open item O6 removed (five left).
  CLAUDE.md and HANDOVER (open items, register counts) follow.
- **Checks:** lint OK; prose current; §10 matches.
- **Note:** before the first cycle that names Base, Calea confirms the prize wallet holds the
  prizes on Base (CQ-20's record).

## The every-bear Task (MNT-161) — after Q7

- **Branch** `mnt/NONE-every-bear` at `01b5f91`, stacked on MNT-160's `22c1120`; worktree
  `~/trees/NFT-every-bear`; 25 files, +265 / −731. In Review. MNT-160 merges first.
- **Gates (fork's run):** fmt; 0 warnings; 246 contract tests; coverage 100/100 (492/492 lines,
  120/120 branches); Slither 41, no High or Critical; `verify.sh` and its 6 cases; client 104;
  quotes 40/0 (the 3 failures from Q7 are gone); trees 26/0.
- **Planted breakages** (open refusing id 1 or 4,444; `PLAYABLE` 4,443; shots left capped; a team
  bear refused in `planOpen`): each caught, then restored.
- **Here:** `tasks.md` 0.2 ticked; CLAUDE.md's `MysteryBox` row and mystery-box paragraph, and
  HANDOVER's mystery-box lines, follow.
- **Residual risk (as before):** `PrizeDraw` deployed with a `playable` other than 4,444 would end
  its cycles at the wrong count. The runbook's step 1 now reads `PLAYABLE` back on both chains.

## Q9 — the randomness subscription (CQ-17)

- **Answer:** Calea holds and funds it and invoices MINT, a service it keeps after the handover.
- **Read on Arbitrum One (14 Oct):** the VRF v2.5 coordinator `0x3C0C…7a3e` has
  `requestSubscriptionOwnerTransfer`, `acceptSubscriptionOwnerTransfer`, `removeConsumer` and
  `cancelSubscription`. The subscription can go to MINT later with its id unchanged, so
  `PrizeDraw`, which fixes the id, keeps running.
- **Spec:** change `2026-10-14-cq-17-calea-subscription` (RAF-8, OPS-1, OPS-5, DEL-10). OPS-5's
  Scenario now ends: "Calea holds no owner key and no contract role other than the worker's where
  CQ-23 gives it one; it holds the randomness subscription (CQ-17)". CQ-17 resolved. §10 drops the
  item (four left: O1 CQ-22, O2 CQ-23, O3 CQ-2, O4 CQ-1). §1.3's Calea row, §10's settled table and
  HANDOVER's accepted risks follow.
- **Checks:** lint OK; prose current; §10 matches; quotes 37/3 against `feat/contracts` (the expected RAF-16, 27, 28 until MNT-161 merges) and 40/0 against MNT-161's branch.
- **Open:** which Calea wallet holds the subscription. It is named at `PrizeDraw`'s deployment,
  and OPS-1 records it.

## Q10 — who runs the worker (CQ-23)

- **Answer:** MINT runs it on its own infrastructure, from a key MINT creates after TGE. Calea
  builds it and writes the instructions (agreed 14 October).
- **Corrected from the call's notes:** the worker is the mystery box's relay, not a royalty
  service, and its gas is ETH on Arbitrum One, not Ethereum.
- **Spec:** change `2026-10-14-cq-23-mint-runs-worker`. RAF-18 makes the worker service an
  explicit deliverable (`apps/box-worker`, packaged like the whitelist API, no state of its own,
  alarms, a key MINT creates). RAF-14, OPS-1, OPS-5 (Calea keeps no contract role; the Scenario's
  last line follows) and DEL-10 follow. CQ-23 resolved. §10 has three open items left (O1 CQ-22,
  O2 CQ-2, O3 CQ-1). §1.2, §1.3, §8 and §10's settled table follow, as do HANDOVER's open items,
  counts and accepted risk.
- **Pick order:** RAF-14 is free; RAF-18 (now including the service) waits for CQ-22.
- **Checks:** lint OK; prose current; §10 matches.
