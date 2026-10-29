# Differential review: BearDrop, DST-3 (reads)

- **Target:** `git diff mnt/DST-4 -- packages/contracts/src/BearDrop.sol` on `mnt/DST-3` in mintdotio/NFT.
- **Spec:** DST-3.
- **Date:** 29 October 2026.
- **Reviewer:** Claude Code.

## Change

The contract change is one line: `MAX_BEARS` goes from `public` to `private`. DST-3 names no such
read, and its statement allows no public function beyond those DST-1 to DST-5 name. The value
equals `MintABear.MAX_BEARS`, which the collection already exposes. No value path, check or state
transition changes. The rest of the Task is tests:
- the DST-3 Scenario;
- every read asserted by value;
- the interface pinned from the artifact.

The pin fails on any added or removed function, on a public `MAX_BEARS`, and on a `receive`. Each
of these was planted and caught.

## Findings

None. Risk is LOW: a visibility reduction on a constant that nothing calls.

## Coverage

There are 28 `BearDrop` tests, with 100% line and branch coverage of the contract. INV-44, that no
read iterates, is documented for the auditor.
