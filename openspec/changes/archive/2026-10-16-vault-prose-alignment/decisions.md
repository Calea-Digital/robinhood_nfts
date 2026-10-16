# Decisions Delta

No decision is opened or decided here. Three resolved entries still state the prize-wallet model
of 28 September as their outcome, and MINT replaced it on 15 October (CQ-22, option B). Each one
keeps its record and gains a closing paragraph.

## Folded by hand into `openspec/decisions.md`

## RESOLVED Decisions

### CQ-8
- **Status note:** call, 28 September 2026; superseded by CQ-22, 15 October 2026.
- **Resolution:** prizes are NFTs and tokens on Robinhood Chain, Ethereum and ApeChain (Base
  possibly later), held by a `PrizeVault` on each prize chain at one address and funded from
  MINT's prize wallet `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3` during cycle setup (CQ-22,
  RAF-35).
- **Summary:** A prize vault on each prize chain, funded from MINT's prize wallet
- **Blocks:** `RAF-33` → `RAF-33, RAF-35`.
- Append to the record:

**Superseded (MINT, 15 October 2026, CQ-22).** Winners claim from a prize vault. MINT's admin
page sends each cycle's prizes from the prize wallet to the `PrizeVault` on their chain, and the
vault releases each one only to its winner (RAF-35, RAF-36). The wallet remains the source of
the prizes, no longer their custody, and a contract is deployed on every prize chain.

### CQ-11 — May the owner withdraw inventory?
- **Status note:** superseded at the call, 28 September 2026; answered by the vault, 15 October
  2026 (CQ-22).
- **Resolution:** the owner withdraws from a vault only what no cycle reserves; a registered
  cycle's prizes are locked until claimed or released after the claim window (RAF-37).
- **Summary:** Unreserved prizes only; the vault enforces it
- Append to the record:

**Superseded (MINT, 15 October 2026, CQ-22).** The prizes are in vaults again, so the vault
enforces the rule MINT gave. From registration until the claim window closes, a cycle's prizes
on a chain are reserved for their winners, and the owner's `withdraw` is refused for anything
reserved (`Reserved`). After the window, `release` frees what was not claimed, and it carries
over to a later cycle's list or can be withdrawn (RAF-37).

### CQ-20 — Prize count, odds and the token ids out of play
- **Status note:** meeting, 12 October 2026; every bear plays; ApeChain a prize chain, Base
  possible later; custody by vault, 15 October 2026 (CQ-22).
- **Resolution:** the owner sets each cycle's prize count and prize list from MINT's admin page;
  **every bear plays**, the team's 222 included, so no id is excluded and 4,444 bears play each
  cycle; prizes are held by a `PrizeVault` on Robinhood Chain, Ethereum and ApeChain, and
  possibly Base in a later cycle, funded from MINT's prize wallet.
- **Default if deferred:** prizes on Robinhood Chain and Ethereum only; adding ApeChain later
  means one vault deployment there and a chain on the page.
- Append to the record:

**Superseded (MINT, 15 October 2026, CQ-22).** Every prize chain carries a `PrizeVault`, deployed
at the same address on each through the CREATE2 deployer (OPS-2, RAF-35). Adding Base means
deploying the vault there before the first cycle that holds a prize on Base, as well as a line in
that cycle's list and a chain on the page. Calea still checks the prize wallet's address on a new
chain before its first cycle, because the wallet funds that chain's vault.
