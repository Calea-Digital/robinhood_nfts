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
