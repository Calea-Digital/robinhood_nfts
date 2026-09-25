# Spec Delta

## MODIFIED Requirements

### Requirement: ACT-10 — Snapshot view
**Kind:** work-item
`snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting counts, at each
closing block, every bear that has an owner among ids `1..4444`: a wallet's weight is the sum over
its bears, and the total eligible weight is the sum over all bears whose owner is not the canonical
dead address `0x000000000000000000000000000000000000dEaD` (COL-8). Because transfers reset weight
without any call into `Activation`, there is no on-chain running total; the sum is taken off-chain.
The reference script (DEL-6) reads the inputs from an archive node at the closing block, in either
of two ways that agree:
- owners from the collection's `Transfer` events and weights from `weightOf`, for owned ids only,
  since `weightOf` answers the level-0 weight for an id never minted;
- `snapshot`, paged by a gas budget. Each id's owner lookup walks back to the start of its mint
  batch, so one call over the whole range is not dependable (56.2M gas at two bears per wallet).

The script refuses inputs that miss a minted bear, and its allocations plus the rounding carried to
the next distribution equal the funding. MINT credits the resulting shares to getminted.io accounts
through its wallet (§2).

#### Scenario: The snapshot answers for any ids
- **WHEN** `snapshot([1, 2, 4445])` is read
- **THEN** it returns owner, level and weight for ids 1 and 2 and zeroes for the id that does not exist
