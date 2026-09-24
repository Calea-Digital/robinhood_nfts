# DEL-6 — the integration package (session 2)

Open a fresh Claude Code session in `~/trees/robinhood_nfts` once `tranche-1` is merged into
`main`. The YouTrack connector must be connected. Paste everything below the line.

---

Build DEL-6 for MintABear tranche 1: the typed TypeScript client library over the tranche-1 ABIs,
with its own tests and the revert reasons a caller handles, and the reference royalty-split
script with the dead-address exclusion. Work through the project's loop, one piece at a time,
and stop for me at each point marked **Stop**.

**Where things stand (2026-09-24).** Tranche 1 (`MintABear`, `WhitelistClaim`, `Activation`,
four scripts) is reviewed and merged; spec v2.2 with the review's amendments. The play page on
getminted.io is MINT's, in TypeScript, built against this library (CQ-19, DEL-11). The mystery
box is tranche 2: this library leaves a place for it and builds none of it.

**Read first:** `CLAUDE.md`; `docs/HANDOVER.md` ("For the portal team", "Integration", "Accepted
risks"); `openspec/specs/deliverables/spec.md` DEL-6 and DEL-11; the reads, events and errors in
COL-12/13, WL-3 and ACT-4, 9, 10, 13, 14; `openspec/decisions.md` CQ-14 (repository — **open**),
CQ-19 (resolved) and CQ-21 (**open**: how MINT's Status counts an account's links);
`reports/tranche-1-review-log.md` "Carried forward" (the DEL-6 notes); the ABIs under
`out/<Contract>.sol/<Contract>.json`.

## Decide before code — Stop

1. **Where the packages live (CQ-14 is open).** Propose `packages/contracts-client` in this
   repository for now, movable into MINT's monorepo later, versus waiting. Name the toolchain
   (TypeScript, viem, a test runner such as vitest, a local chain such as anvil) and how the
   ABIs reach the package (generated from `out/` by a script, checked in CI for drift).
2. **Whether DEL-6 goes on the board as one Task or several** (it is one requirement; the
   library and the split script are separable). Board shape is mine to choose.

## What the library covers

- **Mint** through SeaDrop: public and allowlist stages, `mintPublic` / `mintAllowList` with the
  allowlist proof. The proofs use Studio's sorted-leaf tree, built exactly as
  `script/lib/AllowListTree.sol` builds it (merkletreejs, sorted leaves and pairs); a
  known-answer test pins a proof against that library.
- **Mint stages:** the whitelist stage is Studio's first stage open to non-team wallets (WL-4);
  SeaDrop's per-wallet limit counts every mint to the wallet, so the mirror shows a claimant its
  remaining whitelist mints as `allocations − numberMinted`.
- **Whitelist claim** (WL-3): read `spotsLeft`, `claimsOf`, `accountClaims`, the window; submit
  `claim(voucher, signature)`. A viem `signTypedData` known-answer test: the exact type string
  `Claim(address wallet,uint8 allocationIndex,bytes32 account,uint256 deadline)`, domain
  `WhitelistClaim` / `1` / chainId / verifyingContract; `allocationIndex` is the **account's**
  allocation number (1 at $50, 2 at $100), whichever wallet claims.
- **Burn** (ACT-4, ACT-7, ACT-8): `costToReach(tokenId, target)` sizes the burn; approve
  **`Activation`** on $MNTD; `burn(tokenId, amount)`. Anything above the level-5 remainder is
  refused. Before a burn, warn about — or offer to cancel — the bear's open marketplace listings:
  a listing filled after a burn costs the seller the $MNTD and gives the buyer level 0.
- **Link** (ACT-9): `linkBear`, `unlinkBear`, `linkOf`. Prompt for `linkBear` after a purchase and
  after a holder's first burn — a wallet has no Status boost until it links, level 5 included —
  and show a link voided by a sale. How an account's several links combine is CQ-21's, open:
  leave it to MINT's Status service and do not encode an answer.
- **Transfers:** refuse `from == to` in the client and warn before transferring an activated
  bear — every transfer, a self-transfer and an approved operator's included, resets the level
  and the link.
- **Reads** (COL-12, ACT-14): `levelOf`, `cumulativeOf`, `lifetimeBurned`, `weightOf`,
  `weightFor`, `thresholdFor`, `costToReach`, `linkOf`, `snapshot`, `paused`, `transferNonce`,
  `exists`.

## The backend's voucher rules (MINT's code; the library documents them and its tests pin them)

- **`account`** is a keyed hash over a canonical account id — `HMAC(serverKey, canonicalId)`, or
  keccak with a server-side pepper — never an unsalted hash of a low-entropy id: `account` is an
  indexed topic of `WhitelistClaimed`, so an unsalted hash ties wallets to casino accounts, and a
  non-canonical id (email case, whitespace) splits one person into two accounts past the
  two-per-account cap.
- **`allocationIndex`** comes from the chain: `accountClaims(account) + 1`, not from the wager
  tier; issue index 2 only once index 1 is claimed.
- **Check `claimsOf(wallet) < 2`** before signing for a wallet, or the claim reverts `WalletLimit`.
- **The signer is an EOA** (ecrecover only; a contract signer gets `BadSigner`), and a rotated-out
  key is never rotated back in (its unexpired vouchers would revive). `deadline` is short by the
  backend's promise; the contract sets no cap.

## Revert reasons a caller handles (documented and tested)

- `BurnDisabled` for any transfer to the zero address.
- `burn` in check order: `ContractPaused`, `ZeroAmount`, `NotBearOwner`, `AlreadyAtMaxLevel`,
  `Overshoot`; `Reentrancy` never in normal use; the token's own reverts (allowance, balance).
- **An id never minted** reverts `OwnerQueryForNonexistentToken` (ERC721A) from `burn` and
  `linkBear`, not `NotBearOwner`.
- `claim`: `NotClaimant`, `BadSigner`, `Expired`, `CampaignClosed`, `SoldOut`, `WalletLimit`,
  `AccountLimit`, `WrongAllocation`.
- SeaDrop's mint errors, `MintQuantityExceedsMaxSupply` among them (it fires before
  `ExceedsMaxBears` while `maxSupply` is 4,444).

## Events and indexing

- `TransferNonceAdvanced(tokenId, nonce)` is the reset; it precedes `Transfer` in the logs of the
  same transaction. The indexer voids a bear's level and every link to it there; a later
  `BearUnlinked` for a void link is a no-op.
- A new `BearLinked(wallet, tokenId)` replaces the wallet's previous link without a
  `BearUnlinked` for the old bear.
- `BearActivated(tokenId, burner, previousLevel, newLevel, amount, cumulative)` has no `ref`.
  A burn transaction also carries $MNTD's own `Transfer(holder, 0x0, amount)`: filter by emitter.

## The reference royalty-split script

- Input: a closing block. Owners from indexed `Transfer` events at that block and weights from
  `weightOf` (no owner walk), or `Activation.snapshot` paged by a **gas budget** from an archive
  node — measured 56.2M gas for 1..4444 at two bears per wallet, and quadratic over a long
  untransferred mint batch, so one full-range call is not dependable.
- Ids exactly 1..4444 (duplicates return duplicate rows), **summed only over ids that have an
  owner**: `weightOf` answers 100 for an id never minted, where `snapshot` answers 0, so before
  sell-out a `weightOf` sum over the whole range counts phantom bears; a wallet's weight is the
  sum over its bears; the eligible total excludes `0x000000000000000000000000000000000000dEaD`; contract-held
  bears keep their weight (MINT's policy to decide).
- Output shares such that allocations plus carried rounding equal the funding, with a test that
  pins it on a fixture.

## Gates

The library's own tests pass in CI (its own job beside Foundry's); the ABI-drift check passes;
`forge` gates unchanged. Deterministic tests only — no fuzz or invariant harnesses.

**Never:** push; merge into `main`; set Done; edit a bridge-owned field; encode an answer to
CQ-14 or CQ-21 without my word.
