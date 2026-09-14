# MintABear

A 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**. Every bear
owns an ERC-6551 account. Holders burn $MNTD to raise a bear's activation level (0–5), which
multiplies the reward rate their off-chain MINT Status already pays. Activation and the
Status link reset when a bear changes hands.

**Start here: [`docs/HANDOVER.md`](docs/HANDOVER.md)** — current state, deploy runbook,
settled decisions, accepted risks, and the questions still open with the client.

## Contracts

| Contract | Base | Role |
|---|---|---|
| [`src/MintABear.sol`](src/MintABear.sol) | OpenSea `ERC721SeaDrop` | the collection. Transfer counter, bear-account guard, supply cap, renderer delegation |
| [`src/BearAccount.sol`](src/BearAccount.sol) | Solady `ERC6551` | the wallet each bear owns. Immutable, no admin path |
| [`src/Activation.sol`](src/Activation.sol) | standalone | cumulative burn, level derivation, MINT Status link |
| [`src/renderers/PlaceholderRenderer.sol`](src/renderers/PlaceholderRenderer.sol) | standalone | pre-reveal metadata; replaced by the real renderer at reveal |

The token never calls the activation contract. The dependency runs one way only, so no
defect in `Activation` can block a transfer and none can silently skip a reset.

Mint pricing, stages, dates, per-wallet limits and primary sale settings are **not** in these
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
forge test --match-contract ActivationTest
forge test --match-test test_transfer_resetsLevelAndCumulative -vvvv
```

Reproduce a CI run locally: `FOUNDRY_PROFILE=ci forge test`.

## Tests

Deterministic unit tests only, with a branching tree per contract (`test/<Contract>.tree.md`)
and a `Given / When / Then` block in every test. Coverage gate is ≥90% line and ≥80% branch;
the suite currently sits at 100% on both.

Fuzz, invariant, mutation, formal-verification and fork harnesses are deliberately absent.
They belong to the auditor and are run independently — a dev-authored invariant suite anchors
the reviewer and creates a false "invariants done" signal. The trees document the INV-N
obligations and leave them unimplemented, on purpose.

`test/poc/` holds proofs of concept from security review, kept as regression guards.
