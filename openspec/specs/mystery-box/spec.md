# Mystery box raffle Specification

## Purpose
A holder opens a mystery box with a bear they own and learns the outcome there and then. One
bear is one shot: the open spends that id for good, and nobody can play it again, whoever holds
the bear afterwards. There are no rounds, no entry window and no scheduled draw (MINT, CQ-9).
Three contracts: `MysteryBox` on Robinhood Chain, where the bears are, so an open is checked
against live ownership; `PrizeDraw` on a chain with Chainlink VRF, which decides each open with
a random word of its own; and a `PrizeVault` on every chain that holds prizes, because a prize
can only be handed over where it sits.

## Requirements

### Requirement: RAF-26 — The game
**Kind:** work-item
One game over the collection, not a series of rounds. States: **Setup** —
prizes deposited, registered and committed, excluded ids recorded, nothing openable; **Open** —
holders open boxes; **Closed** — no further opens, prizes never won released. The owner makes
each transition once and neither is reversible.

#### Scenario: Each transition happens once
- **GIVEN** the game in Setup with prizes committed and ids excluded
- **WHEN** the owner opens it and later closes it
- **THEN** each transition happens once and a second call to either reverts

### Requirement: RAF-27 — Playable ids and the prize pool
**Kind:** work-item
Two numbers fix the odds, and both freeze when the
game opens (`→ CQ-20`). The **excluded ids** are recorded as ranges by the owner during Setup
(`excludeRange(from, to)`, event `IdsExcluded`); an excluded bear is out of play whoever holds
it, so a team bear that is sold stays out. `PLAYABLE = MAX_BEARS − excluded` is computed at the
transition to Open and is immutable after it. The **prize pool** is the ordered manifest
`(chainId, vault, prizeIndex)` of every prize the vaults have committed (RAF-3, RAF-4), chains
in the fixed order the owner records and, within a vault, ERC-721 prizes in registration order
then baskets in asset-approval order. It is public before the first open and nothing may be
added once the game is Open. A game with no prizes cannot open.

`PLAYABLE` and the prize count are also `PrizeDraw`'s constructor arguments, because it runs on
another chain and cannot read the hub. The excluded ranges are therefore final before `PrizeDraw`
is deployed, and the hub's `GameOpened(playable, prizeCount, manifestHash)` publishes all three so
that anyone can check the two chains were given the same game.

#### Scenario: Opening freezes the odds
- **GIVEN** ranges excluded during Setup and prizes committed
- **WHEN** the owner opens the game
- **THEN** `GameOpened(playable, prizeCount, manifestHash)` publishes `MAX_BEARS − excluded`, the manifest length and its hash
- **AND** `excludeRange` after opening reverts

### Requirement: RAF-28 — Opening a box
**Kind:** work-item
`open(uint256 tokenId)` on `MysteryBox`, by the wallet that is
`ownerOf(tokenId)` at that moment. It reverts unless the game is Open (`GameNotOpen`),
`ownerOf(tokenId) == msg.sender` (`NotBearOwner`), the id is not excluded (`IdExcluded`) and the
id has not been opened (`AlreadyOpened`). Effects: the id is marked spent for good, the next
`openIndex` is assigned, and `BoxOpened(openIndex, tokenId, opener)` is emitted. Opening is free
apart from gas. A spent bear stays freely transferable and its buyer cannot open it again.
`shotsLeft(wallet)` returns the wallet's bears that are playable and unopened — a holder of ten
bears who has opened two sees eight.

#### Scenario: One bear is one shot
- **GIVEN** an open game and a holder of a playable, unopened bear
- **WHEN** the holder calls `open(tokenId)`
- **THEN** `BoxOpened(openIndex, tokenId, opener)` is emitted and `shotsLeft(holder)` falls by one
- **AND** the buyer of that bear cannot open it again, reverting with `AlreadyOpened`

### Requirement: RAF-29 — Resolution, in order
**Kind:** work-item
Each open is resolved on `PrizeDraw` by `resolve(uint64
openIndex, address opener)`, which the worker relays from the `BoxOpened` event. `PrizeDraw`
refuses any `openIndex` but the next unresolved one (`OutOfOrder`), so the worker cannot choose
which open meets which state of the pool; it can only delay one, and a delayed open is visible
as a `BoxOpened` with no `OutcomeRecorded`. `resolve` requests one Chainlink word and emits
`DrawRequested(openIndex, requestId)`. Requests may be in flight at once, and outcomes are
applied strictly in `openIndex` order as the words arrive, so an open waits on the words of the
opens before it and on nothing else.

#### Scenario: Relays are accepted only in order
- **GIVEN** opens 1 and 2 recorded and neither resolved
- **WHEN** the worker calls `resolve(2, opener)`
- **THEN** it reverts with `OutOfOrder`
- **AND** `resolve(1, opener)` requests one Chainlink word and emits `DrawRequested`

### Requirement: RAF-30 — The win rule (normative)
**Kind:** work-item
Let `idsLeft` be the playable ids not yet resolved and
`prizesLeft` the prizes not yet awarded, both starting at RAF-27's values. On the word `w` for
`openIndex i`:

- `won = (w mod idsLeft) < prizesLeft`;
- if `won`, the next unawarded prize of the manifest is assigned to `i`'s opener and `prizesLeft`
  decreases by one;
- `idsLeft` decreases by one either way;
- `OutcomeRecorded(openIndex, opener, won, prizeIndex)` is emitted, `prizeIndex` carrying no
  meaning when `won` is false.

Properties: every holder faces the same odds before opening, `prizesLeft / idsLeft`; exactly the
prize count is awarded once every playable id has been opened and resolved, so the pool can
neither run dry early nor be left over if the game is played out; a wallet's chances are
proportional to the playable bears it holds; and there is no cap on how many prizes one wallet
may win (MINT, CQ-9).

#### Scenario: The win rule applies the word
- **GIVEN** `idsLeft` at 10, `prizesLeft` at 2 and a word w with `w mod 10 == 1`
- **WHEN** the open is resolved
- **THEN** `won` is true, the next manifest prize is assigned, `prizesLeft` reads 1 and `idsLeft` reads 9

### Requirement: RAF-31 — Closing the game
**Kind:** work-item
The owner closes the game once, after which `open` reverts. Prizes
never won — because their ids were never opened — return to unreserved inventory when the worker
posts the close to each vault, and the owner may then withdraw them (RAF-14).
`GameClosed(openCount, prizesAwarded)` on the hub, `PrizesReleased` on each vault. Nothing about
an outcome already recorded can change, and a prize already won stays the winner's until it is
claimed or expires.

#### Scenario: Closing releases what was never won
- **GIVEN** an open game with one committed prize never won
- **WHEN** the owner closes the game and the worker posts the close to the vault
- **THEN** `open` reverts, `GameClosed` and `PrizesReleased` are emitted and the prize is unreserved inventory again

### Requirement: RAF-2 — Addresses
**Kind:** work-item
Each `PrizeVault` is the dedicated deposit address on its chain, separate
from the royalty pot and from the admin. Neither `MysteryBox` nor `PrizeDraw` holds assets.

#### Scenario: Vaults are their own addresses
- **WHEN** the deployed addresses are compared
- **THEN** each vault differs from the royalty pot and the admin, and `MysteryBox` and `PrizeDraw` hold no assets

### Requirement: RAF-3 — Asset approval
**Kind:** work-item
The owner approves each asset on each vault once: `approveAsset(token,
kind, basketSize)` with `kind ∈ {ERC20, ERC721}`; `basketSize` is in base units for ERC-20 (for
$MNTD on Robinhood Chain, 5,000 × 10^decimals) and ignored for ERC-721, where each token is its
own prize. `revokeAsset` stops an asset entering the pool and never touches a committed or won
prize. Unapproved assets never enter the pool. ERC-1155 is not supported.

#### Scenario: Baskets follow the approval
- **GIVEN** an ERC-20 approved with basket size b
- **WHEN** the vault holds 2b + 1 units and commits
- **THEN** two baskets are committed
- **AND** a deposit of an unapproved token never enters the pool

### Requirement: RAF-4 — Intake
**Kind:** work-item
Deposits are plain transfers to a vault. Nothing happens until the worker
registers them: `registerERC721(token, id)` requires `ownerOf(id) == vault` and the id not yet
tracked; `syncERC20(token)` adds `balanceOf(vault) − tracked` to unreserved inventory. Token
transfers alone never change the game's state. Each registration emits `DepositRegistered`.

#### Scenario: Registration, not transfer, changes state
- **GIVEN** an ERC-721 transferred to the vault
- **WHEN** the worker calls `registerERC721(token, id)`
- **THEN** `DepositRegistered` is emitted and the prize is unreserved inventory
- **AND** before registration the game's state is unchanged

### Requirement: RAF-5 — Inventory states
**Kind:** work-item
Unreserved → committed (to the game) → won → claimed; or won →
expired → unreserved; or committed → unreserved when the game closes without the prize being
won. A committed or won prize cannot be withdrawn, swept or moved by anyone but its winner,
paused or not.

#### Scenario: A committed prize cannot leave
- **GIVEN** a committed prize
- **WHEN** the owner calls `sweep` for it
- **THEN** the call reverts
- **AND** once won and expired the prize is unreserved again

### Requirement: RAF-6 — Committing prizes
**Kind:** work-item
During Setup the worker calls `commitToGame()` on each vault that
holds prizes: every unreserved full basket of every approved ERC-20 and every unreserved
registered ERC-721 is committed; ERC-20 remainders below a basket stay unreserved; the vault
emits `PrizesCommitted(prizes[])` with its ordered list. The hub's manifest (RAF-27) is the
concatenation of those lists, and a manifest that differs from the vaults' events is detectable
by anyone. MINT fills the vaults with exactly the prizes the game should carry, then the worker
commits and the owner opens.

#### Scenario: Commit lists every full prize
- **GIVEN** a vault with approved baskets and registered ERC-721s
- **WHEN** the worker calls `commitToGame()`
- **THEN** `PrizesCommitted(prizes[])` lists every full basket and every registered token in order
- **AND** remainders below a basket stay unreserved

### Requirement: RAF-8 — Randomness
**Kind:** work-item
Chainlink VRF v2.5, one request and one word per open, with the
subscription owned and funded by MINT and `PrizeDraw` as its consumer (MINT, CQ-17).
**Calea recommends Base** (coordinator `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634`): MINT
already uses it, a request costs cents rather than the dollars Ethereum charges, and two-second
blocks keep the wait a holder sees down to seconds. Ethereum
(`0xD7f86b4b8Cae7D942340FF628F82735b7a20893a`) is the alternative and is correct but slow and
dear at one request per open. ApeChain has no Chainlink VRF; Robinhood Chain has none and no
usable `prevrandao` — which is why the draw is not on the chain the bears live on. One request
per open is what buys an outcome nobody can predict; the subscription has to carry the whole
collection's worth of requests, so it is funded for `PLAYABLE` of them and topped up on a
balance alarm, not on a schedule (`→ CQ-17`).

#### Scenario: One request, one word, per open
- **WHEN** `resolve` runs
- **THEN** exactly one VRF v2.5 request is made from MINT's subscription with `PrizeDraw` as consumer
- **AND** the outcome uses that request's word alone

### Requirement: RAF-24 — Prize vaults
**Kind:** work-item
One `PrizeVault` code, deployed on every chain that holds prizes.
Lifecycle: approval (RAF-3), intake (RAF-4), `commitToGame()` (RAF-6); `award(prizeIndex,
recipient)` by the worker, once per prize and only for a prize the game recorded as won, which
anyone can check against `PrizeDraw`'s `OutcomeRecorded`; `claim(prizeIndex)` by the recipient
(RAF-11); `expirePrize` (RAF-11); `closeGame()` releasing the uncommitted remainder (RAF-31);
`sweep` (RAF-14).

#### Scenario: An award needs a recorded win
- **GIVEN** a prize the draw recorded as won
- **WHEN** the worker calls `award(prizeIndex, recipient)` once
- **THEN** `PrizeAwarded` is emitted
- **AND** a second `award` for the same prize, or one for a prize not recorded as won, reverts

### Requirement: RAF-25 — Recipient nomination
**Kind:** work-item
A winner claims on the prize's chain from the address that
opened the box on Robinhood Chain. An address that is a contract wallet on 4663 may not exist
elsewhere, so for `nominationWindow` after the outcome (default 24 hours; the owner may set 0) a
winner may call `nominateRecipient(openIndex, recipient)` on `PrizeDraw`; the worker posts the
award only once that window has passed, and the recipient defaults to the opener. The UI warns
contract-wallet holders before they open.

#### Scenario: A winner may nominate within the window
- **GIVEN** a win recorded at time t and a nomination window of 24 hours
- **WHEN** the winner calls `nominateRecipient(openIndex, r)` before t + 24 hours
- **THEN** `recipientOf(openIndex)` reads r
- **AND** `award` before the window has passed reverts

### Requirement: RAF-11 — Claims
**Kind:** work-item
`claim(prizeIndex)` on the vault holding the prize: the caller is the
recorded recipient; the prize is unclaimed; `block.timestamp ≤ awardedAt + claimWindow`, with
`claimWindow` **30 days** (MINT, CQ-10). The prize — an ERC-20 basket or an ERC-721 — is
transferred to the caller. The right is single-use and non-transferable, and it belongs to the
wallet that opened the box whatever it does with its bears afterwards. After the window
`expirePrize` (anyone) returns the prize to unreserved inventory — MINT treats an unclaimed
prize as renounced — and a claimed prize never expires.

#### Scenario: Claim within 30 days or expire
- **GIVEN** a prize awarded to r at time a
- **WHEN** r calls `claim(prizeIndex)` before a + 30 days
- **THEN** the prize is transferred to r and `PrizeClaimed` is emitted
- **AND** after 30 days anyone may call `expirePrize` and the prize returns to inventory

### Requirement: RAF-14 — Roles
**Kind:** work-item
Owner (MINT admin): `approveAsset`, `revokeAsset`, `setWorker`,
`excludeRange`, `openGame`, `closeGame`, `setPaused`, `sweep`. `sweep` moves unapproved tokens
and unreserved inventory out of a vault, with an event, **only while that vault has nothing
committed**: from `commitToGame` until the game closes, nothing leaves the vault except to
winners (MINT, CQ-11), and a won prize stays locked until claimed or expired regardless. Worker
(MINT automation): `registerERC721`, `syncERC20`, `commitToGame`, `resolve`, `award`,
`closeGame` on each vault. Anyone: `open` as a bear's owner, `nominateRecipient` as a winner,
`claim` as a recipient, `expirePrize`, all reads.

#### Scenario: Roles hold
- **WHEN** a non-owner calls `excludeRange`, `openGame` or `sweep`, or a non-worker calls `resolve` or `award`
- **THEN** each reverts
- **AND** `open`, `claim` and `expirePrize` need no role

### Requirement: RAF-15 — Pause
**Kind:** work-item
Pausing the hub blocks `open`; pausing `PrizeDraw` blocks `resolve`, so no new
word is requested while outcomes already paid for are settled; pausing a vault blocks
registration and committing. None of them blocks `claim`, `expirePrize` or `nominateRecipient`.

#### Scenario: Pause never blocks a claim
- **GIVEN** the hub, the draw and a vault each paused
- **WHEN** `open`, `resolve` and `registerERC721` are called
- **THEN** each reverts
- **AND** `claim`, `expirePrize` and `nominateRecipient` still succeed

### Requirement: RAF-16 — Events
**Kind:** work-item
Hub: `IdsExcluded(from, to)`, `GameOpened(playable, prizeCount, manifestHash)`,
`BoxOpened(openIndex, tokenId, opener)`, `GameClosed(openCount, prizesAwarded)`, `WorkerSet`,
`PausedSet`. `PrizeDraw`: `DrawRequested(openIndex, requestId)`, `OutcomeRecorded(openIndex,
opener, won, prizeIndex)`, `RecipientNominated(openIndex, recipient)`, `WorkerSet`, `PausedSet`.
Vault: `AssetApproved`, `AssetRevoked`, `DepositRegistered`, `PrizesCommitted`,
`PrizeAwarded(prizeIndex, recipient)`, `PrizeClaimed`, `PrizeExpired`, `PrizesReleased`,
`Swept`, `WorkerSet`, `PausedSet`.

#### Scenario: Events carry the documented arguments
- **WHEN** the game runs through exclusion, opening, an open, a resolution, an award, a claim and closing
- **THEN** every listed event fires with the documented arguments

### Requirement: RAF-17 — Reads
**Kind:** work-item
Hub: game state, `PLAYABLE`, `MAX_BEARS`, `isExcluded(tokenId)`,
`opened(tokenId)`, `openIndexOf(tokenId)`, `openCount()`, `shotsLeft(wallet)`, the manifest and
its hash. `PrizeDraw`: `idsLeft()`, `prizesLeft()`, `nextToResolve()`, `outcomeOf(openIndex)`,
`recipientOf(openIndex)`, `nominationWindow`, `odds()` returning `(prizesLeft, idsLeft)`. Vault:
unreserved inventory per asset, prize by index (asset, id or amount, state, recipient),
`awardedAt(prizeIndex)`, `claimable(wallet)`, `isApproved(token)`.

#### Scenario: Every read answers
- **WHEN** every listed read is called during an open game
- **THEN** each returns without reverting and `odds()` returns `(prizesLeft, idsLeft)`

### Requirement: RAF-18 — Worker sequence
**Kind:** work-item
Register deposits → commit each vault → owner records the excluded
ids and opens the game → holders open boxes → relay each `BoxOpened` to `PrizeDraw` in order →
words arrive and outcomes are recorded → nomination window → post each award to its vault →
winners claim → after the claim window, expire what is unclaimed → owner closes the game → post
the close to each vault. MINT's UI shows the pool, the live odds, a wallet's shots left, its
outcomes and its claims.

#### Scenario: The sequence runs end to end
- **WHEN** the worker sequence runs on the testnets from registration to posting the close
- **THEN** each step succeeds in the listed order and a relay offered out of turn is refused

### Requirement: RAF-19 — Acceptance cases
**Kind:** work-item
Token baskets group correctly; two NFTs from one collection can go
to two different wallets; a deposit registered after the game opens cannot enter the pool; a
committed prize cannot be withdrawn or swept; an excluded id cannot be opened, before or after
it is sold; an id already opened cannot be opened by its buyer; a holder who sells a bear after
opening it still claims what it won; exactly the prize count is awarded when every playable id
is played; the pool neither empties early nor is left over; a relay out of order is refused; an
award that does not match `OutcomeRecorded` is detectable; a prize on ApeChain is claimed by a
nominated recipient; an unclaimed prize expires and can be withdrawn after the game closes.

#### Scenario: Every case has a test
- **WHEN** the tranche-2 test suite runs
- **THEN** every listed case has a passing deterministic test

## Retired Requirements

- RAF-1 (a single raffle chain) → RAF-24, RAF-26
- RAF-7 (passive ownership snapshot) → RAF-28
- RAF-9 (draw over calldata entries) → RAF-30
- RAF-10 (carry forward between rounds) → RAF-31
- RAF-12 (round cancellation) → RAF-31
- RAF-13 (per-round `minLevel` eligibility) → RAF-27
- RAF-20 (rounds on the hub) → RAF-26
- RAF-21 (entry into a round) → RAF-28
- RAF-22 (one seed per round) → RAF-29
- RAF-23 (the per-round draw) → RAF-30
