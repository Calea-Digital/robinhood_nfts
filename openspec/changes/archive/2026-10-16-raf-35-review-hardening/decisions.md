# Decisions Delta

No decision is opened. CQ-11's outcome gains the limit found in MNT-166's self-review.

## Folded by hand into `openspec/decisions.md`

## RESOLVED Decisions

### CQ-11 — May the owner withdraw inventory?
- **Resolution:** the owner withdraws from a vault only what no cycle reserves; a registered
  cycle's prizes are locked against `withdraw` until claimed or released after the claim window
  (RAF-37). The owner's `setSigner` takes effect at once, so the owner can still reach reserved
  prizes by signing its own tickets; accepted with the single admin key (CQ-12).
- Append to the record:

**Limit (Calea, 16 October 2026, the person's choice).** The rule binds `withdraw`, not the
owner. The owner's `setSigner` takes effect at once, so a compromised admin key can name a key of
its own as the signer, sign tickets naming itself, and claim the current cycles' reserved prizes;
a leaked worker key can do the same without the owner until the vault is paused or the signer is
rotated. A delay on `setSigner`, or a signer fixed per cycle, would close this, at the cost of the
instant rotation that answers a leaked worker key. With one admin EOA already controlling every
contract (CQ-12), the risk is accepted and stated in the HANDOVER's accepted risks.
