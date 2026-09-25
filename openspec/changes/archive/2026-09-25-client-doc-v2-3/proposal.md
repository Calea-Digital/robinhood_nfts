# Proposal

## Why

Building the TypeScript client library and the reference royalty split (DEL-6; MNT-69, MNT-131)
showed two places where the specification tells MINT less than it now knows:

- **ACT-10** says MINT's royalty accounting reads `snapshot` for `1..4444` at each closing block.
  One call over the whole range is not dependable. Each id's owner lookup walks back to the start
  of its mint batch, so the range costs 56.2M gas at two bears per wallet and grows with the square
  of a long untransferred batch. `weightOf` also answers the level-0 weight for an id never minted,
  so a sum over the whole range before sell-out counts bears that do not exist. The reference
  script reads the inputs two ways that agree, and refuses inputs that miss a bear.
- **WL-3** says `account` is "a hash of the getminted.io account id". `account` is an indexed topic
  of `WhitelistClaimed`, so an unsalted hash of an email or handle can be matched to a guessed id by
  anyone, and a non-canonical id splits one person into two accounts past the cap. The library's
  backend reference pins a keyed hash over a canonical id, and the signer's rules.

The reviewer approved both amendments on 2026-09-25, with the client document moving to v2.3.

## What Changes

- ACT-10: the split counts every bear with an owner among `1..4444`. The reference script reads
  the inputs from an archive node at the closing block, either from `Transfer` events plus
  `weightOf`, or from `snapshot` paged by a gas budget, and refuses inputs that miss a minted
  bear. The Scenario is unchanged.
- WL-3: `account` is HMAC-SHA256 under a server-side key over a canonical account id. The
  eligibility signer is an externally owned key; it issues `allocationIndex` as
  `accountClaims(account) + 1` only while the wallet holds fewer than two; a key rotated out is not
  rotated back in. The Scenario is unchanged.
- `spec_version` becomes 2.3.

## Capabilities

### Modified Capabilities

- `activation` (prefix `ACT`): ACT-10, how the split's inputs are read.
- `whitelist` (prefix `WL`): WL-3, the keyed account hash and the signer's rules.

## Impact

- No contract changes. The library (`packages/contracts-client`) already implements both.
- `docs/SPECIFICATION.md` (generated blocks), the client document v2.3, and the MNT ACT-10 and
  WL-3 Task bodies follow on render and `board.sh`.
