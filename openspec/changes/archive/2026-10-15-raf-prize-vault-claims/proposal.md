# Proposal

## Why

MINT answered CQ-22 on 15 October 2026: winners claim their prizes from a contract (option B of
the message of 14 October). A contract that holds each cycle's prizes and releases each one
only once, to the winner named by the draw, replaces delivery from MINT's prize wallet. The first
cycle opens on 4 November, so the vault is built, audited and deployed by 31 October.

## What Changes

- **BREAKING (design):** a `PrizeVault` contract is deployed on every prize chain (Robinhood
  Chain, Ethereum, ApeChain; Base when a cycle first uses it). This reverses "no contract on a
  prize chain" (RAF-33, OPS-2, MINT's 28 September decision).
- MINT's admin page sends each cycle's prizes from the prize wallet to the vault during cycle
  setup, then MINT's admin registers the cycle's full prize list on each vault. The list must
  hash to the cycle's `manifestHash`, and the vault must already hold this chain's entries.
- After Chainlink decides a win, the worker signs a claim ticket with its key. The winner claims
  on the prize's chain, paying gas there, until one hour after the cycle's end. Each prize is
  released once, only to the winner.
- A prize not claimed in time stays in the vault, no longer reserved, for a later cycle's list.
  MINT's admin can withdraw any unreserved asset and never a reserved one.
- The worker records each claim on the draw with `recordPayout`, so the payout record is
  unchanged.
- New: RAF-35, RAF-36, RAF-37. Modified: RAF-32, RAF-33, RAF-14, RAF-16, RAF-17, RAF-34,
  RAF-18; OPS-2, OPS-3, OPS-7; DEL-6, DEL-8. CQ-22 is resolved.

## Capabilities

### New Capabilities
- None. The vault belongs to the mystery box (`mystery-box`, prefix RAF).

### Modified Capabilities
- `mystery-box` (RAF): the vault, the claim, carry-over and withdrawal; custody, roles, events,
  reads, pause and the worker's sequence.
- `operations` (OPS): deployment and verification on the prize chains; the claim window as the
  one deadline a holder faces.
- `deliverables` (DEL): the client library's vault calls; `PrizeVault` in audit tranche 2.

## Impact

- New contract `src/PrizeVault.sol` in `packages/contracts` (mintdotio/NFT), with its suite and
  tree, a deploy entry point and its verification on four mainnets and three testnets.
- `apps/box-worker`: signs tickets, serves them, watches claims and records them (RAF-18's payout
  step, until now left open on CQ-22).
- `packages/contracts-client`: funding transfers, cycle registration, the claim, the vault's
  reads and the admin's calls.
- MINT's admin page and play page (MINT's code) gain the funding and registration steps and the
  claim button. Winners need gas on the prize's chain.
- Audit scope: tranche 2 gains `PrizeVault`. `MysteryBox` and `PrizeDraw` are unchanged.

## Grilling record

**Round 1** (15 October 2026; the person answering for Calea and MINT)
- Q1 Family: the RAF family, with modified RAF/OPS/DEL requirements — **(a)**.
- Q2 Claim window, given OPS-7 and last-minute wins: a grace period after the cycle's end —
  **(a), but 1 hour, not 7 days. "Let's make it 1 hour and then close. Anything unclaimed
  carries over to the next cycle rewards."**
- Q3 What the vault knows: the owner registers the cycle's full list, checked against
  `manifestHash`; a ticket names only the cycle, opening, prize and winner — **(b)**.
- Q4 Which key signs: **(a) the worker's key**, not a separate signer (recommendation was (b)).
- Q5 Recipient, submitter, smart wallets — asked to explain (round 2).
- Q6 Owner withdrawal: reserved prizes can't be withdrawn while claimable — **(b)**.
- Q7 Payout record: the worker records each claim with `recordPayout` — **(a)**.
- Q8 Ticket delivery: the worker serves it over HTTP — **(a)**.
- Q9 Pause stops claims and never moves the deadline; the owner rotates the signer — **agree**.
- Q10 One vault per prize chain at one address through CREATE2, owned by MINT's admin, rehearsed
  on the testnets; `PrizeVault` in tranche 2 — **agree**.
- Q11 Who answers for MINT: "the grace period is 1 hr; … for reservation I answered."

**Round 2**
- Q5.1 The prize always goes to the opener — **yes**.
- Q5.2 Who sends `claim`: **only the winner. "It was explicitly stated by MINT that the claimer
  needs to have ETH on all prize chains in order to be able to claim rewards."**
- Q5.3 Smart wallets: **"treat all recipients as EOA. If it is a smart contract and it receives
  an award on one chain (example Eth) but does not exist on another (example Robinhood), the
  prize on Eth gets claimed, but the prize on Robinhood goes to the next cycle."**
- Q12 A win decided after the window closes: **(a)** it carries over like any unclaimed prize.
- Q13 Carry-over: the prize stays in the vault, unreserved, for a later cycle's list; RAF-32 and
  OPS-7 say so — **agree**.

**Closing** — two defaults proposed and accepted with the list: registration is refused unless
the vault already holds this chain's entries, and `manifestHash` is `keccak256(abi.encode(entries))`
over the full ordered list, computed the same way for the box, the draw and every vault. Added by
the person at the close: **"sending rewards from the specified EOA to the PrizeVault is done from
admin page during the raffle setup/config process by MINT admin."**

## Out of scope

- Fee-on-transfer and rebasing tokens.
- A claim sent by anyone but the winner; relayers.
- Redirecting a prize to another address.
- Automatic return of prizes to MINT's prize wallet.
- Cross-chain messaging.
- One win paying a bundle of prizes across chains.
- A per-ticket deadline: one window per cycle.
