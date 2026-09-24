# Decisions Delta

## ADDED Decisions

### CQ-21 — How MINT's Status counts links across an account's wallets
- **Statement:** Status links per account
- **State:** open
- **Status note:** new; from the tranche-1 review, 24 September 2026
- **Section:** ACT
- **Needed by:** 2026-10-29 — before burns, level-up and Status linking open
- **Resolution:** Open; Calea recommends the account's single highest-level link
- **Default if deferred:** MINT's Status counts one link per getminted.io account: the highest-level bear among the links of the account's wallets.
- **Blocks:** ACT-9

**Question.** `Activation` lets each **wallet** nominate one bear to carry its Status boost
(ACT-9), and a getminted.io account may use several wallets — the whitelist already counts two
per account across them (WL-1, WL-3). So one account can hold several links at once, one per
wallet. How does MINT's Status treat them: one link per account (and if so, which — the highest
level, the most recent, a wallet the account marks as primary), or every wallet's link, each
boosting the account?

**In plain words.** A holder with two wallets could link a bear in each. The contract records
both and reads each bear's current level; what the Status boost is worth, and whether two links
count twice, is MINT's rule, off-chain.

**Calea's recommendation.** One boost per account: MINT reads `linkOf` for every wallet the
account's Privy login ties to it and applies the highest level among them. It keeps "one Status
boost" true per account whatever the number of wallets, needs nothing from the holder beyond the
links they already make, and needs no contract change. Any other answer needs no contract change
either — only MINT's Status service and the portal's wording follow it.
