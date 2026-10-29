# Tasks

One line per requirement id, in pick order. `/mnt:next` takes the first unticked line whose Task is
Open and not hard-gated, and `/mnt:done` ticks it. CQ-25 to CQ-28 are resolved (MINT, 29 October):
round 1 is 500 $MNTD for each of the 4,444 bears, open for 90 days.

## 1. BearDrop (Robinhood Chain)

- [x] 1.1 DST-5 — `BearDrop(owner, bears, mntd)`, immutables, two-step handover only (`TwoStepHandoverOnly`, `RenounceDisabled`), `setPaused`/`PausedSet`; the tree `test/BearDrop.tree.md`
- [x] 1.2 DST-1 — `setAmounts` for the next round only, `openRound` with `NotNextRound`, `EmptyRound`, `InvalidWindow` (`MAX_ROUND_LENGTH` 365 days), `Unfunded`; `owed`; `AmountsSet`, `RoundOpened`
- [x] 1.3 DST-2 — `claim(roundId, ids)` by the owner, non-reentrant, all-or-nothing: `UnknownRound`, `OutsideWindow`, `ContractPaused`, `NotBearOwner`, `NothingToClaim`, `AlreadyClaimed`; `Claimed`
- [x] 1.4 DST-4 — `closeRound` (`RoundRunning`, `AlreadyClosed`, `RoundClosed`) and `withdraw` (`Reserved`, `ZeroAddress`, `Withdrawn`)
- [x] 1.5 DST-3 — every read asserted by value; the interface pinned from the artifact (`BaseTest._assertInterface`)

## 2. Scripts and operations

- [x] 2.1 DST-6 — `script/BearDropList.s.sol`: `load`, `check`, `hash`; CSV refusals; fixtures under `test/fixtures/bear-drop-csv`; `fs_permissions` read access to them
- [x] 2.2 OPS-2 — (Defect MNT-210) `runBearDrop(configPath)` with read-back; the config field `bearDrop` in `script/config/46630.json` and `4663.json`; `verify.sh` covers its broadcast; RUNBOOK "Holders' $MNTD (BearDrop)" (handover, read `owner()`, fund, open; never pause near a window's end) and a DESIGN note

## 3. Client

- [ ] 3.1 DEL-6 — (Defect MNT-211) `packages/contracts-client` `drop`: `lookup(ids)`, a wallet's claimable bears (Multicall3), `claim`, the admin's calls, `listHash`; error codes with `userMessage`; `examples/drop.ts`; README; `gen:abi`; the README tells buyers to read `claimed` before buying

## 4. Live

- [ ] 4.1 The testnet run on 46630 with test $MNTD `0x15CF…`: deploy, load, check, handover, fund, open (90 days), claim, a second claim refused, a transfer and the buyer's claim, close, withdraw; report in `reports/`
- [ ] 4.2 Mainnet on 4663 with round 1's list (4,444 × 500 $MNTD, checksum confirmed by MINT): deploy, load, check, handover to `0x1530…6141`, Sourcify `exact_match`; MINT funds and opens
