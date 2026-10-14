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
