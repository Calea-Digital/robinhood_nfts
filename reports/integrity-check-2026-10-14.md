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
