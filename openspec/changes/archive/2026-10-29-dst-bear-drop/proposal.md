# Proposal

## Why

MINT plans to give $MNTD to MintABear holders. Airdropping it got the token flagged before, so MINT asked
on 29 October 2026 for a contract that lets each bear claim its own amount. A buyer on the secondary
market has to be able to look a bear up by its id and see whether it still has tokens to claim. MINT
plugs the contract into its own claim UI. The distribution can follow the mint; MINT's target is
15–20 November.

## What Changes

- A new contract, `BearDrop`, on Robinhood Chain. It holds $MNTD and pays each bear's amount, in
  numbered rounds, to whoever owns the bear when it is claimed. Each bear claims once per round, inside
  the round's window.
- The owner sets each round's per-bear amounts from MINT's list. Opening the round fixes the amounts, the
  window and a fingerprint of the list, and is refused unless the contract already holds enough $MNTD.
- Anyone can read a bear's amount and whether it has been claimed. That is all an id checker needs.
- The owner can withdraw only what no running round still owes. A round's unclaimed share is freed when
  the round ends, including the share of bears sent to the dead address.
- Calea deploys the contract and loads round 1, checking the list against MINT's CSV with a script. It
  then hands ownership to MINT's admin by two-step handover. MINT funds the contract and opens the round.
- The client library gains the id checker's reads, a wallet's claimable bears, the claim, and the
  admin's calls.
- This is new work outside the SoW and is billed as an extra.
- New requirements: DST-1 to DST-6, and the commercial item DEL-13. Modified: OPS-2 and DEL-6. Added
  and resolved by MINT's answers of 29 October: CQ-25 (500 $MNTD for every bear, 2,222,000 in all),
  CQ-26 (rounds left open), CQ-27 (90 days) and CQ-28 (no external review).

## Capabilities

### New Capabilities
- `distribution` (prefix **DST**): `BearDrop`, the per-bear $MNTD claim. It covers the rounds, the
  claim, the reads, withdrawal, ownership and pause, and the list check.

### Modified Capabilities
- `operations` (OPS): OPS-2 adds `BearDrop` to the Robinhood Chain deployment.
- `deliverables` (DEL): DEL-6 adds the client calls; DEL-13 adds the commercial item.

## Impact

- `packages/contracts` in mintdotio/NFT:
  - new: `src/BearDrop.sol` with its suite and tree, and `script/BearDropList.s.sol`;
  - changed: `Deploy.s.sol` (`runBearDrop`), `docs/RUNBOOK.md` and `docs/DESIGN.md`.
- `packages/contracts-client`: a `drop` module, its ABI, examples and tests.
- MINT's webapp, which is MINT's code: the NFT-id search bar and the claim button, on `/claim` or
  `/nft`.
- No change to `MintABear`, `Activation`, `MysteryBox`, `PrizeDraw` or `PrizeVault`. `BearDrop` only
  reads `ownerOf` and `exists`.
- Audit scope: no external review (CQ-28). Calea's own differential review and `solidity-auditor`
  passes cover `BearDrop`.

## Grilling record

**Round 1** (29 October 2026; the person answering for Calea, every recommendation accepted)
- Q1 Worker key in Railway env vars: treat it as compromised and rotate it before the box opens. MINT
  gets a checklist. Checked afterwards: no mainnet draw or vault exists yet (`42161.json`'s
  `subscriptionId` is 0, `vault.json`'s `signer` is unset), and the testnet draw's worker is
  `0x18D2…1Eff`. The mainnet key is therefore made fresh, after the incident. Not part of this change.
- Q2 Whitelist checker closes 7 November: ask MINT for the new stage date and update WL-5 and CQ-1.
  Assume the stage opens no earlier than 9 November 12:00 UTC. Not part of this change.
- Q3 What sets a bear's amount: per-id amounts written on-chain by the owner in batches and locked when
  the round opens. A flat amount is the special case. No Merkle tree, no proof server. The rule and the
  list are MINT's (CQ-25).
- Q4 Who claims: the owner at claim time. An unclaimed amount travels with the bear, and a transfer
  resets nothing.
- Q5 Rounds: numbered rounds, so later drops need no new contract (CQ-26).
- Q6 Window and leftovers: a `start` and an `end` per round. The owner withdraws only the surplus while
  a round runs, and its unclaimed share after the round ends (window: CQ-27, default 90 days).
- Q7 Funding: MINT funds first. Opening is refused when the balance does not cover it.
- Q8 House pattern: Solady, $MNTD and the collection fixed in the constructor, two-step handover only,
  no renounce, a pause that stops claims only, non-reentrant claims, solc 0.8.17.
- Q9 Spec home: the new family DST, OPS-2 and DEL-6 modified, a new `tranche-3` pick order.
- Q10 Commercial: recorded as DEL-13, billed as an extra, without holding up the start.
- Q11 Assurance: Calea's own review. An external review is MINT's call and MINT pays for it (CQ-28).
- Q12 Client scope: lookup, a wallet's claimable bears, claim, the admin's calls, examples, tests;
  staging on 46630 with test $MNTD `0x15CF…`. The UI is MINT's.

**Round 2** (29 October 2026; every recommendation accepted)
- Q13 Only the bear's owner calls `claim`, and is paid. A claim made on the owner's behalf could strand
  $MNTD in a contract holding the bear.
- Q14 `setAmounts` in batches, editable until the round opens. `openRound` fixes the amounts, the total
  and `listHash`. A script compares the chain with the CSV.
- Q15 Calea deploys, loads round 1 and checks it, then hands ownership to MINT's admin by two-step
  handover. MINT funds and opens.
- Q16 Rounds are independent and may overlap: `claim(roundId, ids)`.
- Q17 `withdraw(to, amount)` above what rounds that have not ended still owe.
- Q18 Events: `AmountsSet`, `RoundOpened`, `Claimed`, `Withdrawn`.
- Q19 Name: `BearDrop`.
- Q20 Dates: CQ-25's list by 10 November, the testnet run by 12 November, mainnet on 13–14 November.

**MINT's answers** (29 October 2026, through the person)
- Amounts: "same for every bear and even team 222 count yes incase we gift them. Let's do 2,222,000
  $MNTD so that's 500 $MNTD per bear. We can always do a second one."
- Window: "Yes sure let's add the claim window of 90 days."
- Rounds: "Let's leave it open so we can do more if we want."
- External review: "out of scope for us."
