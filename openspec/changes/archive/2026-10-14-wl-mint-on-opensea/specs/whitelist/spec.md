## MODIFIED Requirements

### Requirement: WL-2 — Division of work
**Kind:** informative
- **MINT:**
  - the Privy login;
  - the wager API (Season 1 capped at $50, plus campaign wagering);
  - the eligibility check and the page, which also checks a wallet's spots from every other
    channel;
  - the register with its counter, and the wallet signature for pasted addresses;
  - the final list.
- **Calea:**
  - the check that Studio's list is MINT's final list (WL-4);
  - a review of the backend's claim rules, on request.

#### Scenario: The division of work holds
- **WHEN** a step of the whitelist flow is traced
- **THEN** the login, wager API, eligibility check, UI, register and CSV are MINT's, and the root check and the review are Calea's

### Requirement: WL-4 — Into the mint
**Kind:** work-item
Once the list is frozen (WL-5), MINT exports the final list, one row per wallet with its number
of spots, and Iñigo loads it into Studio's whitelist stage.
- **The mint enforces each wallet's number.** It becomes that wallet's mint limit in the stage.
- **The list names the wallet that will mint.** For a smart wallet, that's the smart wallet's own
  address.
- **The list holds at most 4,222 spots:** the 1,000 wagering spots and at most 3,222 from every
  other channel together. The team's 222 bears are minted first, so every spot has a bear. A spot
  lasts as long as the whitelist stage; bears left unminted go to the next stage.
- **The limit counts every bear the wallet mints, in any stage.** So the whitelist stage is the
  first stage anyone but the team can mint in, no other stage overlaps it, and a later stage's
  limit counts the whitelist mints too.
- **Before the stage opens,** Calea checks that Studio's list is exactly MINT's final list.
- **Holders mint on OpenSea's drop page,** which serves each wallet's proof from Studio's list.

*Technical note.* The final list is a CSV, `wallet,allocations`. Each row becomes a SeaDrop
allowlist leaf whose `maxTotalMintableByWallet` is the row's allocations, and SeaDrop counts it
against every bear minted to the wallet. `compare` in `script/WhitelistExport.s.sol` rebuilds the
allowlist Merkle root from the CSV and the stage's parameters, and fails unless it is the root on
SeaDrop, naming the difference. The row's address is the address that calls `mintAllowList`.
The CSV's allocations total at most 4,222, and `compare` also fails when they total more. The
whitelist stage's `maxTokenSupplyForStage` is 4,444, the collection's total including the team's
222, so the stage can fill every row.

#### Scenario: The export is the allowlist
- **GIVEN** MINT's final CSV and the whitelist stage Studio has set
- **WHEN** `compare` runs over the CSV and the stage
- **THEN** it passes only if the root on SeaDrop is the root of the CSV's rows, and fails naming the difference otherwise

### Requirement: WL-5 — Timing
**Kind:** informative
MINT's backend takes claims only during the campaign window. The list is frozen at least 48
hours before the whitelist stage opens, which leaves time to load it into Studio, check it and
fix anything. The campaign runs from 30 September to 27 October at 12:00 UTC, and
the whitelist stage opens on 29 October at 12:00 UTC (MINT, 12 October 2026). The 48 hours is Calea's buffer, not an OpenSea rule. Dates `→ CQ-1`.

#### Scenario: The window gates claims
- **GIVEN** a campaign window closing at least 48 hours before the whitelist stage
- **WHEN** a claim arrives outside the window
- **THEN** MINT's backend refuses it, and the list is final before the Studio upload
