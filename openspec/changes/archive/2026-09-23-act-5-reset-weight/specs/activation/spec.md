# Spec Delta

## MODIFIED Requirements

### Requirement: ACT-5 — Reset
**Kind:** work-item
Cumulative and level read as zero, the weight reads the level-0 weight (ACT-3) and the link
reads `(0, 0)` whenever the counter value they were recorded at differs from the current
`transferNonce`. The reset is a consequence of the transfer (COL-3), not an action: it cannot
be skipped and cannot block a transfer. Return transfers reset like any other.

#### Scenario: A transfer resets everything
- **GIVEN** a bear at level 2 with a Status link
- **WHEN** it is transferred to another wallet
- **THEN** `levelOf` and `cumulativeOf` read zero, `weightOf` reads `weightFor(0)` and `linkOf` reads `(0, 0)`, with no call into `Activation`
