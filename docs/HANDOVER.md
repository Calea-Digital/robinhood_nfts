# MintABear — handover

Written 2026-09-14. Read this first when resuming.

## State

Clean tree on `main`.

| | |
|---|---|
| Contracts | 4 written, all compiling |
| Tests | 137, all passing |
| Coverage | 100% line, 100% branch, 100% functions (gate is ≥90 / ≥80) |
| CI gates | `fmt --check`, `build --sizes`, `test` — all green |
| Slither | no High or Critical; 2 accepted Mediums (below) |

Submodule pins: `forge-std` `bf647bd` (v1.16.2), `seadrop` `757590f`, `solady` `acd959a` (v0.1.26).

Deployed sizes: `MintABear` 21,601 · `Activation` 6,052 · `BearAccount` 5,315 ·
`PlaceholderRenderer` 3,569 bytes. The chain's limit is ~96 KB; all four clear even
Ethereum's 24,576.

## What the client asked for, and where it lives

The architecture email of 2026-09-10 names four contracts to build. Four contracts exist,
but they are not a one-to-one match and a reviewer comparing the email line by line should
have this table rather than infer it.

| Client's list | Where it is |
|---|---|
| MINTaBear ERC-721C, SeaDrop-compatible | `src/MintABear.sol` |
| ERC-6551 TBA | `src/BearAccount.sol` |
| Activation / Level contract | `src/Activation.sol` |
| MINT Status / Rewards integration | **folded into `Activation`**: `linkBear`, `unlinkBear`, `linkOf`, ~24 lines |
| — | `src/renderers/PlaceholderRenderer.sol`, which is not on their list |

**Why the Status integration is not its own contract.** A separate contract would need the
same `ownerOf` and `transferNonce` reads, the same pause, and the same owner, in order to
hold one mapping. It would also need its own copy of the counter-matching rule that makes
the reset work. Folding it in keeps one implementation of that rule.

**Why there is a renderer they did not ask for.** Artwork does not exist and the contract
deadline is 21 September. The renderer is replaceable, so the collection can mint without
art and reveal later. It is a scheduling device, not a fifth deliverable.

## Where rewards stop being on-chain

This boundary is the most likely source of a late surprise, so it is stated plainly.

**On-chain:** that a wallet burned $MNTD into a bear, the cumulative total, the level that
total reaches, and which bear a wallet has nominated to carry its Status. `BearActivated`
logs token id, owner, previous level, new level, amount burned and the new cumulative, so
the record of what was bought is permanent.

**Not on-chain, anywhere:** the reward boost. There is no multiplier, no pool weight, no
Status tier, no accrual and no claim in any contract. The words *Status*, *boost*,
*multiplier* and *reward* appear in `src/` only in comments.

The chain records that a holder reached level 5. What level 5 is worth is the client's to
define and to change. Open questions 7 and 8 are both inside this boundary and both are
still unanswered — if the client believes a contract computes the boost, that surfaces on
20 October rather than before.

## Deadlines

| Date | Milestone |
|---|---|
| **15 Sep** | code complete, hand to the client's internal security reviewer |
| week of 15 Sep | internal audit (their reviewer; no external audit) |
| 2–4 Oct | mint |
| 17 Oct | qualification snapshot (client side) |
| **20 Oct** | TGE — $MNTD exists, activation goes live |

Two decouplings make this work and should be preserved if anything slips: **activation
cannot run before TGE** (there is no $MNTD to burn until 20 Oct), and **the artwork is off
the critical path** because the renderer is replaceable.

## What is left

1. **Deploy scripts** — `script/` is still empty. See the runbook below; it exists only as
   prose until someone writes it as `forge script`.
2. **Testnet rehearsal** on chain 46630, including the two OpenSea unknowns below and a
   gas-limit check on `recordAccounts`.
3. **Integration docs** for the getminted.io portal team — ABIs, addresses, and a typed
   client library, which is the agreed deliverable. The call surface and the four
   constraints that must survive into it are in "For the portal team" below; what is left
   is packaging them.
4. **The real renderer** — blocked on artwork that does not exist yet.

## Deploy runbook

Order matters, and two steps are easy to miss because nothing fails loudly without them.

1. `BearAccount` — no constructor arguments.
2. `PlaceholderRenderer(description, externalUrl, image)`.
3. `MintABear(name, symbol, [seaDrop], accountImplementation, renderer)`.
4. **`MintABear.recordAccounts(from, to)`, covering 1 to 4,444.** Roughly 25M gas per
   1,111-bear batch, so four batches, subject to the chain's block gas limit. Bounded by
   `MAX_BEARS` rather than by `maxSupply`, so it can run immediately and never needs
   repeating. Permissionless. **Without it, a bear can be sent to the account address of a
   bear that has not minted yet.**
5. **`MintABear.setMaxSupply(4444)` — exactly 4,444, not more.** `maxSupply` is zero on
   deployment and every mint reverts until it is set. Set it higher and the collection still
   cannot be inflated, but Studio advertises a supply the token will not deliver; see
   "What OpenSea Studio still owns" below.
6. Royalties, provenance hash, SeaDrop drop configuration.
7. Separately, after TGE: `Activation(bears, mntd, thresholds)`. $MNTD must already exist —
   the constructor reads `decimals()`.
8. At reveal: `MintABear.setRenderer(realRenderer)`.

## For the portal team

The NFT tab on getminted.io drives everything below. Four of these are constraints rather
than notes: nothing on-chain enforces them, and each one is a way for the portal to lose a
user's money or confuse them.

**1. Always size an activation with `costToReach`.** `Activation.burn` accepts any amount
and banks all of it. The part above the level-5 threshold buys nothing and is destroyed.
Call `costToReach(tokenId, targetLevel)` for the exact remainder and offer that. The
contract cannot tell a deliberate overshoot from a fat finger, so this cannot be enforced
on-chain and the portal is the only thing standing between a holder and a pointless burn.

**2. Activation is two steps, not one.** `burn` uses `burnFrom`, so the holder must first
`approve` the `Activation` contract on $MNTD. Confirm the burn interface against open
question 1 before building this — a self-burn-only token changes the flow.

**3. Metadata comes from the renderer, never from `baseURI`.** Do not read or display
`baseURI`; it is stored and never served. `tokenURI` is the only source.

**4. A bear's wallet does not advertise the receiver interfaces.** `supportsInterface` on a
`BearAccount` returns false for `IERC721Receiver` and `IERC1155Receiver` even though receipt
of both works. Anything in the portal that gates a deposit on ERC-165 will refuse to send to
a bear wallet; do not gate on it.

### Call surface

Reads are free and safe to poll. Everything that writes is one transaction from the holder.

| Purpose | Call |
|---|---|
| Bear's wallet address, deployed or not | `MintABear.accountOf(tokenId)` |
| Bring the wallet into existence | `MintABear.deployAccount(tokenId)` — anyone, any time, idempotent |
| Who controls a wallet | `BearAccount.owner()` |
| Move assets out of a wallet | `BearAccount.execute(target, value, data, 0)` — operation **must** be 0; batch with `executeBatch` |
| Current level | `Activation.levelOf(tokenId)` — reads 0 after a sale |
| Burned so far by this owner | `Activation.cumulativeOf(tokenId)` |
| Burned ever, across all owners | `Activation.lifetimeBurned(tokenId)` |
| Cost of the next level | `Activation.costToReach(tokenId, level)` |
| Price of a level outright | `Activation.thresholdFor(level)` |
| Activate | `Activation.burn(tokenId, amount)` — owner only, after approving $MNTD |
| Nominate a bear for Status | `Activation.linkBear(tokenId)` — owner only, one per wallet |
| Remove the nomination | `Activation.unlinkBear()` — safe to call unconditionally |
| A wallet's nominated bear and its level | `Activation.linkOf(wallet)` — returns `(0, 0)` once sold |
| Is activation suspended | `Activation.paused()` |

Indexing: `BearActivated`, `BearLinked` and `BearUnlinked` on `Activation`, plus the token's
own `Transfer`. **There is no reset event** — derive a reset from `Transfer`, because nothing
executes at reset time. That is the property that makes the reset impossible to skip.

## What OpenSea Studio still owns

Studio configures the drop; this collection enforces a small number of things for itself.
The division is clean apart from two places, both pinned in `test/SeaDropIntegration.t.sol`
and explained in `test/SeaDropIntegration.tree.md`.

Unaffected, verified by test: the mint entry point and its allowed-caller guard, per-wallet
limits (`getMintStats` reports each wallet's own count), mint stages, dates and pricing,
primary sale and payout settings, `multiConfigure`, provenance hash, ERC-2981 royalties,
operator transfers of the kind Seaport's conduit performs, ERC-165 detection of every
interface OpenSea looks for, and the deliberately unset transfer validator.

**1. `maxSupply` above `MAX_BEARS` produces a mismatch that cannot be corrected in code.**
`getMintStats` and `setMaxSupply` are both final on `ERC721SeaDrop` — neither is `virtual` —
so the collection can neither clamp what it reports nor refuse an over-large setting. Set
`maxSupply` to 10,000 and Studio's UI shows 10,000, SeaDrop's own check passes, and the mint
reverts at 4,445 with `ExceedsMaxBears`. The collection cannot be inflated, which is the
point of the cap, but buyers past the cap pay gas for a failed transaction. **Set
`maxSupply` to 4,444 and never raise it.**

**2. A `baseURI` configured through Studio is stored and never served.** `tokenURI` is
overridden to answer from the renderer, so metadata is on-chain and `setBaseURI` has no
effect. Nothing reverts, which is exactly why it needs stating: a Studio-managed drop
configures metadata through `baseURI` by default, and it will appear to work. The portal
team and whoever operates the drop both need to know metadata comes from
`MintABear.setRenderer` and nowhere else.

**3. Burning is refused, so any Studio feature that burns is unavailable.** That includes
burn-to-redeem. `ERC721SeaDrop.burn` is final and cannot be overridden, so the refusal lives
in `_beforeTokenTransfers`. A holder or marketplace UI offering a burn action will see the
transaction revert. If the client ever wants burn-to-redeem, this is the decision to revisit
— and the reason it was made is that a burned bear's wallet contents become unreachable for
good.

## Decisions that should not be relitigated

Each of these was settled deliberately and costs more to revisit than to keep.

- **The transfer counter, not a callback.** A callback either fails open (the reference
  project's `try … catch {}` lets a sold bear keep the seller's level) or bricks transfers.
  The counter can do neither.
- **`solc 0.8.17`.** Forced by SeaDrop's exact pragma, not chosen. See `CLAUDE.md`.
- **Transfer validator unset.** Enabling it on 4663 makes bears unsellable on OpenSea and
  blocks smart wallets from moving them. Both verified live.
- **Solady over Tokenbound for the account.** Tokenbound's deployed configuration has a
  broken root-owner traversal, an obsolete ERC-4337 version, and an upgrade switch held by
  an unrelated third party's multisig.
- **Canonical ERC-6551 registry.** The reference project used a custom one; its accounts are
  undiscoverable by standard wallets and indexers.
- **Wallets immutable, no admin path into user assets.** This is the specification's "no
  admin asset seizure" requirement, and the reason we rejected Tokenbound. Solady's `ERC6551`
  does inherit `UUPSUpgradeable`, but its `onlyViaERC6551Proxy` guard refuses any upgrade
  when the proxy hardcodes the implementation — which is what the canonical registry
  deploys. `test_upgrade_isRefused` pins it.
- **No burn.** Burning a bear would strand its wallet contents permanently: the account
  resolves its controller through `ownerOf`, which stops answering. `ERC721SeaDrop` exposes
  a public `burn` that is neither `virtual` nor internal, so it is refused in
  `_beforeTokenTransfers` instead, where every burn passes with `to` set to zero.
- **Supply capped in code.** `MAX_BEARS` is a constant checked on the mint path. The
  inherited `maxSupply` is an owner setting that OpenSea Studio can also write through
  `multiConfigure`, so it cannot carry the 4,444 guarantee on its own.
- **Only `ownerOf` may activate.** An operator approved to transfer a bear must not be able
  to spend the owner's $MNTD, and must not be able to spend from the bear's wallet either.

## Accepted risks

- **Slither "locked ether" ×2** (`Activation`, `PlaceholderRenderer`). Solady marks its
  ownership functions `payable` as a gas optimisation, and neither contract has a withdraw
  path. Only the owner could lock their own ETH, by deliberately attaching value to an
  ownership call. Accepted.
- **Slither "reentrancy-events" ×1** (`Activation.burn`). Event ordering only: the record is
  written before `MNTD.burnFrom`. $MNTD is untrusted because it does not exist yet, and the
  hostile cases were traced — reentering `burn` still needs each `burnFrom` to succeed, and
  transferring the bear from inside `burnFrom` voids the caller's own record. Accepted.
- **No activation-reset event.** The specification asks for one (marked Recommended). With
  the counter, nothing executes at reset — which is exactly why it cannot fail — so there is
  no opportunity to emit. Indexers derive it from the token's `Transfer` event.
- **Burning past level 5 is permitted and the excess is destroyed.** `burn` accepts any
  amount and banks all of it; the part above the level-5 threshold buys nothing.
  `costToReach` returns the exact remainder and the portal is **required** to use it on
  every activation. The contract cannot tell a deliberate overshoot from a mistake, so this
  cannot be enforced on-chain.
- **The bear-account guard is collection-local.** It refuses any destination that is one of
  this collection's bear accounts, at any depth. An NFT from another collection reaching a
  bear's wallet relies on Solady's cycle check, which runs only on `safeTransferFrom`; a
  plain `transferFrom` skips it. No bear can reach an account by either route.
- **`supportsInterface` on a bear's wallet does not advertise the ERC-721 or ERC-1155
  receiver interfaces**, although receipt of both works. Anything that gates a deposit on
  ERC-165 will refuse to send to a bear wallet. The portal team needs to know.

## Verified on-chain facts

Measured against chain 4663 on 2026-09-10. Do not re-research these.

| | Address / value |
|---|---|
| Robinhood Chain mainnet | chain id **4663**, RPC `https://rpc.mainnet.chain.robinhood.com` |
| Testnet | chain id **46630**, RPC `https://rpc.testnet.chain.robinhood.com` |
| ERC-6551 registry | `0x000000006551c19487814612e58FE06813775758` — byte-identical to Ethereum; hardcoded in Solady |
| Canonical SeaDrop | `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5` |
| CREATE2 deployer | `0x4e59b44847b379578588920cA78FbF26c0B4956C` — present |

- **Contract size limit is ~96 KB**, four times Ethereum's, confirmed by test deployment.
- **`block.number` returns the L1 Ethereum height, not L2.** Never key logic on it; use
  `block.timestamp`. Block time is ~100 ms.
- **No usable randomness.** `block.prevrandao` is a constant and Chainlink VRF is not
  available. This is why trait assignment is a published manifest committed via
  `setProvenanceHash`, not a reveal lottery.
- **`block.blobbasefee` reverts.** It is the one unsupported opcode.
- **Sequencer-level compliance screening is active.** A holder's transaction can be blocked
  and force-inclusion via L1 is not a reliable escape. No part of the system may break when
  one holder cannot transact — no hard deadlines, no "everyone must act by day N".
- **Mainnet Blockscout's API sits behind a bot challenge.** Verify through Sourcify
  (supports both 4663 and 46630).
- **OpenSea supports the chain** and Studio drops run there today.

## Two unknowns to settle on testnet

Neither is answered by public documentation, and both bear on the mint path:

1. Will OpenSea Studio attach to and manage a contract we deployed ourselves?
2. Does an on-chain `tokenURI` render correctly in a Studio-managed drop?

A third, smaller one has joined them: whether a ~25M gas `recordAccounts` batch fits in a
block on 4663. If not, the batches get smaller; nothing else changes.

## Open questions with the client

1. **$MNTD burn interface.** We build against `burnFrom` + allowance, isolated behind one
   call in `Activation.burn`. A self-burn-only token makes activation two transactions and
   changes the portal flow. Asked; awaiting.
2. **Gating responsibility** — Studio or us. Does not block development; the contract is
   identical either way. Asked; awaiting.
3. **Vector source artwork — decays fastest.** HashLips consumes PNG layers and emits flat
   PNGs for IPFS, which contradicts the on-chain image requirement. If the artist authors in
   vector and exports both, we get both; raster-native means the on-chain image must be
   dropped. Free to ask before they start, a redraw afterwards.
4. **Royalty rate and receiver** — nothing to build, needed at deploy.
5. **The five burn thresholds** — constructor arguments with no setter, so they must be
   right. Needed by mid-October, not by the 15th.
6. **Compliance sign-off** — no on-chain controls. A required freeze or clawback would
   reshape the permission model.
7. **Does +2%…+10% uplift the Status payout or bump the Status tier?** We assume payout.
8. **Was the daily pool dropped when Status became stake-based?** Moot for our storage; a
   product question they should answer.
9. **Drop mechanics** — "guaranteed" is enforced by stage sequencing, not the contract, so
   the GTD window must close before WL opens. Team/treasury/partner bears come out of the
   same 4,444, and `MAX_BEARS` now enforces that on-chain, so the real over-allocation
   exceeds the stated 23.8%.
10. **Safe details** — address, threshold, and whether Safe's web UI supports 4663
    (contracts are deployed; the interface is unverified).

## Related documents

- `test/<Contract>.tree.md` — one branching tree per contract, including the invariant and
  fork-test obligations left for the auditor.
- `test/SeaDropIntegration.t.sol` and its tree — the boundary with OpenSea Studio, including
  the two places where the division is not clean.
- `test/poc/BurnStrandsAccount.t.sol` — a finding from the 2026-09-14 review, kept inverted
  as a regression guard, with the reasoning in its NatSpec.
- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire these answers came from.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — full decision log, item by item.
- The client's architecture email of 2026-09-10 outranks the original spec sheet wherever
  they conflict; where it is silent, the sheet governs.
