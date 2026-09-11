# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MintABear — a 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**, built for a third party as the TGE vehicle for their casino product. Every bear owns an ERC-6551 account. Holders burn $MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their off-chain MINT Status already pays. Activation and the Status link reset when a bear changes hands.

Start any session by reading `docs/HANDOVER.md` — it carries current state, what is done, what is next, and the open questions waiting on the client.

## Architecture

Four contracts. The token never calls the activation contract; the dependency runs one way only.

| Contract | Base | Role |
|---|---|---|
| `src/MintABear.sol` | OpenSea `ERC721SeaDrop` | the collection. Transfer counter, bear-account guard, renderer delegation |
| `src/BearAccount.sol` | Solady `ERC6551` | the wallet each bear owns. Immutable, no admin path |
| `src/Activation.sol` | standalone | cumulative burn, level derivation, Status link |
| `src/renderers/PlaceholderRenderer.sol` | standalone | pre-reveal metadata; replaced by the real renderer at reveal |

**The transfer counter is the load-bearing idea.** `MintABear` increments `transferNonce[tokenId]` on every transfer and never on mint. `Activation` stores a level alongside the counter value it was recorded at, and treats it as void once the counter moves. The reset is therefore a consequence of the transfer rather than an action that must succeed — it cannot be skipped, and a defect in `Activation` cannot block a transfer. Do not replace this with a callback from the token; that pattern fails open, and we have a live example of it doing so.

**Bear-account guard.** Each bear's canonical account address is recorded in `isBearAccount` at mint, when the address is already known. `_beforeTokenTransfers` refuses any destination in that mapping, so a bear can never be sent into any bear's account — including accounts that have never been deployed. This blocks ownership cycles of every length, not just self-deposit.

**ERC-721C.** `ERC721SeaDrop` already implements `ICreatorToken`, so this *is* an ERC-721C collection. The transfer validator is deliberately left unset: on 4663, OpenSea's conduit is not on the default allowlist, so enabling enforcement would make bears unsellable where they are actually listed, and smart wallets could not transfer them out. Do not point it at Limit Break's validator without re-reading `docs/HANDOVER.md` first.

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

## Setup

Three submodules: `lib/forge-std`, `lib/seadrop`, `lib/solady`. After a fresh clone run `git submodule update --init --recursive`. SeaDrop carries its own nested libs (ERC721A, OpenZeppelin, solmate, utility-contracts), which the remappings in `foundry.toml` point into — do not install those separately.

## Configuration notes

- **`solc_version = "0.8.17"` is forced, not chosen.** SeaDrop declares `pragma solidity 0.8.17;` — an exact pin, not a caret range — so everything in its import graph must compile at that version. This deviates from the `^0.8.20+` convention in the global instructions; the mandated dependency is the justification. Do not "upgrade" it without removing SeaDrop.
- **`evm_version = "london"` follows from that.** `paris` only arrived in solc 0.8.18, so london is the ceiling here. No PUSH0, no transient storage. Nothing in this codebase needs them and the bytecode is maximally portable as a result.
- `optimizer_runs = 1_000_000` matches SeaDrop's own setting. Robinhood Chain's contract size limit is ~96 KB (four times Ethereum's), so size is not a constraint — `MintABear` is 21 KB and fits under even the Ethereum limit.
- `[profile.ci]` raises only fuzz/invariant runs. Keep build settings in `[profile.default]` so `forge build --sizes` matches between local and CI.

## Test conventions

Developer scope is **deterministic unit tests only**, with a BTT tree per contract (`test/<Contract>.tree.md`) and a `/* Scenario: Given / When / Then */` block in every test. Coverage gate: **≥90% line, ≥80% branch**.

**Do not write fuzz, invariant, mutation, formal-verification or fork-test harnesses.** Those belong to the auditor and are run independently; dev-authored invariant suites anchor the reviewer and create a false "invariants done" signal. The trees may *document* INV-N obligations, and they do — leave them documented and unimplemented. Deterministic single-scenario tests that happen to pin an invariant are in scope.

Write specs and docs as **final state, not changelog** — no "was X, now Y" in body prose.

## CI gates

Push and PR run `forge fmt --check`, `forge build --sizes`, `forge test -vvv`. All three must pass.
