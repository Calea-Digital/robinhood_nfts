# MintABear

A 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**. Holders burn
$MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their
off-chain MINT Status already pays. Activation resets when a bear changes hands. Holders also
open a mystery box with their bears, one shot per bear per cycle, decided by Chainlink VRF on
Arbitrum One; prizes are paid from MINT's wallet on each prize chain.

**Start here: [`docs/HANDOVER.md`](docs/HANDOVER.md)** — current state,
settled decisions, accepted risks, and the questions still open with the client. The
specification is in [`openspec/`](openspec/); the board (YouTrack `MNT`) follows it.

## Contracts

The specification (v2.6) calls for `MintABear` and `Activation` in tranche 1, and `MysteryBox`
(Robinhood Chain) and `PrizeDraw` (Arbitrum One) in tranche 2. The whitelist is off-chain, in
MINT's backend. On `tranche-1` today:

| Contract | Base | Role |
|---|---|---|
| [`src/MintABear.sol`](src/MintABear.sol) | OpenSea `ERC721SeaDrop` | the collection. Transfer counter and reset event, burn refusal, `MAX_BEARS`, `exists`; ERC-721C with the validator set at deploy; stock SeaDrop metadata, royalties and two-step ownership, never renounced |
| [`src/interfaces/IMintABear.sol`](src/interfaces/IMintABear.sol) | — | the reads `Activation` depends on: `ownerOf`, `transferNonce`, `exists` |
| [`src/Activation.sol`](src/Activation.sol) | Solady `Ownable`, `ReentrancyGuard`, `SafeCastLib` | the level record: a holder burns $MNTD for a bear and the burn is recorded in the same transaction; levels and royalty weights, `snapshot` for the royalty split; refuses amounts past level 5 |
| [`src/WhitelistClaim.sol`](src/WhitelistClaim.sol) | Solady `Ownable`, `EIP712`, `ECDSA` | not deployed, kept as a fallback: the voucher whitelist registry (retired WL-3). `src/WhitelistImport.sol`, the owner-imported variant (retired WL-7), likewise |

`MysteryBox` and `PrizeDraw` are tranche 2; no contract goes on a prize chain. `Activation` still
carries the Status link, which the specification retired (ACT-9) and `openspec/changes/tranche-1/tasks.md` 3.15 removes.

The token never calls the activation contract. The dependency runs one way only, so no
defect in `Activation` can block a transfer and none can silently skip a reset: every
non-mint transfer advances `transferNonce` and emits `TransferNonceAdvanced`, and a level
recorded at an older counter value reads as zero.

Mint pricing, stages, dates, per-wallet limits, metadata and royalties are **not** in these
contracts. They are configured through OpenSea Studio / SeaDrop.

## Scripts

| Script | Role |
|---|---|
| [`script/Deploy.s.sol`](script/Deploy.s.sol) | deploys the three tranche-1 contracts in the specified order, refusing a collection address that is not `MintABear`, from `script/config/<chain>.json` (template [`example.json`](script/config/example.json)), verifying on Sourcify as it broadcasts |
| [`script/verify.sh`](script/verify.sh) | re-verifies and checks on Sourcify every contract a deploy created |
| [`script/Enforcement.s.sol`](script/Enforcement.s.sol) | lifts or restores royalty enforcement with one owner call; prints the Safe transaction for a Safe admin |
| [`script/WhitelistExport.s.sol`](script/WhitelistExport.s.sol) | checks the allowlist root Studio set against the whitelist; the check over MINT's CSV is `tasks.md` 2.6, and today it reads a registry |

Operating steps are in [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Setup

```shell
git submodule update --init --recursive
```

Three submodules: `lib/forge-std`, `lib/seadrop`, `lib/solady`. SeaDrop carries its own
nested libs (ERC721A, OpenZeppelin, solmate, utility-contracts), which the remappings in
`foundry.toml` point into — do not install those separately.

## Commands

```shell
forge build --sizes        # compile + size report (what CI runs)
forge test                 # full suite
forge fmt --check          # format gate — run before pushing
forge coverage --no-match-coverage 'test/|lib/'
slither . --exclude-dependencies
```

Targeting a single test:

```shell
forge test --match-contract MintABearCreatorTokenTest
forge test --match-test test_transfer_emitsTheResetEvent_withALevel -vvvv
```

Reproduce a CI run locally: `FOUNDRY_PROFILE=ci forge test`.

## Tests

Deterministic unit tests only, with a branching tree per contract (`test/<Contract>.tree.md`)
and a `Given / When / Then` block in every test; a test that satisfies a requirement quotes that
requirement's Scenario from the specification. Coverage gate is ≥90% line and ≥80% branch; the
suite sits at 100% on both.

Fuzz, invariant, mutation, formal-verification and fork harnesses are deliberately absent.
They belong to the auditor and are run independently — a dev-authored invariant suite anchors
the reviewer and creates a false "invariants done" signal. The trees document the INV-N and
Fork-N obligations and leave them unimplemented, on purpose.

`test/poc/` holds proofs of concept from security review, kept as regression guards.
