# Spec Delta

## MODIFIED Requirements

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, transfers ownership, verifies source, and delivers the runbook. After
that it holds no owner key. The one role it may keep is the worker's, if Calea operates the
worker (`→ CQ-23`); `setWorker` lets MINT's admin take that role back at any time. Technical
support runs through 19 November 2026 with agreed response hours (DEL-10).

The runbook is one document, produced via `forge script` tooling. It covers:
- the deploy order (OPS-2);
- the enforcement toggle (OPS-6);
- `Activation`'s pause and unpause around the burn switch-on date (ACT-15);
- the whitelist export or import (WL-4, WL-7);
- the mystery-box cycle and worker sequence (RAF-18).

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one
