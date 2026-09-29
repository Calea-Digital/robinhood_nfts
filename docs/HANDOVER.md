# MintABear — handover

Written 2026-09-15, current as of 2026-09-29. Read this first when resuming.

## Where things stand

**The specification lives in `openspec/`** (v2.6: the MINT–Calea calls of 21 and
28 September 2026, MINT's replies of 28 and 29 September, the tranche-1 review of 23–24 September,
and the readability pass of 29 September):
- `openspec/specs/<family>/spec.md` carries every requirement with its Kind and its Scenario.
- `openspec/decisions.md` is the `CQ-n` register that belongs to MINT.
- `docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md` are the prose views MINT reads. The
  narrative is edited in place; the requirement and register blocks are generated between markers
  by `docs/tools/spec_tools/`, and CI fails when they are stale.

MINT has one combined document in `docs/client/`, generated from those two files by
`docs/tools/build_client_doc.py`. Never edit the `.pages` by hand. The output name carries the
version line in full, suffix included, so each draft is its own file.
- **The current one** is `MintABear-Specification-v2.6.pages` (built 29 September 2026, 25 pages,
  down from v2.5's 48). It is written for MINT's decision-makers: §10 first, with what is settled
  and the open items O1–O7 soonest first, then where the work stands and the changes since v2.5.
  Each requirement is a plain statement; its `*Technical note.*` stays in `openspec/` and on the
  board. Settled questions get no callout, an open one gets one yellow line pointing to §10, and
  the retired requirements are an appendix. `MintABear-Whitelist-Options.pages` is the brief on the two registry
  options MINT answered with the off-chain register; its source is
  `docs/tools/build_whitelist_options.py`.
- **`MintABear-Operational-v2.6.pages`** is its extract for a call: everything before §1 Scope,
  built with `build_client_doc.py --operational`.
- **`v1.0` to `v2.5`** stay beside them as the records MINT answered, decided against and last
  received.

**The board (YouTrack MNT) follows `openspec/`** through `docs/tools/board.sh`. The work loop that
picks requirements off it is in `CLAUDE.md` ("Specification and board"), and its pick order is
`openspec/changes/tranche-1/tasks.md`.

To check a client-document build without opening Pages, export it to PDF through `osascript` and
render or count text per page with a short Swift PDFKit script. A table that does not fit the rest
of a page moves whole to the next one, so a heading left alone on a page means the table after it
is too tall; a one-cell callout taller than the space left is clipped at the page edge instead —
v2.1's CQ-18 and CQ-9 callouts are cut off that way — so read each callout's last line too.

Both calls are folded in.

**The call of 28 September** answered most of v2.3's O1–O9:
- **Mystery box:** cycles the owner schedules; 222 excluded ids (which ones, to follow); the draw
  on Arbitrum One; prizes in MINT's own wallet; no vaults.
- **Status links** are off-chain, so ACT-9 is retired.
- **Addresses:** the admin `0x1530…6141` and the royalty receiver `0xf7E7…0e63`.
- **$MNTD's interface** is known from the reference token.
- **The repository recommendation** is accepted.
- **The whitelist** is off-chain, in MINT's backend: no contract (MINT's reply, same day).

MINT first asked for a whitelist its admin imports from a CSV. Calea built that as a variant,
WL-7 `WhitelistImport`, beside the voucher registry WL-3 `WhitelistClaim`, and sent a brief on
both (`docs/client/MintABear-Whitelist-Options.pages`). MINT answered with an off-chain register,
which Calea accepted with five conditions (WL-8, CQ-18 resolved): a free signature for pasted
wallets, one merged row per wallet, a counter that cannot over-claim, a freeze 48 hours before the
whitelist stage, and the whitelist stage first. Both contracts stay in the repository, unused.
Spec v2.5 records it. In v2.6, §10 lists seven open items, O1–O7, soonest first, each with what it holds up and Calea's fallback; `build_client_doc.py` refuses to build when they disagree with the register.

**29 September** (spec v2.6):
- **CQ-14 resolved:** the repository is `https://github.com/mintdotio/NFT`, and Calea has access.
- **CQ-13 withdrawn, DEL-7 retired:** no existing MINT contract is reviewed. Tranche 1's internal
  audit runs on 30 September and 1 October.
- **CQ-18, other channels:** getminted.io is a general whitelist checker. Spots from
  collaborations and giveaways come on top of the 1,000 wagering spots, which keep two per wallet
  and two per account.
- **CQ-24 resolved:** the 1,000 wagering spots are guaranteed, and the other channels are capped
  at 3,222. The CSV totals at most 4,222, and with the team's 222 minted first every row has a
  bear. `compare` is to refuse a CSV over 4,222 (`tasks.md` 2.6).
Two decisions are new: CQ-22 (who sends a payout, push or request) and CQ-23 (who operates the
worker).

**The mystery box runs in cycles** (§6):
- `MysteryBox` on 4663 records the excluded ids once, then each cycle's window, prize count and
  prize-list hash. It checks ownership and spends a bear for the cycle.
- `PrizeDraw` on Arbitrum One carries the same cycle terms, takes one VRF word per open in
  `openIndex` order, applies a fixed pool drawn without replacement per cycle, and records each
  payout (`recordPayout` → `PrizePaid`).
- Prizes sit in MINT's prize wallet `0xf6c0…e3e3` on Robinhood Chain, Ethereum and possibly
  ApeChain, and are paid by transfer. No contract goes on a prize chain.

RAF-32 (cycles), RAF-27 to RAF-30, RAF-8, RAF-33 (custody and the payout record) and RAF-34
(pause) carry it. RAF-2 to 6, 11, 15 and 24 to 26 and 31 are retired.

**Tranche 1's code** is on `main` up to `8fc37ac` (merged, never pushed). `tranche-1` carries
WL-7 and specs v2.4, v2.5 and v2.6 on top. **The paired review of every tranche-1 Task is complete**
(`reports/tranche-1-review-log.md`):
- COL-1…13, WL-1, 3, 4, 5, ACT-1…14, OPS-2, 3, 6 and the non-spec MNT-92…94, 96…98 are Done;
- with them, the Defects the review raised (MNT-99…112, 115…118, 120…130);
- and the architecture change MNT-113 (`Activation` burns $MNTD itself, spec v2.2).

An integrity check of spec, prose, client document, code and board ran first (the log's
"Integrity check"), and three tranche-end `solidity-auditor` passes after (the log's
"Tranche-end pass"); `reports/tranche-1-review.md` summarises it all.

**WL-7** (MNT-134, merge `451554c`, In Review) was built on 28 September by the developer, with
tests and self-review (`reports/wl-7-diff-review.md`). It is not deployed: the whitelist went off-chain the same day (WL-8). With it:
242 contract tests and 133 client tests; 200 rows cost 14.0M gas to add.

Still ahead:
- **OPS-4**, the rehearsal, with Subtask MNT-95 (Sourcify on 46630).
- **ACT-9's removal** from the code: a Task under ACT-12 (spec v2.4).

Each Task carries a claim comment, a summary with its commits and gates, a `Reviewed — Done`
comment and logged time. The human merges `tranche-1` into `main`.

| | |
|---|---|
| Contracts | `MintABear`, `Activation`; tranche 2 is `MysteryBox` (4663) and `PrizeDraw` (Arbitrum One). `WhitelistClaim` and `WhitelistImport` are built but not deployed (the whitelist is off-chain) |
| Scripts | `Deploy.s.sol` (OPS-2), `verify.sh` (OPS-3), `Enforcement.s.sol` (OPS-6), `WhitelistExport.s.sol` (WL-4); `docs/RUNBOOK.md`: ownership handover, whitelist export and import, transfer enforcement, royalties, Activation |
| Tests | 242 contract tests and 133 client tests, all passing; 100% line, branch and function coverage (gate ≥90 / ≥80); every tranche-1 work-item Scenario has a test except the operational OPS-1, OPS-3 (live), OPS-4, OPS-5 |
| CI gates | `fmt --check`, `build --sizes` (no warnings), `test`, spec lint, generated prose, `verify.sh` dry run and verdict test — all green |
| Slither | no High or Critical; 3 accepted Mediums, all `locked-ether` (below) |

Requirements amended since v2.1, each through an archived OpenSpec change:
- **23 September:** ACT-5 (after a transfer the weight reads the level-0 weight) and OPS-2
  (`WhitelistClaim` takes MINT's admin as owner).
- **24 September, in the tranche-1 review:**
  - COL-10 (ownership is never renounced);
  - WL-3 (the voucher's index is the account's allocation; renounce refused);
  - WL-1 (thresholds make the account eligible);
  - spec v2.2: `Activation` burns $MNTD itself (ACT-1…14, OPS-1, 2, 4, DEL-8).
- **28 September:**
  - WL-7 (the owner-imported registry);
  - spec v2.5, MINT's reply: the whitelist off-chain (WL-8 added; WL-3, WL-6, WL-7 retired;
    WL-1, 2, 4, 5, COL-11, OPS-1, 2, 4, 5, DEL-6, 8, 9, 10 modified);
  - spec v2.4, the call of that day: RAF-32 to RAF-34 added, RAF-2…6, 11, 15, 24…26, 31 retired,
    RAF-8, 14, 16…19, 27…30 modified; ACT-9 and ACT-11 retired, ACT-15 added, ACT-5, 12, 13, 14
    modified; WL-2…5, COL-3, 6, 8, OPS-1…5, 7 and DEL-6, 8, 9, 10, 12 modified.
- **29 September:** spec v2.6, the readability pass and MINT's replies of that day: every active
  requirement restated as a plain statement plus a `*Technical note.*` (Scenarios unchanged),
  COL-7 renamed "Enforced royalties", DEL-7 retired, and the new Purpose line of every family
  (`openspec/changes/archive/2026-09-29-client-readability-v2-6/`).

Submodule pins: `forge-std` `bf647bd` (v1.16.2), `seadrop` `757590f`, `solady` `acd959a`
(v0.1.26). The chain's contract size limit is ~96 KB; every contract clears even Ethereum's
24,576.

## Next session — the whitelist check, ACT-9, then the rehearsal

1. **The whitelist root check over a CSV** (`tasks.md` 2.6, WL-4, Defect MNT-141). `WhitelistExport.s.sol`'s
   `compare` reads a registry today; it has to read MINT's final CSV file. Add tests and the
   tree. It is needed before the whitelist stage: the freeze is 27 October and the stage opens
   29 October. With it, `tasks.md` 6.2 (Defect MNT-143): the client library's `whitelist.allowList` and
   `mint.remainingWhitelistMints` from MINT's CSV rather than a registry.
2. **ACT-9 out of the code** (`tasks.md` 3.15, Defect MNT-142; then 3.16, ACT-15, MNT-135): remove `linkBear`, `unlinkBear`, `linkOf`,
   `BearLinked`, `BearUnlinked`, the ACT-12 interface pin's entries, the tests, trees and the
   client's link module. Rename the ACT-11 references to ACT-15.
3. **The OPS-4 rehearsal on 46630** (human-led; `tasks.md` 4.4). It needs:
   - from MINT: the testnet $MNTD's address (CQ-2) and the campaign dates (CQ-1), written into
     `script/config/46630.json` from `script/config/example.json`;
   - from the operator: a funded deployer key and OpenSea Studio access.

   It then runs, in order:
   - the `Deploy.s.sol` entry points, with Sourcify verification (closing MNT-95);
   - Studio attached, and `acceptOwnership` completed;
   - `Activation` read back, and the admin proving control (runbook, "Activation");
   - a CSV loaded into Studio's whitelist stage, `compare` passing against it, and an allowlist
     mint;
   - a burn through `Activation`;
   - enforcement toggled once.
4. **The internal auditor** takes `MintABear` and `Activation` on 30 September and 1 October,
   ahead of the rehearsal. The trees' INV-N and Fork-N obligations are theirs. The whitelist has no contract.
5. **Tranche 2 waits on the 222 excluded ids** (CQ-20, O2). MINT mints the team bears from the
   owner wallet; if that is the first mint, they are ids 1–222. How the owner mints is still to
   confirm: Calea recommends a private team stage in Studio. It also needs CQ-22 and CQ-23 before
   `PrizeDraw` is deployed.

**Board clean-up for the human** (the 20 problems `board.sh`'s read-back reports, all in
human-owned fields):
- **Cancel the Tasks for retired requirements:** the 13 RAF and ACT ones (MNT-34, 36, 40, 45–50,
  52–54, 56), plus MNT-22 (WL-3) and MNT-134 (WL-7). MNT-134 needs Canceled or Done. Each carries
  a comment naming its replacement.
- **Four Done items now point at requirements that are no longer work items,** because WL-1 and
  WL-5 became informative: MNT-20, MNT-24, MNT-109 and MNT-110.
- **CQ-1 is flagged** as still open while everything it blocks is Done.

What each open item blocks:

| Open item | Blocks |
|---|---|
| O1 admin for every contract (CQ-12), by 2 Oct | Mainnet configs; the accepted risk on the minter list |
| O2 the 222 excluded ids (CQ-20), by 5 Oct | The first cycle; `PrizeDraw`'s `PLAYABLE` |
| O3 prize delivery (CQ-22), by 12 Oct | How payouts are sent and whether a request window exists; `recordPayout` is built either way |
| O4 VRF subscription holder (CQ-17), by 12 Oct | `PrizeDraw`'s deployment (subscription id); DEL-10 if Calea holds it |
| O5 worker operator (CQ-23), by 12 Oct | The worker's address; OPS-5's handover; DEL-10 |
| O6 testnet and mainnet $MNTD addresses (CQ-2), mainnet by 20 Oct | `Activation`'s deployment and the rehearsal |
| O7 dates (CQ-1), by 29 Oct | The whitelist freeze (48 h before the stage); scheduling |

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

MINT's fixed dates:
- the whitelist frozen by 27 October, 48 hours before the whitelist stage;
- TGE on 20 October ($MNTD live on Robinhood Chain);
- the mint on 29 October;
- burns and level-up from 29 October.

The mystery box's cycles are the owner's to schedule after that. Every other date is proposed in
§8 and confirmed under CQ-1.

Two decouplings hold whatever moves:
- the collection deploys and mints without the mystery box or `Activation`;
- `Activation` stays paused until its burn has been exercised against real $MNTD.

The whitelist is frozen at least 48 hours before the whitelist stage, so the Studio upload and the
root check fit.

## What is left

### Tranche 1 — `MintABear`, `Activation`, then the internal auditor

The code is written and reviewed (above). What remains before the internal auditor takes it:

1. **The merge** of `tranche-1` into `main` (the human's).
2. **OPS-4 rehearsal on 46630** with MINT's values, closing Subtask MNT-95 and rehearsal items
   1, 3 and 4 below.
3. **Mainnet configs** `script/config/4663.json` once CQ-12, CQ-1 and CQ-2 are answered.
4. **OPS-1 and OPS-5** — the recorded addresses and the handover — at deployment.

### Tranche 2 — after the excluded ids

- **`MysteryBox` on 4663:** RAF-32, RAF-27, RAF-28, RAF-34.
- **`PrizeDraw` on Arbitrum One:** RAF-8, RAF-29, RAF-30, RAF-33.
- **Both:** RAF-14, RAF-16 to RAF-19.
- Testnet rehearsal on 46630, Arbitrum Sepolia and Sepolia, two cycles included.
- The admin-page and worker calls in the client library (DEL-6).

The things to get right:
- **`PrizeDraw` must refuse an `openIndex` out of turn**, so the worker cannot choose which open
  meets which state of the pool.
- **The win rule** is `(word mod idsLeft) < prizesLeft` per cycle, with both counters
  decremented on every resolution.
- **Each cycle's terms are fixed from its `start`**, and match across the two chains
  (`CycleScheduled` on both).
- **A bear is spent per cycle**, not for good.

### Integration

DEL-6 is built (MNT-69; usability pass MNT-131): `packages/contracts-client`, the typed TypeScript client
over the tranche-1 ABIs (viem 2, tested against anvil), and the reference royalty split with the
dead-address exclusion (`bin/split.ts`). Its `README.md` is the portal team's reference: a quick
start through the `createMintABearClient` facade, the error codes with the message each shows a
holder, the voucher backend's rules, events and indexing, and the split. `examples/` holds one
runnable file per flow (mint, whitelist, burn, link and transfer, errors, indexing and split).
It moves unchanged into MINT's repository, `github.com/mintdotio/NFT` (CQ-14). The mystery
box's calls and MINT's admin-page calls (exclusions, cycle scheduling, pauses) join it in
tranche 2. Its whitelist claim and import modules are not delivered. Calea's part of the UI is the call
surface, review of contract-touching pull requests, and clarifications; the rest is MINT's.

## For the portal team

The call surface after tranche 1 is WL-4 (mint proofs from the CSV), ACT-14 and COL-12 in the spec; after tranche 2,
RAF-17. Four constraints:

0. **The client library is Calea's deliverable and it is TypeScript** (DEL-6, D9). It is typed
   against the ABIs, covers every call the app makes, and carries its own tests and the revert
   reasons a caller has to handle. MINT builds the page on getminted.io against it. It lives in
   `packages/contracts-client`, and its `README.md` is the reference for everything below.
1. **The whitelist is MINT's backend** (WL-8). The mint page builds each wallet's allowlist proof
   from MINT's final CSV with `buildAllowList`; nothing on-chain is read for eligibility.
2. **Activation is approve, then one click.** Approve `Activation` on $MNTD, then call
   `burn(tokenId, amount)` with `amount` from `costToReach(tokenId, targetLevel)`. Anything above
   the level-5 remainder is refused, so nothing is destroyed for nothing. Status links are MINT's,
   kept against the Privy account; `levelOf` is what Status reads.
3. **Reads are free; poll them.** `levelOf`, `weightOf`, `costToReach`, `snapshot`; after tranche 2, `shotsLeft`, `odds` and `outcomeOf`.
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
- **Cycles set by the owner, one shot per bear per cycle.** MINT's decision of 28 September:
  the owner schedules each cycle's window and prizes, and every bear gets a shot again in the
  next cycle. Exclusions are fixed for good before the first cycle.
- **Instant reveal, one word per open.** MINT's decision of 21 September, confirmed on the
  28th. Robinhood Chain makes
  no randomness, so the only arrangement in which an instant outcome is unpredictable to
  everyone — MINT included — is a fresh Chainlink word per open. A pre-committed seed was
  offered and refused for that reason. The cost is one VRF request per open.
- **Resolution strictly in `openIndex` order.** It is what stops the worker choosing which open
  meets which state of the pool. Without it the worker could reorder relays and shift individual
  odds. Do not relax it for latency.
- **A fixed pool drawn without replacement, per cycle.** `(word mod idsLeft) < prizesLeft`. It
  gives every holder the same odds going in. A cycle that ends with bears unopened awards fewer
  prizes, and the rest roll forward (MINT's option (a), 28 September).
- **No vaults.** Prizes are held and paid by MINT's prize wallet; `PrizeDraw` records the payout
  (MINT, 28 September).
- **Fuzz and invariant harnesses are the internal auditor's.** The developer writes
  deterministic unit tests; the SoW's "fuzzing report" is the auditor's output.
- **Final-state prose in specs and docs.** No "was / now".

## Accepted risks

- **The collection's owner can add a minter.** `updateAllowedSeaDrop` is SeaDrop's owner-only
  setting, so the owner — Calea until `acceptOwnership`, then MINT's admin — could allow its own
  address and mint bears outside Studio's stages, without fee or allowlist, up to `MAX_BEARS`.
  Canonical SeaDrop as the only allowed minter (COL-1) is a deployment and ownership property,
  not a constant. MINT's admin is one EOA, `0x1530…6141` (CQ-12), not a Safe, so the mitigation
  is that key alone and the runbook's handover, which resets the list to canonical SeaDrop
  straight after acceptance.
- **One EOA owns every contract** (assumed, CQ-12). A compromise of `0x1530…6141` controls the
  collection's settings, the pause of `Activation`, and
  the mystery box's exclusions and cycles. It cannot move a holder's bear, record a level
  without a burn, or change an outcome.
- **The whitelist is MINT's word** (WL-8). The register, its counter and its rules are in MINT's
  backend, and nothing public shows how the list was made. The one check is that Studio's root is
  exactly MINT's final CSV (WL-4). MINT's decision, 28 September.
- **Slither "locked ether"** on `Activation` (and on the undeployed `WhitelistClaim` and `WhitelistImport`): Solady marks ownership
  functions `payable`, and anyone can call `requestOwnershipHandover` and
  `cancelOwnershipHandover`, so anyone could lock their own ETH by attaching value; neither
  contract withdraws it. The loss is only ever the sender's own. Accepted, and said in each
  contract's NatSpec.
- **`Activation` calls $MNTD, which is outside this codebase.** The record is written before
  `burnFrom`, and `burn` is `nonReentrant`: a token that calls back cannot burn again, and any
  revert undoes the record. The reference token is OpenZeppelin 5.5 `ERC20Burnable`, which reverts
  on failure (CQ-2); Fork-3 confirms the deployed one.
- **Reading owners over an untransferred mint batch is expensive.** ERC721A records one owner
  per mint batch, and `ownerOf` walks back to the batch's start, so `snapshot` (which reads the
  owner of every id) costs roughly the square of an untransferred batch's length. Measured on the
  unit fixture: `snapshot(1..4444)` 56.2M gas when wallets mint two each; with all 4,444 in one
  batch, 50 ids at its end cost 55.9M and the full range runs out of gas. `weightOf` does not walk
  (2,451 gas). A holder cannot lengthen a batch; the mint pattern decides it. Accepted; the
  mitigations are the split script's (DEL-6: owners from indexed `Transfer` events at the closing
  block and weights from `weightOf`, or `snapshot` paged by a gas budget) and team and treasury
  mints of at most about 200 bears per transaction (ACT-10).
- **Every holder pre-approves OpenSea's conduit.** SeaDrop's base (`ERC721AConduitPreapproved`)
  answers `isApprovedForAll(anyHolder, 0x1E0049783F008A0085193E00003D00cd54003c71)` with true, and
  no holder can revoke it. The conduit is not deployed on 4663 (verified read-only, 2026-09-24),
  and only OpenSea's conduit creator can deploy it at that address; if it ever exists, its owner
  could move any bear — each move still advancing the counter. Accepted as trust in OpenSea, like
  Studio itself; Fork-2 and the rehearsal check that the address still has no code, or who owns it
  and what the validator's list allows it.
- **A sale arranged outside a marketplace pays no creator earnings.** At level 0 the holder's own
  transfers pass, so a direct or escrow-mediated sale settles without royalties (COL-7). Inherent
  to every level that lets holders move their bears; the level is settled.
- **Prizes are in MINT's wallet, not in a contract.** Nothing on-chain forces a payout or keeps a
  listed prize in the wallet; a cycle's prize list is committed by hash only. What is checkable is
  the record: every win is an `OutcomeRecorded`, and every payout a `PrizePaid`. A win without a
  `PrizePaid` is visible to anyone. MINT's decision (28 September).
- **The worker relays each open and records each payout.** It cannot change an outcome, because
  Chainlink decides it, and it cannot reorder, because `PrizeDraw` refuses an `openIndex` out of
  turn. It can delay one, which is visible as a `BoxOpened` with no `OutcomeRecorded`. Accepted;
  the alternative is cross-chain messaging, and 4663 has no endpoint. If Calea operates it
  (CQ-23), it is the one role Calea keeps.
- **One VRF request per open is a real cost.** At up to one request per playable bear per cycle,
  the subscription is funded for a cycle's worth and watched with a balance alarm. On Arbitrum a
  request costs the network fee plus Chainlink's premium. Accepted as the price of an instant
  outcome nobody can foresee.
- **A holder whose address cannot receive on a prize chain** (a contract wallet on 4663) is MINT's
  to settle by hand; there is no on-chain nomination. The UI warns before the open.

## Verified on-chain facts

Measured against chain 4663 on 2026-09-10 and 2026-09-15; Chainlink and ApeChain facts on
2026-09-18; Arbitrum, MINT's addresses and the reference $MNTD on 2026-09-28. Do not re-research
these.

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
| Chainlink VRF v2.5 | Ethereum `0xD7f86b4b8Cae7D942340FF628F82735b7a20893a` (code present); Base `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634` (not used); **none on 4663, none on ApeChain** (Chainlink supported-networks page) |
| ApeChain | chain id **33139**, RPC `https://rpc.apechain.com/http`; Curtis testnet 33111 |
| Chainlink VRF v2.5, Arbitrum | Arbitrum One (42161) `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`, LINK `0xf97f4df75117a78c1A5a0DBb814Af92458539FB4`; Arbitrum Sepolia (421614) `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`; both answer `getActiveSubscriptionIds` with 256-bit ids and `MAX_NUM_WORDS` 500 |
| MINT's admin | `0x153052B43c8fD4ec01f14D1Edd8660778daa6141` — EOA; transactions on 4663 and Ethereum |
| Royalty receiver | `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63` — EOA, unused |
| Prize wallet | `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3` — EOA; active on 4663 and Ethereum, nothing on Arbitrum or ApeChain |
| Reference $MNTD | Base Sepolia `0xa21273093af1b3b880b73afd54514bb3d6269968`: OpenZeppelin 5.5 `ERC20 + ERC20Burnable + ERC20Permit`, 18 decimals, 1,000,000,000 minted once, no owner, no proxy; solc 0.8.28, `cancun` |

- **Contract size limit is ~96 KB**, four times Ethereum's.
- **`block.number` returns the L1 Ethereum height.** Key logic on `block.timestamp`. Block time ~100 ms.
- **The block header's `gasLimit` reads 2^50** — Arbitrum-style; the per-transaction gas limit is what binds, so long loops (the draw) are chunked.
- **No usable randomness on 4663.** `block.prevrandao` is constant; no Chainlink. Randomness lives on Arbitrum One.
- **`block.blobbasefee` reverts.** The one unsupported opcode.
- **Sequencer-level compliance screening is active.** No part of the system may break when one holder cannot transact.
- **Mainnet Blockscout's API sits behind a bot challenge.** Verify through Sourcify (4663 and 46630).
- **OpenSea supports the chain** and Studio drops run there. Creator earnings are enforced only for validated collections; otherwise the buyer chooses.

## Unknowns to settle by rehearsal

1. Does OpenSea Studio attach to and manage a contract we deployed ourselves, validator set? (testnet)
2. Does OpenSea emit SignedZone-restricted orders for a Limit-Break-validated collection on 4663? (mainnet: one team bear listed and sold before the drop page is published)
3. The whitelist end to end: a CSV → Studio allowlist stage → allowlist mint. It passes when `WhitelistExport.s.sol compare` over the CSV passes against the root Studio set, a two-allocation wallet mints two, and a one-allocation wallet is refused its second — which shows Studio builds its tree like `script/lib/AllowListTree.sol` and keeps each wallet's own limit. (testnet)
4. A burn through `Activation` against $MNTD on 46630 through to a recorded level; then against the real token on mainnet between 20 and 28 October. The pause has no exemption, so that rehearsal runs in a window the owner opens and closes again; holders' access opens on 29 October (ACT-11, §8).
5. Two mystery-box cycles on the testnets (46630 and Arbitrum Sepolia): exclusion, scheduling on both chains, boxes opened, relays in order, words and outcomes — one open that wins and one that does not, a relay offered out of turn and refused — a win paid from a test prize wallet and recorded with `recordPayout`, and a bear opened again in the second cycle.
6. Moot while MINT's admin is an EOA: does Safe's web interface support chain 4663?

## Open questions with the client

Twenty-four are in `docs/OPEN-QUESTIONS.md`, each with the section it affects, when it is
needed, the answer where one exists, and the default otherwise:
- **resolved or closed (17):** CQ-3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 18, 19, 21, 24;
- **in follow-up (5):** CQ-1, 2, 12, 17, 20;
- **open (2):** CQ-22, 23.

They map onto O1–O7 in §10. Tranche 1's code is written. The whitelist root check over a CSV is
needed by 27 October; the rehearsal waits on the testnet $MNTD; tranche 2 waits on the excluded
ids.

## Related documents

- `openspec/specs/`, `openspec/decisions.md`, `openspec/changes/tranche-1/` — the specification and the tranche's pick order.
- `docs/SPECIFICATION.md`, `docs/OPEN-QUESTIONS.md` (generated views), `docs/client/`, `docs/tools/build_client_doc.py`, `docs/tools/board.sh`.
- `test/<Suite>.tree.md` — one branching tree per test suite, leaves citing requirement IDs, with
  the auditor's INV-N and Fork-N obligations numbered once across all trees.
- `docs/RUNBOOK.md` — operating steps: the ownership handover (COL-10), the whitelist into Studio (WL-4), transfer enforcement (OPS-6), royalties (COL-6) and `Activation` — the read-back, the control check, the pause around rehearsals and switch-on, and the mint batch size (OPS-2, ACT-11).
- `test/SeaDropIntegration.t.sol` and its tree — the boundary with OpenSea Studio.
- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire the original build answered.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — the original decision log, item by item.
- `~/.claude/plans/mutable-sparking-candy.md` — the re-specification session: fact base,
  design tree, the SoW digest.
- `~/.claude/plans/in-previous-session-we-ticklish-thacker.md` — the answer intake: MINT's
  answers mapped to questions, the v2.0 design (whitelist registry, mystery box hub, prize
  vaults), and the assumptions made.
