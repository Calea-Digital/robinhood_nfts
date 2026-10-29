# Decisions Delta

## ADDED Decisions

### CQ-25 — How much $MNTD each bear gets
- **Statement:** Holders' $MNTD per bear
- **State:** resolved
- **Status note:** MINT, 29 October 2026
- **Section:** DST
- **Resolution:** In round 1, every bear 1–4,444, the team's 222 included, gets 500 $MNTD, 2,222,000 in all. Calea writes the list (4,444 rows of 500) and MINT confirms its checksum.
- **Summary:** 500 $MNTD per bear, all 4,444, 2,222,000 in all
- **Blocks:** DST-1, DST-6

**Question.** How much $MNTD does each bear get in the first round? The same for every bear, or an
amount that varies per bear (rarity, activation level at a date, a tier)? Do the team's 222 bears
count? What is the round's total?

**In plain words.** The contract pays whatever amount the list gives each bear, so any rule works. A
bear held by the dead address can never claim, and its amount comes back to MINT when the round closes
(DST-4).

**Answer (MINT, 29 October 2026).** "same for every bear and even team 222 count yes incase we gift
them. Let's do 2,222,000 $MNTD so that's 500 $MNTD per bear."

**Recorded as.** DST-1 and DST-6: round 1's list is 4,444 rows of 500 $MNTD, so its total is
2,222,000, and MINT funds the contract with that before `openRound`.

### CQ-26 — One distribution or several
- **Statement:** More holder rounds?
- **State:** resolved
- **Status note:** MINT, 29 October 2026
- **Section:** DST
- **Resolution:** Left open: `BearDrop` runs numbered rounds, and MINT may open more with a new list, funding and `openRound`.
- **Summary:** Left open; more rounds possible
- **Blocks:** DST-1

**Question.** Is this a one-off distribution, or will holders get $MNTD again? The answer changes no
code, because `BearDrop` runs numbered rounds. It changes what the page shows and the runbook's cadence.

**Answer (MINT, 29 October 2026).** "We can always do a second one … Let's leave it open so we can do
more if we want."

### CQ-27 — How long holders have to claim
- **Statement:** Claim window per round
- **State:** resolved
- **Status note:** MINT, 29 October 2026
- **Section:** DST
- **Resolution:** 90 days from the round's start. After that anyone can close the round, and MINT's admin can withdraw the unclaimed $MNTD.
- **Summary:** 90 days
- **Blocks:** DST-1, DST-4

**Question.** How long does a round stay claimable? The contract accepts up to 365 days. A short window
returns unclaimed $MNTD sooner; a long one gives secondary buyers more time.

**Answer (MINT, 29 October 2026).** "Yes sure let's add the claim window of 90 days."

### CQ-28 — External review of BearDrop
- **Statement:** External review of BearDrop
- **State:** resolved
- **Status note:** MINT, 29 October 2026
- **Section:** DEL
- **Resolution:** No external review. Calea's differential review and `solidity-auditor` passes cover `BearDrop`, and the report goes to MINT.
- **Summary:** None; Calea's own review only
- **Blocks:** DEL-13

**Question.** `BearDrop` holds holders' $MNTD until it is claimed. Should an external reviewer look at it
before mainnet? It is a small contract: one token, no upgrade path, and no external calls other than
`ownerOf` and the $MNTD transfer.

**Answer (MINT, 29 October 2026).** "out of scope for us."
