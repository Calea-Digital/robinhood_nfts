# MintABear — handover

Written 2026-09-15, current as of 2026-09-24. Read this first when resuming.

## Where things stand

**The specification lives in `openspec/`** (v2.2: the MINT–Calea call of 21 September 2026,
and the amendments of the tranche-1 review, 23–24 September): `openspec/specs/<family>/spec.md` carries every requirement with its Kind and its
Scenario, `openspec/decisions.md` the `CQ-n` register that belongs to MINT. `docs/SPECIFICATION.md`
and `docs/OPEN-QUESTIONS.md` are the prose views MINT reads: narrative edited in place, the
requirement and register blocks generated between markers by `docs/tools/spec_tools/` (CI fails
when they are stale). MINT has one combined document in `docs/client/`, generated from those two
files by `docs/tools/build_client_doc.py` — never edit the `.pages` by hand. The output name
carries the version line in full, suffix included, so each draft is its own file. The current one
is `MintABear-Specification-v2.1.pages`; `v1.0` and `v2.0` stay beside it as the records MINT
answered and then decided against. The v2.2 document is not built yet: it is built when the
reviewer asks, and until then v2.1 is the last version MINT has. **The board (YouTrack MNT) follows `openspec/`** through
`docs/tools/board.sh`; the work loop that picks requirements off it is in `CLAUDE.md`
("Specification and board") and its pick order is `openspec/changes/tranche-1/tasks.md`. A
The next session starts from `docs/prompts/tranche-1-integrity-and-review.md`: an integrity check of spec, prose, client document, code and board, then the rest of the tranche-1 review.
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

**Tranche 1's code is on branch `tranche-1`**, branched from `main` at `746acbe`, never pushed and
not merged into `main`; `main` still carries the pre-specification code. **The paired review is
under way** (`reports/tranche-1-review-log.md`): COL-1…COL-13 (MNT-7…16, 18, 19), WL-1, WL-3, WL-4,
WL-5 (MNT-20, 22…24) and the non-spec MNT-92…94 are Done, with the Defects the review raised
(MNT-99…112) Done too. In Review and still to be reviewed, in order: ACT-1…ACT-14 (MNT-26…39),
OPS-2, OPS-3, OPS-6 (MNT-62, 63, 66) and MNT-96…98. MNT-113 — the change that made
`Activation` burn $MNTD itself (spec v2.2) — and MNT-114, this handover, are Done. OPS-4, the rehearsal, is still ahead, with Subtask MNT-95 (Sourcify
on 46630). Each Task carries a claim comment, a summary comment with its commits and gates, and
logged time; the human sets Done and merges `tranche-1` into `main`.

| | |
|---|---|
| Contracts | 3 of the 6 the spec calls for: `MintABear`, `WhitelistClaim`, `Activation`; `MysteryBox`, `PrizeVault`, `PrizeDraw` are tranche 2 |
| Scripts | `Deploy.s.sol` (OPS-2), `verify.sh` (OPS-3), `Enforcement.s.sol` (OPS-6), `WhitelistExport.s.sol` (WL-4); `docs/RUNBOOK.md`: ownership handover, whitelist export, transfer enforcement, royalties, Activation |
| Tests | 208, all passing; 100% line, branch and function coverage (gate ≥90 / ≥80); every tranche-1 work-item Scenario has a test except the operational OPS-1, OPS-3 (live), OPS-4, OPS-5 |
| CI gates | `fmt --check`, `build --sizes` (no warnings), `test`, spec lint, generated prose, `verify.sh` dry run and verdict test — all green |
| Slither | no High or Critical; 2 accepted Mediums, both `locked-ether` (below) |

Requirements amended since v2.1, each through an archived OpenSpec change with the reviewer's
go: ACT-5 (after a transfer the weight reads the level-0 weight) and OPS-2 (`WhitelistClaim`
takes MINT's admin as owner) on 2026-09-23; on 2026-09-24, in the tranche-1 review, COL-10
(ownership is never renounced), WL-3 (the voucher's index is the account's allocation; renounce
refused), WL-1 (thresholds make the account eligible), and spec v2.2 — `Activation` burns $MNTD
itself and `DirectBurnAdapter` is gone (ACT-1, 2, 4, 6, 7, 8, 11–14, OPS-1, 2, 4, DEL-8).

Submodule pins: `forge-std` `bf647bd` (v1.16.2), `seadrop` `757590f`, `solady` `acd959a`
(v0.1.26). The chain's contract size limit is ~96 KB; every contract clears even Ethereum's
24,576.

## Next session — integrity check and review, then the rehearsal

1. **Integrity check, then the rest of the review** (`docs/prompts/tranche-1-integrity-and-review.md`).
   The review resumes at #20, MNT-26 / ACT-1, against the `Activation` of MNT-113; then the human
   merges `tranche-1` into `main`. Point recorded for the reviewer in the Task comments:
   `WeightsNotAscending` (MNT-26).
2. **The OPS-4 rehearsal on 46630** (human-led; `tasks.md` 4.4). It needs from MINT the admin and
   signer addresses (CQ-12), the campaign dates (CQ-1) and the testnet $MNTD with its `decimals`
   (CQ-2), written into `script/config/46630.json` from `script/config/example.json`; and from the
   operator a funded deployer key and OpenSea Studio access. It runs the three `Deploy.s.sol`
   entry points with Sourcify verification (closing MNT-95), attaches Studio, completes
   `acceptOwnership`, walks a whitelist claim through `WhitelistExport.s.sol`'s export and compare
   into an allowlist mint, burns through `Activation`, and toggles enforcement once.
3. **The internal auditor** takes the tranche after the rehearsal: the trees' INV-N and Fork-N
   obligations are theirs.
4. **Tranche 2 waits on O1 (CQ-20)** — the prize count, the excluded token ids and the closed list
   of prize chains.

What each open item blocks:

| Open item | Blocks |
|---|---|
| O1 prize count, excluded ids, prize chains (CQ-20) | All of tranche 2 — they are `PrizeDraw`'s constructor values |
| O2 confirm the mystery box design (CQ-9) | Tranche 2's shape, if MINT wants it different |
| O3 VRF network and subscription wallet (CQ-17) | `PrizeDraw` deployment; Calea recommends Base |
| O4 addresses (CQ-12, CQ-15) | The rehearsal's and mainnet's `script/config/<chain>.json`, not code |
| O5 $MNTD `burnFrom`, `decimals` and final address (CQ-2) | `Activation`'s deployment: the token is fixed in its constructor, which reads its `decimals`; the runbook's "Activation" read-back checks the scaled thresholds |
| O6 calendar (CQ-1) | Scheduling; the campaign dates fix when `WhitelistClaim` must be live |
| O7 repository and CI (CQ-14) | Where the packages land at handover |
| O8 whitelist export direction and any owner bulk-add (CQ-18) | One `WhitelistClaim` function, if MINT needs it; none is built |

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
the collection deploys and mints without the hub, the vaults or `Activation`, and `Activation`
stays paused until its burn has been exercised against real $MNTD. The whitelist registry
must be live before the campaign opens (proposed 6 October).

## What is left

### Tranche 1 — `MintABear`, `WhitelistClaim`, `Activation`, then the internal auditor

The code is written and In Review (above). What remains before the internal auditor takes it:

1. **Review and merge** of `tranche-1` into `main` (the human's).
2. **OPS-4 rehearsal on 46630** with MINT's values, closing Subtask MNT-95 and rehearsal items
   1, 3 and 4 below.
3. **Mainnet configs** `script/config/4663.json` once CQ-12, CQ-1 and CQ-2 are answered.
4. **OPS-1 and OPS-5** — the recorded addresses and the handover — at deployment.

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
   after the wager API confirms a threshold; the wallet submits it. The voucher's
   `allocationIndex` is the account's allocation number — 1 once $50 is wagered, 2 once $100 is —
   whichever wallet the holder selects, and the EIP-712 type is exactly
   `Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`. `spotsLeft()` is the live
   counter; a claim after sell-out reverts with `SoldOut`.
2. **Activation is approve, then one click.** Approve `Activation` on $MNTD, then `burn(tokenId,
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
- **`Activation` burns $MNTD itself.** $MNTD is native to Robinhood Chain (CQ-2), so the token is
  a constructor argument and there is no crediter to point elsewhere: no key can record a level
  without a burn. Calea's decision of 24 September (spec v2.2); a different token address means a
  new `Activation`.
- **A burn is recorded only for the bear's current owner.** `burn` reads `ownerOf` and the
  counter in the same call, so an approved operator cannot spend an owner's $MNTD, and a burn
  never lands on a bear that has changed hands.
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

- **The collection's owner can add a minter.** `updateAllowedSeaDrop` is SeaDrop's owner-only
  setting, so the owner — Calea until `acceptOwnership`, then MINT's admin — could allow its own
  address and mint bears outside Studio's stages, without fee or allowlist, up to `MAX_BEARS`.
  Canonical SeaDrop as the only allowed minter (COL-1) is a deployment and ownership property,
  not a constant. Accepted; the mitigation is MINT's admin being a Safe (COL-10) and the
  runbook's handover, which resets the list to canonical SeaDrop straight after acceptance.
- **Slither "locked ether"** on `Activation` and `WhitelistClaim`: Solady marks ownership
  functions `payable`, and anyone can call `requestOwnershipHandover` and
  `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value; neither
  contract withdraws it. The loss is only ever the sender's own. Accepted, and said in each
  contract's NatSpec.
- **The eligibility signer decides who may claim.** The signer, and the owner through
  `setSigner`, can sign vouchers for wallets they control with fresh account hashes, up to all
  1,000 allocations: the register proves a voucher, not the wagering behind it. Accepted; the
  signer is MINT's backend key (WL-2), rotated by `setSigner`, and every claim and every
  `SignerSet` is on-chain.
- **`setWindow` can reopen a closed campaign.** Claims made after the export would be in the
  registry and not in Studio's allowlist. Accepted; the runbook runs the export and `compare`
  after the last `WindowSet`, and `compare` fails on any difference.
- **`Activation` calls $MNTD, which is outside this codebase.** The record is written before
  `burnFrom`, and `burn` is `nonReentrant`: a token that calls back cannot burn again, and any
  revert undoes the record. What remains trusted is that $MNTD's `burnFrom` reverts on failure
  rather than returning without burning (CQ-2, Fork-3). Accepted; the hostile-token tests pin the
  refusal.
- **Reading owners over an untransferred mint batch is expensive.** ERC721A records one owner
  per mint batch, and `ownerOf` walks back to the batch's start, so `snapshot` (which reads the
  owner of every id) costs roughly the square of an untransferred batch's length. Measured on the
  unit fixture: `snapshot(1..4444)` 56.2M gas when wallets mint two each; with all 4,444 in one
  batch, 50 ids at its end cost 55.9M and the full range runs out of gas. `weightOf` does not walk
  (2,451 gas). A holder cannot lengthen a batch; the mint pattern decides it. Accepted; the
  mitigations are the split script's (DEL-6: owners from indexed `Transfer` events at the closing
  block and weights from `weightOf`, or `snapshot` paged by a gas budget) and team and treasury
  mints of at most about 200 bears per transaction (ACT-10).
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
3. A whitelist claim end to end: voucher → `claim` → export → Studio allowlist stage → allowlist mint. It passes when `WhitelistExport.s.sol compare` passes against the root Studio set, a two-allocation wallet mints two, and a one-allocation wallet is refused its second — which shows Studio builds its tree like `script/lib/AllowListTree.sol` and keeps each wallet's own limit. (testnet)
4. A burn through `Activation` against $MNTD on 46630 through to a recorded level; then against the real token on mainnet between 20 and 28 October. The pause has no exemption, so that rehearsal runs in a window the owner opens and closes again; holders' access opens on 29 October (ACT-11, §8).
5. A full multi-chain game on the testnets: deposit, commit, exclude, open the game, boxes opened, relays in order, words, outcomes, awards, claims and expiry — including one open that wins and one that does not, and a relay offered out of turn and refused.
6. Does Safe's web interface support chain 4663? (D3)

## Open questions with the client

Twenty in `docs/OPEN-QUESTIONS.md`, each with the section it affects, when it is needed, the
answer where one exists, and the default otherwise. After the call of 21 September: ten settled
(CQ-3, 4, 5, 6, 7, 8, 10, 16, 18, 19), six in follow-up (CQ-1, 2, 9, 11, 15, 17) and four open
(CQ-12, 13, 14, 20). They map onto O1–O8 in §10. Tranche 1's code is written; its rehearsal and
deployment wait on MINT's values (O4, O5, O6); tranche 2 waits on CQ-20.

## Related documents

- `openspec/specs/`, `openspec/decisions.md`, `openspec/changes/tranche-1/` — the specification and the tranche's pick order.
- `docs/SPECIFICATION.md`, `docs/OPEN-QUESTIONS.md` (generated views), `docs/client/`, `docs/tools/build_client_doc.py`, `docs/tools/board.sh`.
- `test/<Suite>.tree.md` — one branching tree per test suite, leaves citing requirement IDs, with
  the auditor's INV-N and Fork-N obligations numbered once across all trees.
- `docs/RUNBOOK.md` — operating steps: the ownership handover (COL-10), the whitelist export (WL-4), transfer enforcement (OPS-6), royalties (COL-6) and `Activation` — the read-back, the control check, the pause around rehearsals and switch-on, and the mint batch size (OPS-2, ACT-11).
- `test/SeaDropIntegration.t.sol` and its tree — the boundary with OpenSea Studio.
- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire the original build answered.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — the original decision log, item by item.
- `~/.claude/plans/mutable-sparking-candy.md` — the re-specification session: fact base,
  design tree, the SoW digest.
- `~/.claude/plans/in-previous-session-we-ticklish-thacker.md` — the answer intake: MINT's
  answers mapped to questions, the v2.0 design (whitelist registry, mystery box hub, prize
  vaults), and the assumptions made.
