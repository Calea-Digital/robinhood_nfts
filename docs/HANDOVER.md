# MintABear — handover

Written 2026-09-11. Read this first when resuming.

## State

`main` at `995c401`, clean tree, everything merged.

| | |
|---|---|
| Contracts | 4 written, all compiling |
| Tests | 56, all passing |
| Coverage | 100% line, 96.3% branch, 100% functions (gate is ≥90 / ≥80) |
| CI gates | `fmt --check`, `build --sizes`, `test` — all green |
| Slither | no High or Critical; 2 accepted Mediums (below) |

Submodule pins: `forge-std` `bf647bd`, `seadrop` `757590f`, `solady` `acd959a` (v0.1.26).

## Deadlines

| Date | Milestone |
|---|---|
| **15 Sep** | code complete, hand to the client's internal security reviewer |
| week of 15 Sep | internal audit (their reviewer; no external audit) |
| 2–4 Oct | mint |
| 17 Oct | qualification snapshot (client side) |
| **20 Oct** | TGE — $MNTD exists, activation goes live |

Two decouplings make this work and should be preserved if anything slips: **activation cannot run before TGE** (there is no $MNTD to burn until 20 Oct), and **the artwork is off the critical path** because the renderer is replaceable.

## What is left

1. **Deploy scripts** — `script/` is still empty. Deployment order is `BearAccount` → `PlaceholderRenderer` → `MintABear` → (separately, before TGE) `Activation`. $MNTD must exist before `Activation` deploys, because its constructor reads `decimals()`.
2. **Testnet rehearsal** on chain 46630, including the two OpenSea unknowns below.
3. **Integration docs** for the getminted.io portal team — ABIs, addresses, and the read/write paths for activate, link, unlink, deploy wallet, read level. Agreed deliverable is interfaces plus a typed client library.
4. **The real renderer** — blocked on artwork that does not exist yet.

## Decisions that should not be relitigated

Each of these was settled deliberately and costs more to revisit than to keep.

- **The transfer counter, not a callback.** A callback either fails open (the reference project's `try … catch {}` lets a sold bear keep the seller's level) or bricks transfers. The counter can do neither.
- **`solc 0.8.17`.** Forced by SeaDrop's exact pragma, not chosen. See `CLAUDE.md`.
- **Transfer validator unset.** Enabling it on 4663 makes bears unsellable on OpenSea and blocks smart wallets from moving them. Both verified live.
- **Solady over Tokenbound for the account.** Tokenbound's deployed configuration has a broken root-owner traversal, an obsolete ERC-4337 version, and an upgrade switch held by an unrelated third party's multisig.
- **Canonical ERC-6551 registry.** The reference project used a custom one; its accounts are undiscoverable by standard wallets and indexers.
- **Wallets immutable, no admin path into user assets.** This is the specification's "no admin asset seizure" requirement, and the reason we rejected Tokenbound.
- **No burn function on the token.** Burning a bear would strand its wallet contents permanently.
- **Only `ownerOf` may activate.** An operator approved to transfer a bear must not be able to spend the owner's $MNTD.

## Accepted risks

- **Slither "locked ether" ×2** (`Activation`, `PlaceholderRenderer`). Solady marks its ownership functions `payable` as a gas optimisation, and neither contract has a withdraw path. Only the owner could lock their own ETH, by deliberately attaching value to an ownership call. Accepted.
- **No activation-reset event.** The specification asks for one (marked Recommended). With the counter, nothing executes at reset — which is exactly why it cannot fail — so there is no opportunity to emit. Indexers derive it from the token's `Transfer` event.
- **Level semantics are off-chain.** The chain records that a holder reached level 5; what level 5 is worth is the client's to define and change. The activation event logs token id, owner, previous and new level, and amount burned, so the record of what was bought is permanent even though the interpretation is not.

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
- **`block.number` returns the L1 Ethereum height, not L2.** Never key logic on it; use `block.timestamp`. Block time is ~100 ms.
- **No usable randomness.** `block.prevrandao` is a constant and Chainlink VRF is not available. This is why trait assignment is a published manifest committed via `setProvenanceHash`, not a reveal lottery.
- **`block.blobbasefee` reverts.** It is the one unsupported opcode.
- **Sequencer-level compliance screening is active.** A holder's transaction can be blocked and force-inclusion via L1 is not a reliable escape. No part of the system may break when one holder cannot transact — no hard deadlines, no "everyone must act by day N".
- **Mainnet Blockscout's API sits behind a bot challenge.** Verify through Sourcify (supports both 4663 and 46630).
- **OpenSea supports the chain** and Studio drops run there today.

## Two unknowns to settle on testnet

Neither is answered by public documentation, and both bear on the mint path:

1. Will OpenSea Studio attach to and manage a contract we deployed ourselves?
2. Does an on-chain `tokenURI` render correctly in a Studio-managed drop?

## Open questions with the client

1. **$MNTD burn interface.** We build against `burnFrom` + allowance, isolated behind one call in `Activation.burn`. A self-burn-only token makes activation two transactions and changes the portal flow. Asked; awaiting.
2. **Gating responsibility** — Studio or us. Does not block development; the contract is identical either way. Asked; awaiting.
3. **Vector source artwork — decays fastest.** HashLips consumes PNG layers and emits flat PNGs for IPFS, which contradicts the on-chain image requirement. If the artist authors in vector and exports both, we get both; raster-native means the on-chain image must be dropped. Free to ask before they start, a redraw afterwards.
4. **Royalty rate and receiver** — nothing to build, needed at deploy.
5. **The five burn thresholds** — constructor arguments with no setter, so they must be right. Needed by mid-October, not by the 15th.
6. **Compliance sign-off** — no on-chain controls. A required freeze or clawback would reshape the permission model.
7. **Does +2%…+10% uplift the Status payout or bump the Status tier?** We assume payout.
8. **Was the daily pool dropped when Status became stake-based?** Moot for our storage; a product question they should answer.
9. **Drop mechanics** — "guaranteed" is enforced by stage sequencing, not the contract, so the GTD window must close before WL opens. Team/treasury/partner bears come out of the same 4,444, so the real over-allocation exceeds the stated 23.8%.
10. **Safe details** — address, threshold, and whether Safe's web UI supports 4663 (contracts are deployed; the interface is unverified).

## Related documents

- `docs/MintABear-Questionnaire-v2.0.docx` — the client questionnaire these answers came from.
- `~/.claude/plans/i-am-starting-a-tidy-sloth.md` — full decision log, item by item, with reasoning.
- The client's architecture email of 2026-09-10 outranks the original spec sheet wherever they conflict; where it is silent, the sheet governs.
