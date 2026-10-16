# Proposal

## Why

The self-review of `PrizeVault` (MNT-166, 16 October 2026: a differential review plus an
adversarial pass) found three ways an honest owner's mistake could make a reservation disagree
with what the vault can pay:
- one token listed under two kinds, so one NFT backs two prizes;
- a window with no upper bound, so a mistyped `end` keeps prizes reserved for good;
- entries whose amount is zero, or whose unused fields say something other than what is
  reserved.

It also found that the owner's instant `setSigner` reaches reserved prizes. The person chose to
refuse the first three at registration and to accept the fourth as a stated risk. RAF-35 is
built and In Review, so its refusals change before the review closes.

## What Changes

- **RAF-35:** `registerCycle` also refuses:
  - an entry for a token that this chain's reservations already hold under another kind
    (`KindMismatch`), while that token has any reserved entry;
  - a window longer than 90 days, the box's `MAX_CYCLE_LENGTH` (`InvalidWindow`, as for `end`
    before `start`);
  - a non-canonical entry (`InvalidPrize`): an amount of 0, a native entry naming a token or an
    id, an ERC-20 entry naming an id, or an ERC-721 amount other than 1.

  The Scenario is unchanged.
- **CQ-11:** the record and Resolution say that the vault's rule binds `withdraw`. The owner's
  `setSigner` takes effect at once, so the owner with a key of its choosing can claim reserved
  prizes. It is accepted with the single admin EOA (CQ-12), and the instant rotation stays the
  response to a leaked worker key.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mystery-box` (RAF): RAF-35's statement and technical note.

## Impact

- `packages/contracts/src/PrizeVault.sol` on `mnt/RAF-35` (mintdotio/NFT): three refusals and a
  per-token count of reserved entries. There is no new public read; the 90-day bound is a private
  constant.
- Its suite and tree. RAF-36 and RAF-37 must keep the per-token count exact when they lower
  reservations.
- HANDOVER's accepted risks gain the `setSigner` entry. DESIGN gains the three refusals.
