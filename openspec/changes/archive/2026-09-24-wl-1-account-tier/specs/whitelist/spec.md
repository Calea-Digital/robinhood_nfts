# Spec Delta

## MODIFIED Requirements

### Requirement: WL-1 — Rules
**Kind:** work-item
From MINT's brief, as the contract enforces them:

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: an account at $100 holds two of the 1,000 (`→ CQ-18` confirms this reading).
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes the
  getminted.io account eligible for the allocation it unlocks; it reserves nothing. An allocation
  belongs to a wallet only once its claim transaction has succeeded.
- **$50 wagered unlocks allocation 1; $100 unlocks allocation 2.** Historical wagering (Season 1,
  back-credited) counts up to $50, so allocation 2 always requires at least $50 of in-campaign
  wagering. Who has wagered what is MINT's data (WL-2); each allocation is the account's, claimed
  once, in order (WL-3).
- **Live counter** "wagering spots left — X / 1,000", read from the contract. A claim that
  arrives after the last spot fails whole; there is no partial state.
- **The holder selects the NFT wallet** before claiming and may change it until the claim; the
  claim puts the account's allocation in that wallet. One call to action per unlocked allocation:
  a holder at $75 claims one now and the second later.
- **Two per wallet, two per account.** A getminted.io account cannot spread more than two
  over several wallets.

#### Scenario: Two per wallet, two per account
- **GIVEN** a wallet holding one claimed allocation and an account holding one
- **WHEN** the wallet claims allocation 2 with a valid voucher
- **THEN** the claim succeeds and both counts read 2
- **AND** a third claim for either reverts
