# Design

## Context

A win is decided on Arbitrum One by `PrizeDraw` (RAF-29, RAF-30). The prizes are on other
chains: Robinhood Chain, Ethereum and ApeChain, with Base later. Robinhood Chain has no
cross-chain messaging endpoint (HANDOVER, verified facts), so a contract on a prize chain cannot
learn of a win from the chain that decided it. The only bridge is a signature from a key that
reads the draw: the worker's (CQ-23). `MysteryBox` and `PrizeDraw` are built, reviewed and
rehearsed (OPS-4, 15 October) and are not changed. The repository's conventions apply: solc
0.8.17 (SeaDrop's pragma), Solady, deterministic unit tests and a BTT tree.

## Goals / Non-Goals

**Goals:**
- A winner pulls their own prize; a contract releases each prize once, only to the winner the
  draw named, within the claim window.
- A leaked worker key is bounded to the current cycle's registered prizes.
- The published prize list is checkable on-chain on every prize chain against the cycle's
  `manifestHash`.
- Unclaimed prizes stay in the vault for a later cycle; MINT keeps control of what is not
  reserved.

**Non-Goals:**
- Relayed or gasless claims; nominating another recipient; bundles across chains.
- Any change to `MysteryBox` or `PrizeDraw`.
- Fee-on-transfer or rebasing tokens.

## Decisions

- **One `PrizeVault` per prize chain, one address.** CREATE2 deployer `0x4e59…956C` (present on
  4663, 1, 33139, 8453 and the testnets 46630, 11155111, 33111) with identical
  `(owner, signer)` arguments: MINT's admin and the worker are EOAs with one address everywhere.
  The page, the worker and the client need one vault address. Alternative: a different address
  per chain, which means a config map everywhere for no gain.
- **The full list on every vault, checked against `manifestHash`.** The vault stores all entries
  (≤ `MAX_PRIZES`) and releases only its own chain's. Registering the full list lets each vault
  recompute the cycle's fingerprint, which the box and the draw already carry, so a vault can't
  be registered with a list other than the published one. Alternative: the ticket names the
  whole prize, which lets a leaked key drain anything the vault holds.
- **Funded before registered.** `registerCycle` checks the vault's balance of each own-chain
  entry against what is already reserved. Balances are read per kind: `address(this).balance`,
  ERC-20 `balanceOf`, ERC-721 `ownerOf`, ERC-1155 `balanceOf`.
- **Reservation by asset key.** `reserved[(kind, token, id)]` sums every registered and unclaimed
  entry. A claim lowers it; `release(cycleId)` after the window lowers it by the cycle's
  unclaimed entries, once. Withdrawal and registration compare against it. Two prizes may share
  a token.
- **The ticket.** EIP-712, domain `("MintABear PrizeVault", "1", chainId, vault)`, message
  `Claim(uint64 cycleId, uint64 openIndex, uint16 prizeIndex, address winner)`; Solady's EIP712
  and SignatureCheckerLib. `msg.sender` is the winner, so a ticket is useless to anyone else and
  needs no secrecy. `openIndex` is bound so each record on the draw maps to one claim; the
  claimed bit is per `(cycleId, prizeIndex)`.
- **The window on the vault's clock.** `end + CLAIM_GRACE` (1 hour), compared with the prize
  chain's `block.timestamp`, never `block.number` (OPS-7).
- **Transfers.** Native by a value call; ERC-20 by Solady `SafeTransferLib`; ERC-721 and
  ERC-1155 by `safeTransferFrom`, so a winner contract that cannot receive refuses the claim and
  the prize carries over. `claim` is non-reentrant and updates state before the transfer.
- **Ownership.** Solady `Ownable`, two-step only; `transferOwnership` and `renounceOwnership`
  revert, as on the box and the draw.

## Risks / Trade-offs

- **The worker's key signs tickets** (the person's choice, Q4 (a)). The vault trusts the signer
  to name the winner, so whoever holds the key can sign tickets naming their own address and
  claim every still-unclaimed prize registered for the current cycle, on every chain. That is the
  bound: no prize outside a registered list, none twice, none after the window (Q3 (b)). Such a
  claim is visible, a `PrizeClaimed` whose winner and opening match no `OutcomeRecorded`. The
  same key also relays on the draw, so one leak touches both. Mitigation: the key stays a secret
  in MINT's Railway project; on a suspected leak, pause the vaults, `setSigner` to a new key and
  `setWorker` on the draw. A separate signing key (Q4 (b)) would have kept a relay-key leak from
  releasing prizes; it can be adopted later with `setSigner` and no contract change.
- **A one-hour window.** Winners screened on Robinhood Chain, or offline for an hour, lose the
  prize to carry-over. This is the person's decision (Q2), stated in OPS-7.
- **Gas on every prize chain.** A winner with no ETH on Ethereum cannot claim there. MINT's
  stated requirement (Q5.2).
- **Audit time.** A new contract on four chains must be reviewed by 31 October; it is small
  (one registration, one claim, one release, one withdrawal).

## Migration Plan

No migration: the box and the draw are unchanged, and no vault exists yet. Deploy to the
testnets with the RAF-18 two-cycle run, then to 4663, Ethereum and ApeChain before the first
cycle (4 November).

## Open Questions

- `MAX_PRIZES`: MINT plans at most 10 a cycle; the cap is set at build time with room above
  that (for example 32) and pinned by a test.
