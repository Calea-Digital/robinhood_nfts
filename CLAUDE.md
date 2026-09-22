# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MintABear — a 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**, built for a third party as the TGE vehicle for their casino product. Every bear owns an ERC-6551 account. Holders burn $MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their off-chain MINT Status already pays. Activation and the Status link reset when a bear changes hands.

Start any session by reading `docs/HANDOVER.md` — it carries current state, what is done, what is next, and the open questions waiting on the client.

## Specification and board

**The specification lives in `openspec/`**, in the calea-house OpenSpec format: `openspec/specs/<family>/spec.md` (one file per family — `collection` COL, `whitelist` WL, `activation` ACT, `mystery-box` RAF, `operations` OPS, `deliverables` DEL), `openspec/decisions.md` (the `CQ-n` register) and `openspec/config.yaml` (`spec_version`). Every requirement carries `**Kind:**` (work-item, acceptance-standard, commercial or informative) and one `#### Scenario:` — the Scenario is the requirement's definition of done and the text a unit test's `/* Scenario: */` block quotes. A MODIFIED delta must repeat the Kind line; `openspec archive` drops it otherwise.

**`docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md` are generated views** where their markers say so (`<!-- openspec:begin … -->` … `<!-- openspec:end -->`): the narrative between markers is edited in place, the requirement and register blocks are written by `docs/tools/spec_tools/render_calea_prose.py` from `openspec/`. CI fails when they are stale. `docs/tools/build_client_doc.py` reads them unchanged to build the client document.

**The board (YouTrack project MNT) is a function of `openspec/`.** After any spec or register edit: commit, then run `docs/tools/board.sh` (or `/mnt:board`). It validates, lints, checks the rendered prose, previews and writes the board through the ai-stack bridge (`~/trees/ai-stack/scripts/youtrack-bridge`, `/usr/bin/python3`), then reads it back with the validator's ten checks. Never edit a bridge-owned field in YouTrack by hand.

**Who writes what on the board.** The bridge owns summary, body (statement, `Done when`, `Gates`), Type, Work Kind, Spec Ref, parent Milestone, tranche tags, decision State and Due Date, and gating links. Claude owns a requirement Task's State from Open to In Review, the claim comment, the `MNT Claude` tag, Spent time, Subtasks (only when a step has another owner), Defects (Work Kind Defect, Spec Ref = the violated requirement or `NONE`, body with `Reproduce` / `Expected` / `Observed`) and `NONE` Tasks for non-spec work. The human owns Done and Canceled, Priority, Estimation, Assignee, and picks DEL and OPS-1/5 work. Nobody targets project KNI; Claude deletes nothing.

**The work loop.** The active OpenSpec change is `openspec/changes/tranche-1/`; its `tasks.md` is the pick order, one requirement id per line. `/mnt:next` takes the first unticked id, confirms the Task is Open and not hard-gated (a `depends on` link to a decision in State Open), claims it comment-first (`Claim <nonce> …` with the plan as a checklist; the earliest claim wins, the loser yields), sets In Progress, tags `MNT Claude`, branches `mnt/<spec-ref>` and works. Work happens on `mnt/<spec-ref>` branched off the integration branch `tranche-1`; `/mnt:done` runs the Task's Gates — `forge fmt --check`, warning-free `forge build --sizes`, `forge test`, the coverage gate, `slither . --exclude-dependencies` with no new High or Critical — runs a `differential-review:diff-review` self-review on value- or role-touching changes, merges the Task branch back into `tranche-1` with `--no-ff`, ticks `tasks.md`, sets In Review, comments a summary and logs time; a human sets Done and merges `tranche-1` into `main`. The skills per step are the ai-stack web3 manual's W7: `openzeppelin-skills:develop-secure-contracts` for OpenZeppelin patterns (SeaDrop and Solady win where they differ), `evm-internals` for storage and gas, `/solidity` for style; never `fizz`, invariants or fuzz harnesses. `/mnt:resume` finds the live claim (a Task In Progress with no claim comment is a human's; a claim older than 24 h with no commits is released). A spec edit goes through `/opsx:propose` → lint → `/opsx:archive` (then fold the decisions delta into `openspec/decisions.md` and any REMOVED id into `## Retired Requirements` by hand) → commit → `/mnt:board`. New command names need a Claude Code restart before first use.

## Architecture

Four contracts. The token never calls the activation contract; the dependency runs one way only.

| Contract | Base | Role |
|---|---|---|
| `src/MintABear.sol` | OpenSea `ERC721SeaDrop` | the collection. Transfer counter, bear-account guard, supply cap, burn refusal, renderer delegation |
| `src/BearAccount.sol` | Solady `ERC6551` | the wallet each bear owns. Immutable, no admin path |
| `src/Activation.sol` | standalone | cumulative burn, level derivation, Status link |
| `src/renderers/PlaceholderRenderer.sol` | standalone | pre-reveal metadata; replaced by the real renderer at reveal |

**The transfer counter is the load-bearing idea.** `MintABear` increments `transferNonce[tokenId]` on every transfer and never on mint. `Activation` stores a level alongside the counter value it was recorded at, and treats it as void once the counter moves. The reset is therefore a consequence of the transfer rather than an action that must succeed — it cannot be skipped, and a defect in `Activation` cannot block a transfer. Do not replace this with a callback from the token; that pattern fails open, and we have a live example of it doing so.

**Bear-account guard.** Each bear's canonical account address is recorded in `isBearAccount`, and `_beforeTokenTransfers` refuses any destination in that mapping, so a bear can never be sent into any bear's account — including accounts that have never been deployed. This blocks ownership cycles of every length, not just self-deposit. Addresses are recorded as each bear mints, and `recordAccounts` pre-records a range so the rule also covers bears that have not minted yet; it is bounded by `MAX_BEARS`, permissionless and idempotent, and belongs in the deploy sequence. See the runbook in `docs/HANDOVER.md`.

**Two things the SeaDrop base cannot enforce.** `ERC721SeaDrop.burn` and `setMaxSupply` are both `external` and neither is `virtual`, so neither can be overridden. Both are handled on the mint/transfer path in `_beforeTokenTransfers` instead: `to == address(0)` is refused, because a burned bear's account would keep its contents while resolving its controller through an `ownerOf` that no longer answers; and `MAX_BEARS` caps supply, because the inherited `maxSupply` is an owner setting that OpenSea Studio can also write through `multiConfigure`. When something inherited needs disabling, that hook is the lever.

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

Developer scope is **deterministic unit tests only**, with a BTT tree per contract (`test/<Contract>.tree.md`) and a `/* Scenario: Given / When / Then */` block in every test. Coverage gate: **≥90% line, ≥80% branch**; the suite currently sits at 100% on both, so a drop means something was added without a test.

`test/poc/` holds proofs of concept from security review, kept as regression guards with the finding written up in the contract's NatSpec. A PoC that gets fixed is inverted to assert the refusal rather than deleted.

**Do not write fuzz, invariant, mutation, formal-verification or fork-test harnesses.** Those belong to the auditor and are run independently; dev-authored invariant suites anchor the reviewer and create a false "invariants done" signal. The trees may *document* INV-N obligations, and they do — leave them documented and unimplemented. Deterministic single-scenario tests that happen to pin an invariant are in scope.

Write specs and docs as **final state, not changelog** — no "was X, now Y" in body prose.

## CI gates

Push and PR run `forge fmt --check`, `forge build --sizes`, `forge test -vvv`. All three must pass.
