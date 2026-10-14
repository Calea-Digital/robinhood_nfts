## MODIFIED Requirements

### Requirement: OPS-5 — Handover
**Kind:** work-item
Calea deploys, configures, hands over ownership, verifies the source and delivers the runbook,
then holds no owner key. The one role it may keep is the worker's, if Calea runs it (O4), and
MINT's admin can take that back at any time. Technical support runs until 19 November 2026 with
agreed response hours (DEL-10). The runbook covers:
- the deployment order (OPS-2);
- switching royalty enforcement off and on (OPS-6);
- pausing and opening burns around 29 October (ACT-15);
- loading the whitelist into Studio and checking it (WL-4);
- running a mystery-box cycle (RAF-18);
- moving each contract's ownership to a new owner, such as a multisig (COL-10, ACT-12, RAF-14).

*Technical note.* The runbook is one document, backed by `forge script` tooling. MINT's admin
takes the worker role back with `setWorker` `→ CQ-23`. The ownership steps cover all four contracts: `MintABear`'s
`transferOwnership` then `acceptOwnership`, and the Solady handover on `Activation`, `MysteryBox`
and `PrizeDraw` (`requestOwnershipHandover` from the new owner, `completeOwnershipHandover` from
the owner within 48 hours), each with its read-back of `owner()`, and the same steps as a Safe
proposes them.

#### Scenario: Nothing stays with Calea
- **WHEN** handover completes
- **THEN** every contract's owner is MINT's admin, every source is verified and the runbook is delivered
- **AND** Calea holds no owner key, and no role other than the worker's where CQ-23 gives it one
