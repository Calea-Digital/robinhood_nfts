# Tasks

## 1. Spec and register

- [x] 1.1 Validate (`openspec validate raf-35-review-hardening`) and lint. Verify: RAF-35's MODIFIED block carries its Kind line and its unchanged Scenario.
- [x] 1.2 Archive, then fold `decisions.md` into CQ-11 by hand. Verify: CQ-11's Resolution names the `setSigner` limit, and its record ends with the "Limit (Calea, 16 October 2026 …)" paragraph.
- [x] 1.3 Re-render the generated prose; check the client document; commit the named paths; `/mnt:board`. Verify: MNT-166 and CQ-11 refreshed, nothing created, the validator OK.

## 2. Code on `mnt/RAF-35` (MNT-166, still In Progress)

- [ ] 2.1 `PrizeVault.registerCycle`: `InvalidPrize`, the 90-day `InvalidWindow`, and `KindMismatch` with the per-token kind and count, which replacement lowers. Verify: a test per refusal, including a token re-listed as another kind after its reservations are lifted, and a planted breakage per refusal caught.
- [ ] 2.2 Tree leaves and the obligation for RAF-36 and RAF-37 to lower the per-token count. DESIGN's `PrizeVault` section and HANDOVER's accepted risks (`setSigner`). Verify: `check_scenario_quotes.py` and `check_tree_tests.py` clean.
- [ ] 2.3 `tranche-2/tasks.md` 5.2 and 5.3 name the per-token count. Verify: the lines read so.
