# Tasks

## 1. Spec

- [x] 1.1 Validate and lint. Verify: `openspec validate raf-36-claim-window-from-start` passes, and both MODIFIED blocks keep their Kind line and Scenario.
- [x] 1.2 Archive; re-render the generated prose; check the client document; commit the named paths; `/mnt:board`. Verify: MNT-167 and MNT-58 (RAF-17) refreshed, nothing created, the validator OK.

## 2. Code

- [x] 2.1 On `mnt/RAF-36`, MNT-167's work: `ClaimClosed` before `start`, `WrongChain` outside the list, and `eip712Domain()` in the interface pin. Verify: a test per refusal, and the pin lists `eip712Domain()`.
