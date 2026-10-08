# Tasks

## 1. Spec

- [x] 1.1 Lint; archive; fold CQ-20's `Blocks: RAF-27, OPS-4`; render; commit; board (verify: read-back passes with no CQ-20 problem; MNT-51, MNT-55, MNT-60 refreshed; a CQ-20 → OPS-4 link)

## 2. Code (`mnt/RAF-8`, MNT-51, In Review)

- [ ] 2.1 `REREQUEST_AFTER = 24 hours`; `rerequest(openIndex)` by the worker with `NotRelayed`, `AlreadyAnswered`, `TooEarly`; each request's time kept per opening; first word wins (verify: tests for each refusal, a re-request after 24 hours, and the original's late answer used when it arrives first, the re-request's ignored)
