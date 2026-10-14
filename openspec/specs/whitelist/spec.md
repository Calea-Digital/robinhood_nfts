# Whitelist claim Specification

## Purpose
MINT runs a 1,000-spot whitelist for its wagering holders in its own backend. Calea's part is to make sure the list Studio mints from is exactly MINT's final list.

## Requirements

### Requirement: WL-1 — Rules
**Kind:** informative
- **Spots.** There are 1,000 wagering spots, and each is the right to mint one bear in the
  whitelist stage.
- **Thresholds.** $50 wagered unlocks spot 1 and $100 unlocks spot 2, with no claim needed in
  between. Wagering from before the account's first login on the page counts up to $50, and
  everything wagered after it counts in full, so spot 2 always needs at least $50 wagered after
  that login. For example, a holder with $16,361 wagered before signing in sees one spot
  claimable and $50 more to wager for the second. A refund can lower the credit, but a claimed
  spot stays.
- **First come, first served** on getminted.io/mintabear. Reaching a threshold makes the account
  eligible but reserves nothing. A spot belongs to the wallet once the backend has recorded the
  claim.
- **Live counter.** It shows "spots left — X / 1,000". A claim that arrives after the last spot
  is refused whole.
- **Limits.** The holder chooses the wallet the bear will mint to. There are at most two wagering
  spots per wallet and two per account. The account's first claim locks its wallet, so its
  second spot goes to the same wallet, and a wallet takes wagering spots from one account only.
  Spots from other channels come on top and do not count toward the 1,000 (WL-8).
- **Every spot has a bear.** The 1,000 wagering spots are guaranteed, and every other channel
  together is capped at 3,222 spots. With the 222 team bears that is exactly 4,444, so every
  whitelist spot can be minted while the whitelist stage runs (WL-4, `→ CQ-24`).

#### Scenario: Two per wallet, two per account
- **GIVEN** a wallet holding one claimed spot and an account holding one
- **WHEN** the wallet claims spot 2 after the account has wagered $100
- **THEN** the backend records it and both counts read 2
- **AND** a third claim for either is refused

### Requirement: WL-2 — Division of work
**Kind:** informative
- **MINT:**
  - the Privy login;
  - the wager API (Season 1 capped at $50, plus campaign wagering);
  - the eligibility check and the page, which also checks a wallet's spots from every other
    channel;
  - the register with its counter, and the wallet signature for pasted addresses;
  - the final list.

Calea wrote the register's code at MINT's request (29 September 2026), outside the statement of
work. MINT deploys, runs and owns it.
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

### Requirement: WL-8 — Off-chain register
**Kind:** informative
The whitelist lives in MINT's backend, and no contract is deployed for it (MINT, 28 September
2026, `→ CQ-18`).
1. A holder signs in on getminted.io with Privy, or pastes a wallet address.
2. The page shows what the account has wagered and what is left to unlock the next spot.
3. The holder claims what is unlocked. A pasted address proves it belongs to the holder with a
   free wallet signature. A wallet connected through Privy has already done so.
4. The backend records the claim.

The backend's counter makes sure two claims at the same moment can't both take the last spot.

Choosing a wallet and each claim take a free signature from that wallet, so nobody can claim to a
wallet they don't control. Wagering figures are read from MINT's wager API on the server at every
view and again inside every claim; nothing the browser sends is trusted.

getminted.io is also a general whitelist checker. The register holds every whitelist spot, from
wagering and from every other channel, such as cross-community collaborations and giveaways, and
a wallet sees all of its spots, wagered or not. Spots from other channels do not count toward the
1,000 and come on top of the two wagering spots; together they are capped at 3,222 (MINT,
29 September 2026). The final list has one
row per wallet, with its total across all channels. The team's spots are
display-only: the checker shows them, but they are never exported, never count toward the 3,222,
and a team wallet can't receive wagering or other whitelist spots, because its team mints would
count against the same per-wallet limit (WL-4). MINT loads the other channels from a CSV. Nothing
about the whitelist is public until Studio's list is set, and after that Studio's list is its only
trace on-chain.

*Technical note.* The register is `apps/whitelist-api` with `packages/whitelist-core` in MINT's
repository, on Railway: the page at `nft.getminted.io` and the API at `mintabear-api.mint.io`,
live since 1 October 2026. The starting point for wagering is the lifetime figure at the
account's first login (`accounts.baseline_cents`), since MINT's wager API reports lifetime
figures only. Signatures are EIP-712, single-use and valid for 10 minutes; smart wallets are
checked through ERC-1271 and ERC-6492. A claim locks the pool's counter row.

#### Scenario: The register is MINT's
- **WHEN** the whitelist flow is traced from eligibility to the final CSV
- **THEN** every step runs in MINT's backend and no Calea contract is involved

## Retired Requirements

- WL-3 (the voucher registry `WhitelistClaim`) → WL-8
- WL-6 (the off-chain register as an alternative) → WL-8
- WL-7 (the owner-imported registry `WhitelistImport`) → WL-8
