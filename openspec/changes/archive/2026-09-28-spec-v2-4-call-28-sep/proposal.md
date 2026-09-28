# Proposal

## Why

At the call of 28 September 2026 MINT answered most of the open items O1–O9 of specification
v2.3. The answers change the mystery box's shape:
- cycles the owner schedules, not one game;
- prizes in MINT's own wallet, not in vault contracts;
- the draw on Arbitrum, not Base.

They also remove the Status link from `Activation`, and they take the whitelist registry out of
the audit so it can be delivered on 29 September. Version 2.4 records all of it as final state,
with what is still open.

## What Changes

- **Mystery box:**
  - cycles scheduled by the owner (RAF-32);
  - 222 excluded ids, frozen before the first cycle (RAF-27);
  - one shot per bear per cycle (RAF-28);
  - the fixed-pool win rule per cycle, with unawarded prizes staying in MINT's wallet (RAF-30);
  - `PrizeDraw` on Arbitrum One (RAF-8);
  - prize custody in `0xf6c0…e3e3` on each prize chain, paid by transfer and recorded on
    `PrizeDraw` with `recordPayout` (RAF-33);
  - no `PrizeVault` and no on-chain nomination. RAF-2, 3, 4, 5, 6, 11, 24, 25, 26 and 31 are
    retired.
- **Activation:** ACT-9 (the Status link) is removed; ACT-5, 11, 12, 13 and 14 lose `linkBear`,
  `unlinkBear`, `linkOf` and their events.
- **Whitelist:** WL-2, 3, 4 and 5 name both variants: WL-3 (vouchers) and WL-7 (owner import).
- **Operations:** the addresses MINT supplied (OPS-1); the deploy order with `MysteryBox` and
  `PrizeDraw` and no vaults (OPS-2); Arbiscan verification (OPS-3); rehearsal on 46630, Arbitrum
  Sepolia and Sepolia (OPS-4); the worker as the one role Calea may keep (OPS-5); OPS-7.
- **Deliverables:** the admin-page and worker calls in the client (DEL-6); the whitelist
  registries are outside the audit (DEL-8, DEL-12); the repository recommendation is accepted,
  with early delivery (DEL-9); the commercial items (DEL-10).
- **Collection:** COL-3 and COL-8 lose their references to the link and to rounds.
- **Decisions:**
  - answered or closed: CQ-2, CQ-9, CQ-11, CQ-14, CQ-15, CQ-21;
  - updated: CQ-1, CQ-8, CQ-10, CQ-12, CQ-17, CQ-18, CQ-20;
  - new: CQ-22 (prize delivery) and CQ-23 (worker operator).

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF), `activation` (ACT), `whitelist` (WL), `operations` (OPS), `deliverables`
  (DEL), `collection` (COL).

## Impact

- **Tranche 1 code:** `Activation` loses the link functions and events, and ACT-12's interface
  pin follows. The tests and trees, the client library's link module, the README and the examples
  follow too, as a Task after this change.
- **Tranche 2** is built against RAF-8 and RAF-27 to RAF-33: two contracts, `MysteryBox` and
  `PrizeDraw`.
- **Documents:** `docs/SPECIFICATION.md` narrative (where the work stands, §1, §2, §8, §10),
  `docs/HANDOVER.md`, `docs/RUNBOOK.md`, `CLAUDE.md`, and the client document v2.4 with its
  operational extract.
