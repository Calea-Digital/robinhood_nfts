# Purpose lines

OpenSpec deltas carry requirements only, so each family's new `## Purpose` line is kept here and
written into `openspec/specs/<family>/spec.md` by hand at archive (task 1.3).

## collection
A 4,444-bear collection on Robinhood Chain that MINT runs from OpenSea Studio. It collects royalties on every marketplace sale, and every transfer resets a bear's level, so the rest of the system relies only on ownership and the transfer count.

## whitelist
MINT runs a 1,000-spot whitelist for its wagering holders in its own backend. Calea's part is to make sure the list Studio mints from is exactly MINT's final list.

## activation
Holders burn $MNTD to raise a bear's level, and with it the bear's share of the royalties. No key can fake a level, and every transfer resets it, so a level always proves a burn by the current owner.

## mystery-box
A holder opens a mystery box with a bear they own and learns the outcome on the spot. The box runs in cycles MINT schedules: in each cycle every playable bear gets one shot, and the next cycle gives every bear a new one, whoever holds it. `MysteryBox` on Robinhood Chain runs the cycles and records openings. `PrizeDraw` on Arbitrum One decides each opening and records wins and payouts.

## operations
MINT receives contracts that are correct from their first block, verified on every chain, and handed over with every key, role and a runbook. Running them after 19 November needs nothing from Calea.

## deliverables
Each deliverable and the standard it is accepted against, written down, so both parties can tell when the work is done and what remains.
