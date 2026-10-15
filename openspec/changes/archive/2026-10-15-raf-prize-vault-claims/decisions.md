# Decisions Delta

## Folded by hand into `openspec/decisions.md`

### CQ-22 — How a prize is delivered
- **State:** `open` → `resolved`.
- **Status note:** MINT, 15 October 2026; option B, the winner claims from a prize vault.
- **Resolution:** Option B: a `PrizeVault` on each prize chain holds the cycle's prizes, the
  worker signs a ticket for each win, and the winner claims on the prize's chain until one hour
  after the cycle's end; unclaimed prizes stay in the vault for a later cycle.
- **Rationale:** MINT wants winners to pull their prizes from a contract that releases each one
  only once, to the winner the draw named, rather than trusting a push from a wallet.
- **Blocks:** `RAF-18` → `RAF-18, RAF-35, RAF-36, RAF-37` (the bridge drops the gate once the
  decision is resolved).
- Delete **Needed by** and **Default if deferred** (resolved).
- Append to the record:

**Answer (MINT, 15 October 2026).** Option B. The terms, settled in the grilling of
15 October (change `raf-prize-vault-claims`):
- MINT's admin page sends each cycle's prizes from the prize wallet to the vault during cycle
  setup; MINT's admin then registers the cycle's full prize list on each vault, which checks it
  against `manifestHash` and that it holds this chain's entries.
- The worker's key signs each ticket. Only the winner sends `claim`, and pays gas on the prize's
  chain: MINT stated that a claimer needs ETH on every prize chain.
- The window closes one hour after the cycle's end. A prize not claimed by then, including one
  decided after the window closed, stays in the vault for a later cycle's list.
- Every recipient is treated alike. A smart-contract wallet that does not exist on a prize chain
  cannot claim there, and that prize carries over.
- The worker records each claim on the draw with `recordPayout`, so the payout record is
  unchanged.
