## MODIFIED Requirements

### Requirement: WL-5 — Timing
**Kind:** informative
MINT's backend takes claims only during the campaign window. The list is frozen at least 48
hours before the whitelist stage opens, which leaves time to load it into Studio, check it and
fix anything. The campaign runs from 30 September to 27 October at 12:00 UTC, and the whitelist
stage opens on 29 October at 12:00 UTC (MINT, 12 October 2026). The 48 hours is Calea's buffer,
not an OpenSea rule. Dates: CQ-1. The hand-off on 27 October:
1. Before 12:00 UTC, MINT loads every other channel's spots into the register. Nothing can be
   added after the freeze.
2. At 12:00 UTC, MINT's CTO freezes the register and exports the final list. A second export must
   be byte for byte the same.
3. By 14:00 UTC, the list and its checksum reach Iñigo and Calea. Iñigo loads it into Studio, and
   Calea's check (WL-4) passes before the stage opens.

*Technical note.* The register's `admin freeze --out <file>` validates the list and locks the
register for good; claims in flight finish first. `admin export` must reproduce the file's
sha256.

#### Scenario: The window gates claims
- **GIVEN** a campaign window closing at least 48 hours before the whitelist stage
- **WHEN** a claim arrives outside the window
- **THEN** MINT's backend refuses it, and the list is final before the Studio upload
