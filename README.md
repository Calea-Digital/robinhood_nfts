# MintABear

A 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**. Holders burn
$MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their
off-chain MINT Status already pays. Activation and the Status link reset when a bear changes
hands.

**Start here: [`docs/HANDOVER.md`](docs/HANDOVER.md)** — current state, deploy runbook,
settled decisions, accepted risks, and the questions still open with the client. The
specification is in [`openspec/`](openspec/); the board (YouTrack `MNT`) follows it.

## Contracts

The specification calls for seven contracts, four in tranche 1. On `tranche-1` today:

| Contract | Base | Role |
|---|---|---|
| [`src/MintABear.sol`](src/MintABear.sol) | OpenSea `ERC721SeaDrop` | the collection. Transfer counter and reset event, burn refusal, `MAX_BEARS`, `exists`; ERC-721C with the validator set at deploy; stock SeaDrop metadata, royalties and two-step ownership |
| [`src/interfaces/IMintABear.sol`](src/interfaces/IMintABear.sol) | — | the reads `Activation` depends on: `ownerOf`, `transferNonce`, `exists` |
| [`src/Activation.sol`](src/Activation.sol) | Solady `Ownable` | the level record: credits from one adapter (the crediter), levels and royalty weights, the MINT Status link, `snapshot` for the royalty split; holds no token |
| [`src/WhitelistClaim.sol`](src/WhitelistClaim.sol) | Solady `Ownable`, `EIP712`, `ECDSA` | the on-chain whitelist registry: 1,000 allocations claimed with a voucher from MINT's eligibility signer, two per wallet and per account, inside the campaign window; its claimant list is the Studio allowlist |
| [`script/WhitelistExport.s.sol`](script/WhitelistExport.s.sol) | forge-std `Script` | read-only: exports the claimant CSV for Studio and checks the allowlist root Studio set against the registry |

`DirectBurnAdapter` (the one crediter) is tranche-1 work still to land; `MysteryBox`,
`PrizeDraw` and `PrizeVault` are tranche 2.

The token never calls the activation contract. The dependency runs one way only, so no
defect in `Activation` can block a transfer and none can silently skip a reset: every
non-mint transfer advances `transferNonce` and emits `TransferNonceAdvanced`, and a level
recorded at an older counter value reads as zero.

Mint pricing, stages, dates, per-wallet limits, metadata and royalties are **not** in these
contracts. They are configured through OpenSea Studio / SeaDrop.

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
and a `Given / When / Then` block in every test that quotes the specification's Scenario for
the requirement it satisfies. Coverage gate is ≥90% line and ≥80% branch; the suite sits at
100% on both.

Fuzz, invariant, mutation, formal-verification and fork harnesses are deliberately absent.
They belong to the auditor and are run independently — a dev-authored invariant suite anchors
the reviewer and creates a false "invariants done" signal. The trees document the INV-N and
Fork-N obligations and leave them unimplemented, on purpose.

`test/poc/` holds proofs of concept from security review, kept as regression guards.
