# MintABear — handover

Written 2026-09-15, current as of 2026-09-22. Read this first when resuming.

## Where things stand

**The specification lives in `openspec/`** (v2.1, recording the MINT–Calea call of 21 September
2026): `openspec/specs/<family>/spec.md` carries every requirement with its Kind and its
Scenario, `openspec/decisions.md` the `CQ-n` register that belongs to MINT. `docs/SPECIFICATION.md`
and `docs/OPEN-QUESTIONS.md` are the prose views MINT reads: narrative edited in place, the
requirement and register blocks generated between markers by `docs/tools/spec_tools/` (CI fails
when they are stale). MINT has one combined document in `docs/client/`, generated from those two
files by `docs/tools/build_client_doc.py` — never edit the `.pages` by hand. The output name
carries the version line in full, suffix included, so each draft is its own file. The current one
is `MintABear-Specification-v2.1.pages`; `v1.0` and `v2.0` stay beside it as the records MINT
answered and then decided against. **The board (YouTrack MNT) follows `openspec/`** through
`docs/tools/board.sh`; the work loop that picks requirements off it is in `CLAUDE.md`
("Specification and board") and its pick order is `openspec/changes/tranche-1/tasks.md`.
The v2.0 document is 31 pages; to check a build without opening Pages, export it to PDF through
`osascript` and render or count text per page with a short Swift PDFKit script — a table that does
not fit the rest of a page moves whole to the next one in Pages, so a heading left alone on a page
means the table after it is too tall.

The call of 21 September is folded in. Seven of the nine decisions are settled — $MNTD native on
4663, cumulative thresholds, the on-chain whitelist registry, the instant mystery box, the VRF
subscription, the existing-contract review deferred, and MINT building the play page on
getminted.io in TypeScript. Section 10 now carries those as settled and lists eight open items,
O1–O8, each with Calea's recommendation, which is also the default built if it is deferred.
CQ-20 is new: the prize count and the excluded team ids.

**The mystery box is one instant game over the collection**, not a series of rounds (§6).
`MysteryBox` on 4663 checks ownership, spends the id and registers the open; `PrizeDraw` on the
Chainlink chain takes one VRF word per open, in `openIndex` order, and applies a fixed pool drawn
without replacement; a `PrizeVault` on each prize chain pays out. RAF-26 to RAF-31 carry the
game; RAF-10, 12, 13, 20, 21, 22 and 23 are retired with pointers to them.

The code on `main` predates the specification and is the input to tranche 1, not the output.

| | |
|---|---|
| Contracts | 4 on `main`, all compiling; the spec calls for 7: `MintABear`, `WhitelistClaim`, `Activation`, `DirectBurnAdapter`, `MysteryBox`, `PrizeVault`, `PrizeDraw` |
| Tests | 137, all passing; 100% line, branch and function coverage (gate ≥90 / ≥80) |
| CI gates | `fmt --check`, `build --sizes`, `test` — all green |
| Slither | no High or Critical; 2 accepted Mediums (below) |

Submodule pins: `forge-std` `bf647bd` (v1.16.2), `seadrop` `757590f`, `solady` `acd959a`
(v0.1.26). The chain's contract size limit is ~96 KB; every contract clears even Ethereum's
24,576.

## Next session — fold the call's decisions in, then start tranche 1

The call of 21 September is recorded. What is left before tranche 2 can start:

1. **Tranche 1 is unblocked.** Only `decimals` on the deployed $MNTD is still needed, and that
   is a constructor value, not structure (O5). Start it.
2. **Tranche 2 waits on O1 (CQ-20)** — the prize count, the excluded token ids and the closed
   list of prize chains. Those three numbers are the odds and they freeze when the game opens,
   so nothing can be deployed without them.
3. **O2 asks MINT to confirm the four design choices §6 makes** inside the shape MINT set: a
   fresh VRF word per open, a fixed pool drawn without replacement, no per-wallet cap, and
   unwon prizes returning to MINT at close.
4. **The client document** is rebuilt from the two Markdown sources; its name follows the spec's
   version line, suffix included, so each draft is its own file.

What each open item blocks:

| Open item | Blocks |
|---|---|
| O1 prize count, excluded ids, prize chains (CQ-20) | All of tranche 2 — they are `PrizeDraw`'s constructor values |
| O2 confirm the mystery box design (CQ-9) | Tranche 2's shape, if MINT wants it different |
| O3 VRF network and subscription wallet (CQ-17) | `PrizeDraw` deployment; Calea recommends Base |
| O4 addresses (CQ-12, CQ-15) | Mainnet deployment, not development |
| O5 $MNTD `burnFrom` and `decimals` (CQ-2) | `Activation`'s constructor values |
| O6 calendar (CQ-1) | Scheduling; the campaign dates fix when `WhitelistClaim` must be live |
| O7 repository and CI (CQ-14) | Where the packages land at handover |
| O8 whitelist export direction and any owner bulk-add (CQ-18) | One `WhitelistClaim` function, if MINT needs it |

## Sources and precedence

1. `docs/SPECIFICATION.md` — the resolution of everything below; outranks each source once signed.
2. MINT's statement of work, 2026-09-14 (`~/Downloads/MINTaBEAR_SoW.pages`), as amended by
   MINT's written answers to specification v1.0 (September 2026) and the *WL Wager Based Checker*
   brief — scope, deliverables, the calendar anchors, the answers.
3. Meeting notes, 2026-09-15 — ERC-6551 out, mint leeway to 29 Oct, weights as constructor values, artwork immutable.
4. The architecture email of 2026-09-10, then the original spec sheet — only where the above are silent.

Requirements carry IDs (`COL-n`, `WL-n`, `ACT-n`, `RAF-n`, `OPS-n`, `DEL-n`); trees, tests and
client replies cite them.

## Calendar

Three anchors are MINT's: TGE 20 October ($MNTD live on Robinhood Chain), mint 29 October, and
burns, level-up and the first mystery box round all starting 29 October. Every other date is
proposed in §8 of the specification and confirmed under D7. Two decouplings hold whatever moves:
the collection deploys and mints without the hub, the vaults or the adapter, and `Activation`
stays paused until the adapter has been exercised against real $MNTD. The whitelist registry
must be live before the campaign opens (proposed 6 October).

## What is left

### Tranche 1 — `MintABear`, `WhitelistClaim`, `Activation`, `DirectBurnAdapter`, then the internal auditor

The code changes that take `main` to the specification:

1. **Remove ERC-6551** (COL-9): `src/BearAccount.sol`, `ACCOUNT_IMPLEMENTATION`, `accountOf`,
   `deployAccount`, `recordAccounts`, `isBearAccount`, `TransferToBearAccount`, the `LibERC6551`
   import, `test/BearAccount.*`, `test/poc/BurnStrandsAccount.t.sol`.
2. **Remove the renderer** (COL-5): `src/interfaces/IBearRenderer.sol`,
   `src/renderers/PlaceholderRenderer.sol`, `setRenderer`, the `tokenURI` override,
   `test/PlaceholderRenderer.*`, `test/mocks/MockRenderer.sol`. Metadata is stock `baseURI`.
3. **Burn refused** (COL-8): the `BurnDisabled` refusal in `_beforeTokenTransfers` stays, with its
   tests; the dead-address exclusion lives in the reference split script, not in the contract.
4. **Add** `TransferNonceAdvanced(tokenId, nonce)` in the transfer hook and an `exists(tokenId)`
   view (COL-4, COL-12).
5. **`WhitelistClaim`** (WL-3, per D4): EIP-712 voucher `Claim(wallet, allocationIndex, account,
   deadline)`, signer set by the owner, 1,000 spots, two per wallet and per account, campaign
   window, `claimants(offset, limit)` for the export; `msg.sender == wallet` unless D4 picks (A′).
   Needed first: it must be live before the campaign.
6. **Activation** (ACT-1…ACT-14): no `IMNTD`, no `decimals()`; thresholds and weights as base-unit
   / basis-100 constructor arrays; `credit(tokenId, burner, amount, nonce, ref)` behind a
   `crediter` role with `NotCrediter`, `StaleNonce`, `RefAlreadyUsed`; `ref` on `BearActivated`;
   `weightOf`, `weightFor`, `snapshot(ids)`; `AlreadyAtMaxLevel` moves to the adapter.
7. **`DirectBurnAdapter`** (ACT-7, ACT-8): `burn(tokenId, amount)` with `NotOwner`,
   `AlreadyAtMaxLevel`, `Overshoot` (amount above `costToReach(id, 5)` refused), then
   `burnFrom` and `credit` in one transaction, `ref` = adapter burn number,
   `BurnedForBear`. Immutable, no owner. The token's `burnFrom` and `decimals` come from D1.
8. **Validator set at deploy** (COL-7): the deploy script calls `setTransferValidator(V3)`; the
   runbook carries the one-call fallback.
9. Trees and tests rewritten against the requirement IDs; coverage gate held.
10. `CLAUDE.md` rewritten to the new architecture (it still describes the pre-spec code).
11. `script/` — deploy and configuration scripts per OPS-2, Sourcify verification, the
    whitelist export.

### Tranche 2 — after O1

`MysteryBox` on 4663 (RAF-26 to RAF-28, RAF-31), `PrizeDraw` on the Chainlink chain (RAF-8,
RAF-29, RAF-30, RAF-25), and `PrizeVault` on every chain MINT funds (RAF-24 and the RAF-2 to
RAF-6, RAF-11, RAF-14, RAF-15 rules); testnet rehearsal on 46630, Base Sepolia and every prize
chain's testnet; the repository move per O7.

The two things to get right: `PrizeDraw` must refuse an `openIndex` out of turn, so the worker
cannot choose which open meets which state of the pool; and the win rule is
`(word mod idsLeft) < prizesLeft` with both counters decremented on every resolution, which is
what makes "exactly the prize count is awarded" true.

### Integration

Typed client library (`packages/contracts-client` per D9) and the reference royalty-split script
with the dead-address exclusion (DEL-6). Calea's part of the UI is the call surface, review of
contract-touching pull requests, and clarifications; the rest is MINT's.

## For the portal team

The call surface after tranche 1 is WL-3, ACT-14 and COL-12 in the spec; after tranche 2,
RAF-17. Four constraints:

0. **The client library is Calea's deliverable and it is TypeScript** (DEL-6, D9): typed
   against the ABIs, covering every call the app makes, with its own tests and the revert
   reasons a caller has to handle. MINT builds the page on getminted.io against it.
1. **Whitelist claims are voucher-then-transaction.** The backend signs a short-lived voucher
   after the wager API confirms a threshold; the wallet submits it. `spotsLeft()` is the live
   counter; a claim after sell-out reverts with `SoldOut`.
2. **Activation is approve, then one click.** Approve the adapter on $MNTD, then `burn(tokenId,
   amount)` with `amount` from `costToReach(tokenId, targetLevel)`; anything above the level-5
   remainder is refused, so nothing is destroyed for nothing.
3. **Reads are free; poll them.** `levelOf`, `weightOf`, `linkOf`, `costToReach`, `snapshot`,
   `spotsLeft`, `claimsOf`, `triesLeft`.
4. **There is a reset event.** `TransferNonceAdvanced` fires on every non-mint transfer, in the
   same transaction as `Transfer`. Index it as the reset.

## Decisions that should not be relitigated

- **The transfer counter, not a callback.** A callback fails open or bricks transfers; the
  counter can do neither. The client accepted it on 2026-09-15.
- **`solc 0.8.17`.** Forced by SeaDrop's exact pragma. See `CLAUDE.md`.
- **Transfer validator set at deploy; the fallback is one owner call.** MINT wants royalties
  enforced always. Limit Break V3 is on 4663 and OpenSea's SignedZone is an authorizer on its
  default list; OpenSea's off-chain handling on this chain is proven on testnet and with one
  team-bear sale on mainnet before the drop page is published. Never security level 5 or above.
  COL-7, OPS-6.
- **No burn.** MINT's decision; `BurnDisabled` stays. Supply is 4,444 forever.
- **Supply capped in code.** `MAX_BEARS` on the mint path refuses the mint whatever the
  Studio-writable `maxSupply` says, so raising it cannot increase the supply delivered (COL-2).
- **`Activation` never touches the token.** One `crediter` address is the whole route decision;
  MINT's answer makes it the same-chain adapter.
- **A credit requires `ownerOf == burner` and an unchanged counter.** An approved operator
  cannot spend an owner's $MNTD, and a burn never lands on a bear that has changed hands.
- **Instant reveal, one word per open.** MINT's decision of 21 September. Robinhood Chain makes
  no randomness, so the only arrangement in which an instant outcome is unpredictable to
  everyone — MINT included — is a fresh Chainlink word per open. A pre-committed seed was
  offered and refused for that reason. The cost is one VRF request per open.
- **Resolution strictly in `openIndex` order.** It is what stops the worker choosing which open
  meets which state of the pool. Without it the worker could reorder relays and shift individual
  odds. Do not relax it for latency.
- **A fixed pool drawn without replacement.** `(word mod idsLeft) < prizesLeft`. It makes
  "5 prizes among 4,400 bears" literally true and gives every holder the same odds going in; a
  fixed per-open probability would not.
- **Fuzz and invariant harnesses are the internal auditor's.** The developer writes
  deterministic unit tests; the SoW's "fuzzing report" is the auditor's output.
- **Final-state prose in specs and docs.** No "was / now".

## Accepted risks

- **Slither "locked ether"** on `Activation`: Solady marks ownership functions `payable`; only
  the owner could lock their own ETH by attaching value. Accepted.
- **Event ordering in the adapter**: the record is written before `burnFrom`; the hostile paths
  were traced (re-entering still needs each `burnFrom` to succeed; transferring the bear from
  inside `burnFrom` voids the caller's own record). Accepted.
- **The worker relays each open and each award.** It cannot change an outcome — Chainlink
  decides it — and it cannot reorder, because `PrizeDraw` refuses an `openIndex` out of turn. It
  can delay one, which is visible as a `BoxOpened` with no `OutcomeRecorded`. Accepted; the
  alternative is cross-chain messaging, and 4663 has no endpoint.
- **One VRF request per open is a real cost.** At roughly one request per playable id, the
  subscription has to be funded for the whole collection and watched with a balance alarm. On
  Base that is cents per request; on Ethereum it would not be viable. Accepted as the price of
  an instant outcome nobody can foresee (O2, O3).
- **A bridged $MNTD (D1 option a2) strands rather than burns.** Accepted only with MINT's public
  statement; the contract cannot tell the difference.
- **Contract wallets on 4663 may not exist on other prize chains.** The nomination window
  (RAF-25) and a UI warning cover it.

## Verified on-chain facts

Measured against chain 4663 on 2026-09-10 and 2026-09-15; Chainlink and ApeChain facts on
2026-09-18. Do not re-research these.

| | Address / value |
|---|---|
| Robinhood Chain mainnet | chain id **4663**, RPC `https://rpc.mainnet.chain.robinhood.com` |
| Testnet | chain id **46630**, RPC `https://rpc.testnet.chain.robinhood.com` |
| Canonical SeaDrop | `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` |
| Seaport 1.6 | `0x0000000000000068F116a894984e2DB1123eB395` — deployed |
| OpenSea Conduit | `0x1E0049783F008A0085193E00003D00cd54003c71` — **not deployed**; orders use conduitKey 0 |
| ConduitController | `0x00000000F9490004C11Cef243f5400493c00Ad63` — deployed |
| OpenSea SignedZone | `0x000056F7000000EcE9003ca63978907a00FFD100` — deployed; authorizer on validator list 0 |
| Limit Break validator V3 | `0x721C002B0059009a671D00aD1700c9748146cd1B` — deployed; V1/V2 absent |
| ERC-6551 registry | `0x000000006551c19487814612e58FE06813775758` — byte-identical to Ethereum |
| CREATE2 deployer | `0x4e59b44847b379578588920cA78FbF26c0B4956C` — present |
| LayerZero EndpointV2 | absent at its canonical address |
| Chainlink VRF v2.5 | Base `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634`; Base Sepolia `0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE`; Ethereum `0xD7f86b4b8Cae7D942340FF628F82735b7a20893a` (code present); **none on 4663, none on ApeChain** (Chainlink supported-networks page) |
| ApeChain | chain id **33139**, RPC `https://rpc.apechain.com/http`; Curtis testnet 33111 |

- **Contract size limit is ~96 KB**, four times Ethereum's.
- **`block.number` returns the L1 Ethereum height.** Key logic on `block.timestamp`. Block time ~100 ms.
- **The block header's `gasLimit` reads 2^50** — Arbitrum-style; the per-transaction gas limit is what binds, so long loops (the draw) are chunked.
- **No usable randomness on 4663.** `block.prevrandao` is constant; no Chainlink. Randomness lives on Base.
- **`block.blobbasefee` reverts.** The one unsupported opcode.
- **Sequencer-level compliance screening is active.** No part of the system may break when one holder cannot transact.
- **Mainnet Blockscout's API sits behind a bot challenge.** Verify through Sourcify (4663 and 46630).
- **OpenSea supports the chain** and Studio drops run there. Creator earnings are enforced only for validated collections; otherwise the buyer chooses.

## Unknowns to settle by rehearsal

1. Does OpenSea Studio attach to and manage a contract we deployed ourselves, validator set? (testnet)
2. Does OpenSea emit SignedZone-restricted orders for a Limit-Break-validated collection on 4663? (mainnet: one team bear listed and sold before the drop page is published)
3. A whitelist claim end to end: voucher → `claim` → export → Studio allowlist stage → a two-per-wallet allowlist mint. (testnet)
4. A burn through the adapter against $MNTD on 46630 through to a credited level; then against the real token on mainnet between 20 and 28 October. The pause has no exemption, so that rehearsal runs in a window the owner opens and closes again; holders' access opens on 29 October (ACT-11, §8).
5. A full multi-chain game on the testnets: deposit, commit, exclude, open the game, boxes opened, relays in order, words, outcomes, awards, claims and expiry — including one open that wins and one that does not, and a relay offered out of turn and refused.
6. Does Safe's web interface support chain 4663? (D3)

## Open questions with the client

Twenty in `docs/OPEN-QUESTIONS.md`, each with the section it affects, when it is needed, the
answer where one exists, and the default otherwise. After the call of 21 September: ten settled
(CQ-3, 4, 5, 6, 7, 8, 10, 16, 18, 19), six in follow-up (CQ-1, 2, 9, 11, 15, 17) and four open
(CQ-12, 13, 14, 20). They map onto O1–O8 in §10. Nothing now blocks tranche 1 but `decimals`
(O5); tranche 2 waits on CQ-20.

## Related documents

- `openspec/specs/`, `openspec/decisions.md`, `openspec/changes/tranche-1/` — the specification and the tranche's pick order.
- `docs/SPECIFICATION.md`, `docs/OPEN-QUESTIONS.md` (generated views), `docs/client/`, `docs/tools/build_client_doc.py`, `docs/tools/board.sh`.
- `test/<Contract>.tree.md` — one branching tree per contract, including the invariant
  obligations left for the auditor. Rewritten against requirement IDs in tranche 1.
- `test/SeaDropIntegration.t.sol` and its tree — the boundary with OpenSea Studio.
- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire the original build answered.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — the original decision log, item by item.
- `~/.claude/plans/mutable-sparking-candy.md` — the re-specification session: fact base,
  design tree, the SoW digest.
- `~/.claude/plans/in-previous-session-we-ticklish-thacker.md` — the answer intake: MINT's
  answers mapped to questions, the v2.0 design (whitelist registry, mystery box hub, prize
  vaults), and the assumptions made.
