# Spec Delta

## ADDED Requirements

### Requirement: WL-8 — Off-chain register
**Kind:** informative
The whitelist is kept off-chain, in MINT's backend (MINT, 28 September 2026, `→ CQ-18`). No
contract is deployed for it.

**The flow.**
1. A holder signs in on getminted.io through Privy, or pastes a wallet address.
2. The eligibility check shows what the account has wagered and what is left to unlock a spot or
   the next one.
3. The holder claims the spots unlocked. A pasted address proves itself with a wallet signature,
   which costs no gas; a wallet connected through Privy already has.
4. The backend records the claim.

MINT's backend keeps the 1,000-spot counter so that two simultaneous claims cannot take the last
spot. It also records whitelist spots from any other source, such as collaborations and
giveaways, in the same register. The final list has **one row per wallet with its total**,
merged across sources, and is the CSV loaded into Studio (WL-4). Nothing about the whitelist is
public until Studio's allowlist root is set; the root is its only trace on-chain.

#### Scenario: The register is MINT's
- **WHEN** the whitelist flow is traced from eligibility to the final CSV
- **THEN** every step runs in MINT's backend and no Calea contract is involved

## MODIFIED Requirements

### Requirement: WL-1 — Rules
**Kind:** informative
From MINT's brief, as MINT's backend applies them (WL-8):

- **1,000 spots**, each the right to mint one bear in the whitelist stage. A spot is an
  allocation: an account at $100 holds two of the 1,000.
- **First come, first served** through getminted.io/mintabear. Reaching a threshold makes the
  getminted.io account eligible for the spot it unlocks; it reserves nothing. A spot belongs to a
  wallet once the backend has recorded its claim.
- **$50 wagered unlocks spot 1; $100 unlocks spot 2.** Historical wagering (Season 1) counts up
  to $50, so spot 2 always needs at least $50 of in-campaign wagering. A holder with $16,361 of
  historical wagering is shown $50: one spot claimable, and $50 more to wager for the second.
- **Live counter** "wagering spots left — X / 1,000", read from MINT's backend. A claim that
  arrives after the last spot is refused whole.
- **The holder selects the NFT wallet** before claiming.
- **Two per wallet, two per account.** Whether spots from collaborations and giveaways count
  toward the 1,000, and whether they may take a wallet above two, is `→ CQ-18`.

#### Scenario: Two per wallet, two per account
- **GIVEN** a wallet holding one claimed spot and an account holding one
- **WHEN** the wallet claims spot 2 after the account has wagered $100
- **THEN** the backend records it and both counts read 2
- **AND** a third claim for either is refused

### Requirement: WL-2 — Division of work
**Kind:** informative
**MINT's part:**
- the Privy login on getminted.io;
- the wager API, which returns historical wagering capped at $50 and in-campaign wagering;
- the eligibility check and the UI;
- the off-chain register with its counter, and the wallet signature for pasted addresses (WL-8);
- the final CSV.

**Calea's part:**
- the check that Studio's allowlist root is the CSV's (WL-4);
- the mint proofs for the getminted.io mirror, built from the same CSV (DEL-6);
- a review of the backend's claim rules, on request.

#### Scenario: The division of work holds
- **WHEN** a step of the whitelist flow is traced
- **THEN** the login, wager API, eligibility check, UI, register and CSV are MINT's, and the root check, the mint proofs and the review are Calea's

### Requirement: WL-4 — Into the mint
**Kind:** work-item
When the list is frozen (WL-5), MINT exports the final CSV — `wallet,allocations`, one row per
wallet — and Iñigo loads it as the whitelist stage's allowlist in Studio. SeaDrop allowlist
entries carry a per-wallet mint limit, so "one or two" is enforced by the mint itself.

That limit counts every bear minted to the wallet in any stage. So:
- the whitelist stage is the first stage in which any wallet can mint, apart from the team's
  (COL-11);
- no other stage overlaps it;
- a later stage's per-wallet limit counts the whitelist mints too.

Calea's `compare` rebuilds the allowlist root from the CSV and the stage's parameters, and fails
unless it is the root on SeaDrop. The getminted.io mirror builds its Merkle proofs from the same
CSV (DEL-6).

#### Scenario: The export is the allowlist
- **GIVEN** MINT's final CSV and the whitelist stage Studio has set
- **WHEN** `compare` runs over the CSV and the stage
- **THEN** it passes only if the root on SeaDrop is the root of the CSV's rows, and fails naming the difference otherwise

### Requirement: WL-5 — Timing
**Kind:** informative
MINT's backend accepts claims only within the campaign window, and the list is frozen at least
48 hours before the whitelist stage opens. That leaves time for the Studio upload, the root check
and a fix before minting. With the whitelist stage opening with the mint on 29 October, the list
is frozen by 27 October, at the same time of day. The 48 hours is Calea's buffer, not a SeaDrop
rule. Dates `→ CQ-1`; calendar in §8.

#### Scenario: The window gates claims
- **GIVEN** a campaign window closing at least 48 hours before the whitelist stage
- **WHEN** a claim arrives outside the window
- **THEN** MINT's backend refuses it, and the list is final before the Studio upload

## REMOVED Requirements

### Requirement: WL-3 — Registry
**Reason:** MINT chose the off-chain register (28 September 2026); `WhitelistClaim` is not deployed and stays in the repository unused.
**Migration:** See WL-8.

### Requirement: WL-6 — Alternative — off-chain register
**Reason:** Adopted; the chosen design is restated as WL-8.
**Migration:** See WL-8.

### Requirement: WL-7 — Owner-imported registry
**Reason:** MINT chose the off-chain register (28 September 2026); `WhitelistImport` is not deployed and stays in the repository unused.
**Migration:** See WL-8.
