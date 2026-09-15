# MintABear — Specification

**Version** 1.0-draft · **Date** 15 September 2026 · **Status** awaiting MINT sign-off

Prepared by Calea for MINT. Sources: *MINTaBear development statement of work* (MINT,
14 September 2026); *Mint <> Calea* meeting (15 September 2026); *MintABear questionnaire v2.0*.
Where the sources differ, this document states the resolution. Where a point is still MINT's to
decide, the requirement states the default Calea builds absent an answer and points to the
question (`→ CQ-n`) in the open-questions register.

**How to read.** Requirements carry stable identifiers: `COL-n` collection contract, `ACT-n`
activation and burn route, `RAF-n` raffle vault, `OPS-n` operations and handover, `DEL-n`
deliverables. Each is a single testable statement. Tests, trees and client replies should cite
these identifiers.

## 1. Scope

### 1.1 In scope — Calea / Rayco

- **MintABear** collection contract on Robinhood Chain (chain id 4663), SeaDrop-compatible,
  managed through OpenSea Studio by MINT.
- **Activation** contract on Robinhood Chain: cumulative $MNTD burn credits, level derivation
  (0–5), royalty-weight table, Status link.
- **Burn-route adapter** for $MNTD, per the route MINT selects (`→ CQ-2`).
- **RaffleVault** contract on the raffle chain: prize intake, rounds, verifiable draw, claims.
- Deployment and verification scripts, runbook, testnet deployments, interface/event/role
  documentation with examples, static and manual review, fuzzing and invariant report.
- Technical support for the getminted.io integration: contract call surface, calldata examples,
  clarifications for MINT's developers.

### 1.2 Out of scope

From the SoW, verbatim: independent audit; existing-contract remediation; on-chain art renderer;
automatic bridges or trading; arbitrary unsupported assets; new casino free spins.

Also out of scope: ERC-6551 token-bound accounts (may be added later under separate scope,
see COL-9); artwork, metadata hosting and reveal (MINT); frontend on Framer, Privy login, the
eligibility checker (MINT); backend workers, indexing, royalty accounting and split, credits,
royalty claims, Status boost, monitoring and alerts (MINT); cross-chain messaging infrastructure
(additional scope if selected under `CQ-2` or `CQ-8`).

### 1.3 Parties and responsibilities

| Party | Responsibility |
|---|---|
| Iñigo (MINT) | Collection management in OpenSea Studio; admin of every contract; approves raffle assets; funds treasury with Robert; accepts deliverables |
| Robert (MINT) | Funds treasury and reserves; settlement |
| Javier (MINT) | Framer UI on getminted.io |
| Lorenzo (MINT) | Shared Privy login; account/Status APIs |
| Guri (MINT) | Eligibility checker |
| MINT automation | Worker key: deposit registration, snapshots, round triggers, draws, burn attestation (route b) |
| Calea / Rayco | Contracts, tests, scripts, runbook, testnets, review, integration support; deploys and hands over; retains no keys or roles |
| Calea internal auditor | Fuzzing and invariant harnesses, review report |

## 2. System overview (SYS)

**Chains.** Robinhood Chain mainnet (4663) hosts `MintABear` and `Activation`: it stores the
bears and is the source of truth for ownership. The `RaffleVault` is deployed on the *raffle
chain*, by default Base (8453) (`→ CQ-8`), where Chainlink VRF v2.5 is available and where
$MNTD is native. Testnets: Robinhood testnet 46630 and Base Sepolia 84532.

**Contracts.**

| Contract | Chain | Purpose |
|---|---|---|
| `MintABear` | 4663 | ERC721SeaDrop collection, 4,444 supply, transfer counter |
| `Activation` | 4663 | Credited burns → level → weight; Status link |
| Burn-route adapter | per `CQ-2` | Moves $MNTD out of existence and produces a credit |
| `RaffleVault` | raffle chain | Prize inventory, rounds, VRF draw, claims |

**Trust model.** Contracts enforce ownership, supply, the transfer counter, level derivation,
the weights table, prize reservation, the draw algorithm and claims. One operator role — MINT's
worker key — supplies inputs the contracts cannot obtain themselves: deposit registration,
the ownership snapshot, round triggers, and (route b) burn attestations. Every input it supplies
is publicly verifiable against chain state. The worker cannot redirect prizes, alter weights or
thresholds, raise a level without a corresponding credit, or move reserved prizes.

**On-chain.** Ownership and transfers; the transfer counter and its event; credited burn
amounts, cumulative totals, levels and weights; Status nominations; raffle inventory and its
states; snapshot commitments; randomness; winners; claims.

**Off-chain (MINT).** The royalty pot and its split; credits and USDT/MNTD reserves; royalty
claims; the Status boost; indexing; alerts. What level 5 is *worth* is MINT's to define; the
chain records that it was reached.

**Flow.** (1) Iñigo configures the drop in Studio; holders mint via OpenSea or the getminted.io
mirror. (2) Holders burn $MNTD along the selected route; `Activation` credits the bear, and its
level and weight follow. (3) Any transfer advances the counter and voids the level, weight and
link. (4) MINT's worker registers prize deposits; at schedule it commits an ownership snapshot,
opens a round, requests randomness; the vault draws; winners claim. (5) MINT reads
`Activation.snapshot` at each royalty closing block and computes the split off-chain.

## 3. Collection contract — MintABear (COL)

**COL-1 Base.** `MintABear` extends OpenSea's `ERC721SeaDrop` with its mint path,
`getMintStats`, metadata and royalty interfaces unchanged. Canonical SeaDrop
`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` is the only allowed minter. The drop is configured
and operated through OpenSea Studio by MINT (COL-11).

**COL-2 Supply.** `MAX_BEARS = 4444` is a constant enforced on the mint path; a mint that would
exceed it reverts with `ExceedsMaxBears`. The inherited `maxSupply` must be set to exactly 4,444
and never raised: a higher value advertises a supply the token will not deliver and buyers past
the cap pay for reverted transactions. Team, treasury and partner bears come out of the same
4,444.

**COL-3 Transfer counter.** `transferNonce(tokenId)` increments on every transfer except mint —
sales, gifts, self-initiated moves and return transfers to a previous owner alike — and never
resets. It is the mechanism by which every ownership change resets level, weight and Status
link (ACT-5).

**COL-4 Reset event.** `TransferNonceAdvanced(uint256 indexed tokenId, uint64 nonce)` is
emitted for every non-mint transfer, in the same transaction as `Transfer`. It is the
activation-reset event: anything `Activation` recorded at the previous counter value is void
once it fires. It fires whether or not a level existed.

**COL-5 Metadata.** Standard SeaDrop metadata: `baseURI` set through Studio,
`tokenURI(id) = baseURI + id`, provenance hash committed with `setProvenanceHash` before the
mint opens. Placeholder JSON, reveal and hosting are MINT's. Artwork is immutable and metadata
does not vary with level.

**COL-6 Royalties.** ERC-2981 through SeaDrop's `setRoyaltyInfo`, configured by Iñigo
(`→ CQ-15` rate and receiver). The receiver is the royalty-treasury address, distinct from the
admin and from the raffle vault.

**COL-7 Creator token and enforcement.** `MintABear` implements `ICreatorToken` (ERC-721C).
It is deployed with the transfer validator **unset**: transfers are unrestricted and creator
earnings on OpenSea are the buyer's choice. Enforcement is an owner operation and reversible:
`setTransferValidator(0x721C002B0059009a671D00aD1700c9748146cd1B)` (Limit Break validator V3 on
4663) with the validator's zero-state policy — security level 0 (operator whitelist, OTC
allowed, no receiver constraint) and list 0 (Limit Break Payment Processor whitelist; OpenSea
SignedZone `0x000056F7000000EcE9003ca63978907a00FFD100` as authorizer). Under that policy a
transfer initiated by the holder always passes; a marketplace transfer passes only through
Payment Processor or an OpenSea SignedZone-restricted order; any other Seaport order reverts.
Security levels 5 and above additionally restrict contract receivers and must not be used.
Before enforcement is enabled on mainnet, a listing and sale of a validated collection on 4663
must be observed on OpenSea (OPS-4), because OpenSea's handling of validated collections on this
chain is not documented. Disabling is `setTransferValidator(address(0))`. `→ CQ-7`.

**COL-8 Burn policy.** Default: the standard `ERC721SeaDrop.burn` is available to a bear's owner
or approved operator; burned ids are never re-minted (ids are monotonic), `totalSupply`
decreases, and every downstream reader treats a burned id as nonexistent (ACT-10, RAF-7).
Alternative: burning refused in the transfer hook. The choice is permanent. `→ CQ-6`.

**COL-9 No token-bound accounts.** ERC-6551 is not part of the collection. It can be added later
without any change to `MintABear`: the canonical registry
`0x000000006551c19487814612e58FE06813775758` derives an account address from
`(chainId, tokenContract, tokenId)` for any ERC-721. The one property that cannot be retrofitted
is a token-side guard against sending a bear into a bear's account.

**COL-10 Ownership.** Deployed by Calea; ownership transferred to MINT's admin address by the
inherited two-step process (`transferOwnership`, then `acceptOwnership` from the admin) before
the drop page is published. Calea retains no role.

**COL-11 What Studio owns.** Mint stages, dates and pricing; allowlists and per-wallet limits;
payout address; `maxSupply` (COL-2); `baseURI` and provenance (COL-5); royalty info (COL-6);
`multiConfigure`. A "guaranteed" stage is guaranteed by stage sequencing — the guaranteed
window must close before the allowlist window opens — not by the contract.

**COL-12 Reads.** `ownerOf`, `exists(tokenId)`, `totalSupply`, `maxSupply`, `MAX_BEARS`,
`transferNonce`, `tokenURI`, `royaltyInfo`, `getTransferValidator`, `getMintStats`, plus the
ERC-721 and SeaDrop standard surface.

**COL-13 Events.** Standard `Transfer`, `Approval`, `ApprovalForAll`; SeaDrop configuration
events; `TransferNonceAdvanced` (COL-4); `TransferValidatorUpdated` (COL-7).

## 4. Activation and burn route (ACT)

**ACT-1 Token-agnostic.** `Activation` holds no reference to $MNTD and never moves tokens. It
records credited burn amounts per bear and derives level and weight from them. It reads
`MintABear` (`ownerOf`, `transferNonce`, `exists`); `MintABear` never calls it, so no defect in
`Activation` can affect a transfer.

**ACT-2 Thresholds.** Five cumulative thresholds `T1 < T2 < T3 < T4 < T5`, in $MNTD base units,
supplied to the constructor and immutable. A bear's level is the highest `k` with
`cumulative ≥ Tk`, or 0. `thresholdFor(level)` and `costToReach(tokenId, level)` expose them.
Default values (whole $MNTD): 5,000 / 15,000 / 40,000 / 100,000 / 250,000. `→ CQ-4`.

**ACT-3 Weights.** Six royalty weights for levels 0–5, basis 100, supplied to the constructor
and immutable: `100 / 110 / 125 / 145 / 170 / 200` (1.00×–2.00×). `weightFor(level)` returns
the table entry; `weightOf(tokenId)` returns the weight of the bear's current level.
`→ CQ-5`.

**ACT-4 Credit.** `credit(uint256 tokenId, address burner, uint128 amount, uint64 nonce,
bytes32 ref)` is callable only by the `crediter` (ACT-7). It reverts unless: not paused;
`amount > 0`; `ownerOf(tokenId) == burner`; `transferNonce(tokenId) == nonce`; `ref` has not
been used. Both ownership checks passing means `burner` has owned the bear continuously since
`nonce` was read — a burn is never credited to a bear that changed hands in between. Effects:
the cumulative for the current counter value increases by `amount`; `lifetimeBurned` increases
by `amount`; `ref` is marked used; `BearActivated(tokenId, burner, previousLevel, newLevel,
amount, cumulative, ref)` is emitted. Any amount is accepted, including beyond `T5` (ACT-8).

**ACT-5 Reset.** Cumulative, level, weight and link read as zero whenever the counter value
they were recorded at differs from the current `transferNonce`. The reset is a consequence of
the transfer (COL-3), not an action: it cannot be skipped and cannot block a transfer. Return
transfers reset like any other.

**ACT-6 Lifetime.** `lifetimeBurned(tokenId)` accumulates every credit ever made to a bear and
never resets.

**ACT-7 Crediter and routes.** Exactly one `crediter` address, set by the owner
(`setCrediter`, event `CrediterSet`). The burn route MINT selects determines who it is
(`→ CQ-2`, `→ CQ-3`):

- **(a) $MNTD on Robinhood Chain.** Crediter is a `DirectBurnAdapter`: the holder approves it
  on $MNTD and calls `burn(tokenId, amount)`; the adapter calls `MNTD.burnFrom(msg.sender,
  amount)` and then `Activation.credit(...)` in the same transaction, reading the counter
  itself and generating a unique `ref`. If $MNTD's own level-up function lives on 4663 and
  calls `credit` directly, $MNTD is the crediter and no adapter is needed. Holds only if $MNTD
  exists on 4663; burning a *bridged* representation leaves the canonical Base supply locked in
  the bridge rather than destroyed.
- **(b) $MNTD on Base — default.** A `BurnForBear` contract on Base exposes `burn(tokenId,
  amount, nonce)`: it calls `burnFrom` on canonical $MNTD and emits
  `BurnedForBear(burnId, tokenId, burner, amount, nonce)`. MINT's attester key is the
  crediter on 4663 and relays each event as `credit(tokenId, burner, amount, nonce,
  ref = burnId)`. Canonical supply is provably reduced; the level record lives beside the
  token. The attester is trusted to relay real burns only, and every credit's `ref` lets anyone
  audit credits against Base events; it cannot credit a bear the burner does not own, nor
  across a transfer. The portal reads `transferNonce` from 4663 immediately before the Base
  burn; if the bear is transferred before the relay lands, `credit` reverts with
  `StaleNonce` and the burn is not credited — the portal must warn holders not to move a bear
  with a burn in flight.
- **(c) Cross-chain messaging.** Crediter is a messaging receiver (LayerZero, Hyperlane or
  CCIP). No endpoint is verified on 4663; this is additional scope as the SoW anticipates.

**ACT-8 Overshoot.** `credit` banks the whole amount; the part above `T5` buys nothing. The
same-chain adapter (route a) reverts with `AlreadyAtMaxLevel` before burning when the bear is
already at level 5; a Base burn (route b) cannot be protected on-chain. In every route the
portal **must** size a burn with `costToReach(tokenId, targetLevel)`, which returns the exact
remainder or zero.

**ACT-9 Status link.** `linkBear(tokenId)`, owner of the bear only, one nomination per wallet,
recorded with the current counter value; `unlinkBear()` clears it and is safe to call when
nothing is linked; `linkOf(wallet) → (tokenId, level)` returns `(0, 0)` when nothing is linked
or the bear has since moved. A wallet aggregates royalty weight across all its bears (ACT-10)
but carries exactly one Status boost; the boost's value is MINT's, off-chain.

**ACT-10 Snapshot view.** `snapshot(uint256[] ids) → (address owner, uint8 level, uint16
weight)[]`, returning zeroes for ids that do not exist. MINT's royalty accounting reads it for
`1..4444` at each closing block; a wallet's weight is the sum over its bears and the total
eligible weight is the sum over all existing bears. Because transfers reset weight without any
call into `Activation`, there is no on-chain running total; the sum is taken off-chain from
this view. A reference script reproducing the split is delivered (DEL-6).

**ACT-11 Pause.** The owner may pause. While paused, `credit` and `linkBear` revert; reads,
`unlinkBear` and every transfer are unaffected. A relayed credit rejected by the pause is
retried after unpause; `ref` makes the retry idempotent. `renounceOwnership` is refused while
paused, so a pause can always be lifted.

**ACT-12 Roles.** Owner (MINT admin): `setCrediter`, `setPaused`, ownership transfer. Nothing
else is administrable: thresholds, weights and records are immutable.

**ACT-13 Events.** `BearActivated` (ACT-4), `BearLinked(wallet, tokenId)`,
`BearUnlinked(wallet, tokenId)`, `CrediterSet(previous, current)`, `PausedSet(paused)`.

**ACT-14 Reads.** `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`, `weightFor`,
`thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `crediter`, `BEARS`.

## 5. Raffle vault (RAF)

**RAF-1 Chain.** `RaffleVault` is deployed on the raffle chain, by default Base (8453)
(`→ CQ-8`). Prizes must be native to the raffle chain; $MNTD baskets exist only if $MNTD is on
that chain. Robinhood Chain remains the source of truth for ownership: when the raffle chain is
not 4663, ownership enters each round as a committed snapshot (RAF-7) that anyone can recompute
from 4663 state. If MINT selects 4663 as the raffle chain instead, prizes must be bridged there
and randomness is relayed from Chainlink VRF on another chain — a trusted relay by default, or
on-chain re-verification of the VRF proof as additional scope.

**RAF-2 Address.** The vault contract is the dedicated deposit address, separate from the
royalty treasury and from the admin.

**RAF-3 Asset approval.** The owner approves each asset once: `approveAsset(token, kind,
basketSize)` with `kind ∈ {ERC20, ERC721}`; `basketSize` is in base units for ERC-20 ($MNTD:
5,000 × 10^decimals) and ignored for ERC-721. `revokeAsset` stops an asset entering future
rounds and never touches reserved prizes. Unapproved assets never enter a round. ERC-1155 is not
supported.

**RAF-4 Intake.** Deposits are plain transfers to the vault. Nothing happens until the worker
registers them: `registerERC721(token, id)` requires `ownerOf(id) == vault` and the id not yet
tracked; `syncERC20(token)` adds `balanceOf(vault) − tracked` to unreserved inventory. Token
transfers alone never change round state. Each registration emits `DepositRegistered`.

**RAF-5 Inventory states.** Unreserved → reserved (in an open round) → won → claimed; or
won → expired → unreserved. Reserved and won prizes cannot be withdrawn, reused, swept or moved
by anyone but the winner, whether or not the vault is paused.

**RAF-6 Round opening.** The worker calls `openRound(snapshot, minLevel, claimWindow)`. Every
unreserved full basket of every approved ERC-20 and every unreserved registered ERC-721 is
reserved into the round; ERC-20 remainders below a basket stay unreserved. The prize list is
ordered ERC-721 prizes in registration order, then baskets in asset-approval order; it is fixed
and public before the draw. A round with no prizes cannot be opened. Deposits registered after
opening enter a future round.

**RAF-7 Snapshot.** `(uint64 block, bytes32 blockHash, Entry[] entries)` with `Entry = (address
wallet, uint32 tickets)`: `tickets` is the number of bears the wallet owned at that Robinhood
block whose level was at least `minLevel`; entries sorted by wallet ascending, no duplicates,
`tickets > 0`. One bear is one ticket; at a single block every bear has one owner, so no wallet
can count a bear twice. The vault stores `keccak256(abi.encode(entries))` with the block
reference and emits `RoundOpened`; the entries are in the transaction's calldata permanently.
Anyone recomputes the snapshot from `MintABear.ownerOf` and `Activation.snapshot` at that block
and compares the hash. The snapshot is committed before randomness is requested (RAF-8), so the
worker cannot tailor it to the seed.

**RAF-8 Randomness.** Chainlink VRF v2.5 on the raffle chain: one request per round after the
snapshot is committed, one random word, subscription owned and funded by MINT with the vault as
consumer (`→ CQ-17`). Round states: Open → RandomnessRequested → Drawn. The fulfilment
callback stores the seed only; `draw(entries)` (RAF-9) runs the selection.

**RAF-9 Draw algorithm (normative).** Inputs: the committed entries `E` (verified against the
stored hash), the ordered prize list `P`, the seed `s`. Let `remaining = Σ tickets`. For `i` from
0 to `|P|−1`: if `remaining == 0`, stop; `r = uint256(keccak256(abi.encode(s, i))) mod
remaining`; walk `E` in order accumulating tickets and the first entry whose cumulative total
exceeds `r` wins prize `i`; then `remaining −= entry.tickets` and `entry.tickets = 0`. Winners
are distinct wallets, selection is ticket-weighted, and a wallet wins at most one prize per
round. On Base the selection executes on-chain in `draw`. On a chain where that cost is
prohibitive, the worker executes the identical algorithm off-chain and posts the winners; the
inputs are the same public data, so the result is reproducible by anyone either way.

**RAF-10 Carry forward.** Prizes left unassigned when tickets run out return to unreserved
inventory at the draw and enter the next round (`PrizesCarriedForward`).

**RAF-11 Claims.** `claim(roundId, prizeIndex)`: caller is the recorded winner; the prize is
unclaimed; `block.timestamp ≤ drawnAt + claimWindow`. The prize (ERC-20 basket or ERC-721) is
transferred to the caller. Claims are single-use and non-transferable, and the right belongs to
the snapshot wallet regardless of what it does with its bears afterwards. Default `claimWindow`
30 days (`→ CQ-10`). After the window, `expirePrize` (anyone) returns the prize to unreserved
inventory; a claimed prize never expires.

**RAF-12 Cancellation.** The owner may cancel a round only while it is Open or
RandomnessRequested (randomness failure); its reserves return to unreserved inventory and a
late fulfilment is ignored. Once Drawn, nothing about a round can change.

**RAF-13 Eligibility.** Round 1 uses `minLevel = 0`: ownership only. `minLevel` is supported
for later rounds through the snapshot (RAF-7). Rounds gated on MINT Status are out of scope:
Status is off-chain data that no chain can verify, so such a round would be a "curated" round
whose eligibility list MINT signs and publishes — a different trust model, and it must be
visibly labelled as one.

**RAF-14 Roles.** Owner (MINT admin): `approveAsset`, `revokeAsset`, `setWorker`,
`cancelRound`, `setPaused`, `sweep`. `sweep` moves unapproved tokens and — by default —
unreserved inventory of approved assets out of the vault, with an event; it can never touch
reserved or won prizes (`→ CQ-11`). Worker (MINT automation key): `registerERC721`,
`syncERC20`, `openRound`, `requestRandomness`, `draw`. Anyone: `claim` as a winner,
`expirePrize`, all reads.

**RAF-15 Pause.** Pausing blocks registration, opening, randomness requests and draws. It never
blocks `claim` or `expirePrize`.

**RAF-16 Events.** `AssetApproved`, `AssetRevoked`, `DepositRegistered`, `RoundOpened(roundId,
snapshotHash, block, blockHash, prizeCount, minLevel, claimWindow)`, `RandomnessRequested`,
`RoundDrawn(roundId, seed)`, `PrizeAwarded(roundId, prizeIndex, winner)`, `PrizeClaimed`,
`PrizeExpired`, `PrizesCarriedForward`, `RoundCancelled`, `Swept`, `WorkerSet`, `PausedSet`.

**RAF-17 Reads.** Unreserved inventory per asset; round state, snapshot hash, block reference,
prize count, `drawnAt`, `claimWindow`; prize by index (asset, id or amount, winner, claimed);
`claimable(wallet)`; `isApproved(token)`.

**RAF-18 Worker sequence.** Detect deposits → register/sync → at schedule: take the 4663
snapshot at a finalized block → `openRound` → `requestRandomness` → on fulfilment `draw` →
publish results → after the window, expire unclaimed prizes. MINT's UI shows current inventory,
each wallet's tickets, results and claims; the section is hidden while no prizes are available.

**RAF-19 Acceptance cases (from the SoW).** Token baskets group correctly; two NFTs from one
collection go to two different wallets; a deposit after opening waits for the next round;
reserved prizes cannot be withdrawn or reused; fewer eligible wallets than prizes carries the
excess forward; a randomness failure is cancelled and reserves released; a wallet holding many
bears wins at most once and a bear counts once; a winner who sells their bear after the draw can
still claim.

## 6. Operations, roles and handover (OPS)

**OPS-1 Addresses.** Five addresses are recorded before mainnet deployment (`→ CQ-12`):

| Role | Holds | Recommendation |
|---|---|---|
| Admin | owner of `MintABear`, `Activation`, `RaffleVault` | Safe multisig controlled by Iñigo |
| Worker | `RaffleVault` worker | EOA held by MINT automation |
| Attester (route b) | `Activation` crediter | EOA held by MINT automation |
| Royalty treasury | ERC-2981 receiver | MINT, separate from admin |
| Raffle vault | the `RaffleVault` contract itself | — |

**OPS-2 Deployment order.** On 4663: `MintABear(name, symbol, [SeaDrop])` → `setMaxSupply(4444)`
→ provenance, `baseURI`, royalties through Studio → two-step ownership transfer.
`Activation(bears, thresholds, weights)` → `setCrediter` → ownership transfer. The route
adapter per `CQ-2`. On the raffle chain: `RaffleVault(vrfCoordinator, subscriptionId, keyHash,
worker)` → `approveAsset` for each prize asset → ownership transfer. Each contract is deployed
before the page that depends on it is published.

**OPS-3 Verification.** Sourcify for 4663 and 46630 (mainnet Blockscout's API sits behind a bot
challenge); Basescan or Sourcify for Base.

**OPS-4 Rehearsal on testnet (46630 + 84532).** Studio attaches to and manages a self-deployed
`MintABear`; both mint paths (OpenSea and the getminted.io mirror); a burn along the selected
route through to a credited level; a full raffle round from deposit to claim to expiry; and, if
`CQ-7` is yes, an OpenSea listing and sale of a validated collection on 4663 — this last one
cannot be proven on testnet alone and is confirmed on mainnet before enforcement is switched on.

**OPS-5 Handover.** Calea deploys, configures, transfers ownership, verifies source, and delivers
the runbook; after that it holds no key and no role. Technical support runs through
19 November 2026 with agreed response hours (DEL-10).

**OPS-6 Enforcement runbook.** Enable: `MintABear.setTransferValidator(0x721C002B…)`; leave the
validator's zero-state policy. Optional, from the admin: `createList`, `addAccountsToWhitelist`,
`addAccountsToAuthorizers`, `applyListToCollection`, `setTransferSecurityLevelOfCollection`
(never level 5 or above). Disable: `setTransferValidator(address(0))`. Every step is an owner
call and reversible.

**OPS-7 Chain constraints.** On Robinhood Chain `block.number` is the L1 height — contracts and
scripts key on timestamps. Sequencer-level compliance screening can block an individual
holder's transactions, so nothing in the system requires a holder to act by a deadline in
order for the system to stay correct: an unclaimed prize expires back to inventory and nothing
else depends on it. Randomness is not available on 4663, which is why the VRF lives on the
raffle chain.

## 7. Calendar (CAL)

The SoW's dates are the formal schedule. The mint has been given leeway to 29 October 2026
(meeting of 15 September); dates that depend on the mint are confirmed under `→ CQ-1`.

| Date (2026) | Outcome | Lead |
|---|---|---|
| to 18 Sep | Iñigo's Studio/admin access and wallet roles; page and branding; networks, economics, providers, staffing agreed | Iñigo; Calea; Lorenzo |
| 21 Sep – 2 Oct | Final collection reviewed, tested, deployed; official OpenSea page and URL live before promotion; Studio, sponsorship and burn route proven; checker and login built | Calea; Iñigo; Guri/Javier; Lorenzo |
| 5 – 9 Oct | Raffle, deposit worker and UI tested, including basket grouping and unique winners; reports and runbooks; no open Critical/High | Calea; Javier; MINT |
| 12 – 14 Oct | Raffle vault deployed, verified, funded; roles and official addresses verified; both mint paths, deposits, draw and claims rehearsed | Calea; Iñigo; Javier; MINT |
| 15 Oct → **29 Oct** | Both mint pages live; royalty tracking and countdown start; first raffle previewed; burns disabled | Iñigo; Javier; Calea |
| 16 – 19 Oct (→ CQ-1) | First holder-only raffle opens 16 Oct, draws 19 Oct; funded, transferable prizes on the raffle chain; $MNTD only when available there | Calea; Javier; MINT worker; Iñigo |
| 20 – 26 Oct | TGE and Status on 20 Oct; real burns and APIs verified; royalty allocation, expiry and rollover simulated | Calea; MINT; Lorenzo |
| 27 Oct (→ CQ-1) | Tested burns, weights and Status linking enabled; optional level-gated raffles | Calea; Javier; MINT; Iñigo |
| 5 – 19 Nov (→ CQ-1) | First backed royalty claims 5 Nov, weekly after; first expiry and rollover verified; operations handed over by 19 Nov | MINT; Calea support; Iñigo/Robert |

Two decouplings hold whatever moves: the collection deploys and mints without the raffle vault
or the burn route being live, and burns stay disabled until the route is tested against real
$MNTD.

## 8. Deliverables and acceptance (DEL)

**DEL-1 Source.** Warning-free `forge build`; Slither with no High or Critical finding, every
accepted Medium documented.

**DEL-2 Tests.** Deterministic unit and integration tests with a branching tree per contract;
at least 90% line coverage (the current suite is at 100% line and branch).

**DEL-3 Review report.** Static and manual review, plus fuzzing and invariant harnesses written
and run by Calea's internal auditor independently of the developer; every Critical and High
finding fixed before mainnet deployment; report delivered with the tranche.

**DEL-4 Testnet.** Verified addresses on 46630 and 84532 for every contract.

**DEL-5 Scripts and runbook.** `forge script` deployments and configuration for each chain,
Sourcify verification, and a runbook covering deploy order, role handover, enforcement toggle,
pause, and the worker sequence.

**DEL-6 Integration package.** Interfaces, events, roles and calldata examples for every
contract; a typed client library for getminted.io covering mint (SeaDrop stages, allowlist
proofs, `mintPublic`), activation, link and raffle calls; a reference script that reproduces
the royalty split from `Activation.snapshot` so that "allocations plus carried rounding equal
funding" is testable by MINT.

**DEL-7 Existing-contract review.** A read of the contract MINT names, within the agreed line
limit; findings only, no remediation (`→ CQ-13`).

**DEL-8 Audit tranches.** Tranche 1: `MintABear` and `Activation` with the crediter interface.
Tranche 2: the route adapter and `RaffleVault`, once `CQ-2` and `CQ-8` are answered. Iñigo
accepts after Calea and MINT sign off; anything not accepted stays disabled in the UI.

**DEL-9 Repository.** The contracts live in MINT's monorepo (`github.com/mintdotio/NFT`) as
`packages/contracts` (`@mint/contracts`), a Foundry package with a thin `package.json` so
`pnpm -r build|test|check` reach it; CI runs `forge fmt --check`, `forge build --sizes`,
`forge test` (`→ CQ-14`).

**DEL-10 Commercial items for Rayco's agreement.** Listed here so nothing is implied: prize
intake and unique-winner logic; weight interfaces; Studio and Framer assistance; mainnet
execution and role handover; technical support through 19 November with agreed response hours;
cross-chain messaging (route c) or VRF proof re-verification as additional scope; the
existing-contract review.

## 9. Assumptions and defaults

Absent an answer by the date in the register, Calea builds the default:

| Question | Default |
|---|---|
| CQ-1 calendar | SoW dates after the mint shift by the same 14 days; TGE stays 20 Oct |
| CQ-2 burn route | (b) burn on Base, attested credit on 4663 |
| CQ-3 credit design | as specified in ACT-4 / ACT-7 |
| CQ-4 thresholds | 5,000 / 15,000 / 40,000 / 100,000 / 250,000 $MNTD |
| CQ-5 weights | 1.00 / 1.10 / 1.25 / 1.45 / 1.70 / 2.00 |
| CQ-6 NFT burn | standard burn available |
| CQ-7 enforcement | deploy unset; decide after rehearsal |
| CQ-8 raffle chain | Base |
| CQ-9 entry model | passive snapshot |
| CQ-10 claim window | 30 days |
| CQ-11 owner sweep | unreserved inventory sweepable, evented |
| CQ-12 addresses | Safe for admin; EOAs for worker and attester |
| CQ-13 existing-contract review | not started until named |
| CQ-14 monorepo | `packages/contracts`, `lib/` as submodules, CI ported |
| CQ-15 royalty | not deployable until given |
| CQ-16 compliance | no freeze or clawback |
| CQ-17 VRF subscription | MINT-owned and funded |

## 10. Sign-off

| Party | Name | Date | Signature |
|---|---|---|---|
| MINT | Iñigo Gaston | | |
| Calea | Bojan Jovin | | |
| Rayco | | | |

Version 1.0-draft, 15 September 2026. Amendments are issued as new versions of this document;
requirement identifiers are never reused.
