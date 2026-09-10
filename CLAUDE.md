# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Empty Foundry project. `src/`, `test/`, and `script/` exist but contain no Solidity — the `forge init` `Counter` scaffold was deleted deliberately. There is no protocol code yet and no architecture to preserve, so the first contracts set the conventions rather than inheriting any.

Note that `forge build`, `forge test`, and `forge fmt --check` all exit 0 with no sources, so CI is green on an empty tree — a passing CI run here does not mean anything is being tested.

## Commands

```shell
forge build                # compile
forge build --sizes        # compile + contract size report (what CI runs)
forge test -vvv            # full suite with traces
forge fmt                  # format
forge fmt --check          # format check (CI gate — run before pushing)
forge snapshot             # gas snapshots
slither .                  # static analysis
anvil                      # local node
```

Targeting a single test:

```shell
forge test --match-path test/<File>.t.sol
forge test --match-contract <ContractName>Test
forge test --match-test test_<Name> -vvvv
forge test --match-test testFuzz_<Name> --fuzz-runs 10000
```

Fork testing (PoCs against mainnet state):

```shell
forge test --fork-url $ETH_RPC_URL --fork-block-number <block>
```

Deploy simulation:

```shell
forge script script/<File>.s.sol:<ScriptContract> --rpc-url <rpc> --private-key <key>
```

## Setup

`lib/forge-std` is a git submodule. After a fresh clone: `git submodule update --init --recursive` (or `forge install`).

## Configuration notes

- `foundry.toml` declares only `[profile.default]` (src/out/libs). No solc version, optimizer, or fuzz settings are pinned — compilation uses whatever solc satisfies the source pragmas. Pin `solc_version` explicitly before any audit or gas work so results are reproducible.
- `[profile.ci]` (selected by `FOUNDRY_PROFILE=ci` in CI) raises only fuzz/invariant runs. Build settings must stay in `[profile.default]` so `forge build --sizes` is comparable between local and CI. Reproduce a CI run locally with `FOUNDRY_PROFILE=ci forge test`.
- No pragma precedent exists any more. Target `^0.8.20+` on the first contract and pin `solc_version` in `[profile.default]` at the same time, so the whole project compiles under one known compiler.
- OpenZeppelin is not installed. Add it with `forge install OpenZeppelin/openzeppelin-contracts` (and `-upgradeable` if proxies are needed), then add the remapping to `foundry.toml`.

## CI gates

Push and PR both run: `forge fmt --check`, `forge build --sizes`, `forge test -vvv`. All three must pass — `fmt --check` fails the build on unformatted Solidity, so run `forge fmt` before committing.
