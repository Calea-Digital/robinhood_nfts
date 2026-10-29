# Spec Delta

## MODIFIED Requirements

### Requirement: WL-5 — Timing
**Kind:** informative
MINT's backend takes claims only during the campaign window. The list is frozen at least 48
hours before the whitelist stage opens, which leaves time to load it into Studio, check it and
fix anything. The campaign runs from 30 September to 7 November, and the whitelist stage on
OpenSea moves with it, at least 48 hours after the freeze (MINT, 29 October 2026). The closing hour
and the stage's date and hour follow (→ CQ-1). The 48 hours is Calea's buffer, not an OpenSea rule.
The hand-off on the closing day:
1. Before the close, MINT loads every other channel's spots into the register. Nothing can be
   added after the freeze.
2. At the close, MINT's CTO freezes the register and exports the final list. A second export must
   be byte for byte the same.
3. Within two hours, the list and its checksum reach Iñigo and Calea. Iñigo loads it into Studio,
   and Calea's check (WL-4) passes before the stage opens.

*Technical note.* The register's `admin freeze --out <file>` validates the list and locks the
register for good; claims in flight finish first. `admin export` must reproduce the file's
sha256.

#### Scenario: The window gates claims
- **GIVEN** a campaign window closing at least 48 hours before the whitelist stage
- **WHEN** a claim arrives outside the window
- **THEN** MINT's backend refuses it, and the list is final before the Studio upload
