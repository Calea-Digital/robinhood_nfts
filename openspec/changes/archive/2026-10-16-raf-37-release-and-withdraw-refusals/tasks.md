# Tasks

## 1. Spec

- [x] 1.1 Validate and lint. Verify: `openspec validate raf-37-release-and-withdraw-refusals` passes, and both MODIFIED blocks keep their Kind line and Scenario.
- [x] 1.2 Archive; re-render the generated prose; check the client document; commit the named paths; `/mnt:board`. Verify: MNT-168 and MNT-58 refreshed, nothing created, the validator OK.

## 2. Code

- [ ] 2.1 On `mnt/RAF-37`, MNT-168's work: `release` with `UnknownCycle`, `ClaimWindowOpen` and `AlreadyReleased`; `withdraw` with `InvalidPrize`, `KindMismatch`, `Reserved` and `ZeroAddress`; `released`; the interface pin. Verify: a test per refusal, the deadline second and the one after it, and a planted breakage per refusal caught.
