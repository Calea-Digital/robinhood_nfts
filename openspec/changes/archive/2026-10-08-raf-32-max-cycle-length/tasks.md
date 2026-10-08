# Tasks

## 1. Spec

- [x] 1.1 Lint; archive; render the prose; commit; board (verify: read-back passes; MNT-136 and MNT-58 carry the new text)

## 2. Code (`mnt/RAF-32`, MNT-136, In Review)

- [ ] 2.1 `MAX_CYCLE_LENGTH = 90 days`; `scheduleCycle` refuses `end - start` above it with `InvalidWindow` (verify: a test accepts exactly 90 days and refuses 90 days and one second; tree leaf)
