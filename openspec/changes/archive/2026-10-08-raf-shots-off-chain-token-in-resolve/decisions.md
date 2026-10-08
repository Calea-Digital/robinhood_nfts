# Decisions Delta

## RESOLVED Decisions

### CQ-9 — Raffle entry model
- **Statement:** Mystery box model
- **State:** resolved
- **Status note:** call, 28 September 2026
- **Rationale:** **cycles**. The owner schedules each cycle's window and prizes; in a cycle each playable bear is one shot, decided instantly by its own Chainlink word, from a fixed pool without replacement; prizes not awarded stay with MINT and may roll into a later cycle; the only cap on a wallet's wins is one shot per bear per cycle.
- **Blocks:** RAF-28, RAF-29, RAF-30, RAF-32

**Recorded as (8 October 2026).** The 8/10 is counted by the client library from each bear's
on-chain record (RAF-28); `MysteryBox` has no per-wallet read, because the collection keeps no
list of a wallet's bears and a scan of all 4,444 would strain an RPC's read limit.
