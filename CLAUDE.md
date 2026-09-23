# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MintABear — a 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**, built for a third party as the TGE vehicle for their casino product. Holders burn $MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their off-chain MINT Status already pays. Activation and the Status link reset when a bear changes hands.

Start any session by reading `docs/HANDOVER.md` — it carries current state, what is done, what is next, and the open questions waiting on the client.

## Specification and board

**The specification lives in `openspec/`**, in the calea-house OpenSpec format: `openspec/specs/<family>/spec.md` (one file per family — `collection` COL, `whitelist` WL, `activation` ACT, `mystery-box` RAF, `operations` OPS, `deliverables` DEL), `openspec/decisions.md` (the `CQ-n` register) and `openspec/config.yaml` (`spec_version`). Every requirement carries `**Kind:**` (work-item, acceptance-standard, commercial or informative) and one `#### Scenario:` — the Scenario is the requirement's definition of done and the text a unit test's `/* Scenario: */` block quotes. A MODIFIED delta must repeat the Kind line; `openspec archive` drops it otherwise.

**`docs/SPECIFICATION.md` and `docs/OPEN-QUESTIONS.md` are generated views** where their markers say so (`<!-- openspec:begin … -->` … `<!-- openspec:end -->`): the narrative between markers is edited in place, the requirement and register blocks are written by `docs/tools/spec_tools/render_calea_prose.py` from `openspec/`. CI fails when they are stale. `docs/tools/build_client_doc.py` reads them unchanged to build the client document.

**The board (YouTrack project MNT) is a function of `openspec/`.** After any spec or register edit: commit, then run `docs/tools/board.sh` (or `/mnt:board`). It validates, lints, checks the rendered prose, previews and writes the board through the ai-stack bridge (`~/trees/ai-stack/scripts/youtrack-bridge`, `/usr/bin/python3`), then reads it back with the validator's ten checks. Never edit a bridge-owned field in YouTrack by hand.

**Who writes what on the board.** The bridge owns summary, body (statement, `Done when`, `Gates`), Type, Work Kind, Spec Ref, parent Milestone, tranche tags, decision State and Due Date, and gating links. Claude owns a requirement Task's State from Open to In Review, the claim comment, the `MNT Claude` tag, Spent time, Subtasks (only when a step has another owner), Defects (Work Kind Defect, Spec Ref = the violated requirement or `NONE`, body with `Reproduce` / `Expected` / `Observed`) and `NONE` Tasks for non-spec work. The human owns Done and Canceled, Priority, Estimation, Assignee, and picks DEL and OPS-1/5 work. Nobody targets project KNI; Claude deletes nothing.

**The work loop.** The active OpenSpec change is `openspec/changes/tranche-1/`; its `tasks.md` is the pick order, one requirement id per line. `/mnt:next` takes the first unticked id, confirms the Task is Open and not hard-gated (a `depends on` link to a decision in State Open), claims it comment-first (`Claim <nonce> …` with the plan as a checklist; the earliest claim wins, the loser yields), sets In Progress, tags `MNT Claude`, branches `mnt/<spec-ref>` and works. Work happens on `mnt/<spec-ref>` branched off the integration branch `tranche-1`; `/mnt:done` runs the Task's Gates — `forge fmt --check`, warning-free `forge build --sizes`, `forge test`, the coverage gate, `slither . --exclude-dependencies` with no new High or Critical — runs a `differential-review:diff-review` self-review on value- or role-touching changes, merges the Task branch back into `tranche-1` with `--no-ff`, ticks `tasks.md`, sets In Review, comments a summary and logs time; a human sets Done and merges `tranche-1` into `main`. The skills per step are the ai-stack web3 manual's W7: `openzeppelin-skills:develop-secure-contracts` for OpenZeppelin patterns (SeaDrop and Solady win where they differ), `evm-internals` for storage and gas, `/solidity` for style; never `fizz`, invariants or fuzz harnesses. `/mnt:resume` finds the live claim (a Task In Progress with no claim comment is a human's; a claim older than 24 h with no commits is released). A spec edit goes through `/opsx:propose` → lint → `/opsx:archive` (then fold the decisions delta into `openspec/decisions.md` and any REMOVED id into `## Retired Requirements` by hand) → commit → `/mnt:board`. New command names need a Claude Code restart before first use.

## Architecture

The specification calls for seven contracts, four of them in tranche 1: `MintABear`, `WhitelistClaim`, `Activation`, `DirectBurnAdapter`. The token never calls the activation contract; the dependency runs one way only. What is on `tranche-1` today:

| Contract | Base | Role |
|---|---|---|
| `src/MintABear.sol` | OpenSea `ERC721SeaDrop` | the collection (COL-1…COL-13). Transfer counter and reset event, burn refusal, `MAX_BEARS`, `exists`; ERC-721C with the validator set at deploy; stock SeaDrop metadata, royalties and two-step ownership |
| `src/interfaces/IMintABear.sol` | — | the three reads `Activation` depends on: `ownerOf`, `transferNonce`, `exists` |
| `src/Activation.sol` | Solady `Ownable` | the level record (ACT-1 and on): token-agnostic — no $MNTD reference, moves no tokens; one `crediter` calls `credit(tokenId, burner, amount, nonce, ref)`, accepted only while `burner` owns the bear at the counter value `nonce`; thresholds (base units) and weights (basis 100) fixed in the constructor; `weightOf`, `snapshot`, the Status link, pause, and `renounceOwnership` refused while paused |
| `src/WhitelistClaim.sol` | Solady `Ownable`, `EIP712`, `ECDSA` | the whitelist registry (WL-1, WL-3…WL-5): 1,000 allocations claimed with an EIP-712 voucher from MINT's eligibility signer, two per wallet and two per account, inside the campaign window; `claimants(offset, limit)` is the export to the Studio allowlist |
| `script/WhitelistExport.s.sol` | forge-std `Script` | read-only: `export` writes the claimant CSV for Studio; `compare` fails unless the allowlist root on SeaDrop is the root of the registry's rows (tree in `script/lib/AllowListTree.sol`) |
| `DirectBurnAdapter` | — | not yet written: tasks 3.7–3.8 (ACT-7, ACT-8); the one crediter, immutable, no owner |

**The transfer counter is the load-bearing idea (COL-3, COL-4).** `MintABear` increments `transferNonce[tokenId]` on every transfer and never on mint, and emits `TransferNonceAdvanced(tokenId, nonce)` in the same transaction as `Transfer`. `Activation` stores a level alongside the counter value it was recorded at, and treats it as void once the counter moves. The reset is therefore a consequence of the transfer rather than an action that must succeed — it cannot be skipped, and a defect in `Activation` cannot block a transfer. Do not replace this with a callback from the token; that pattern fails open. Indexers key the reset on `TransferNonceAdvanced`.

**No bear can be destroyed (COL-8).** `ERC721SeaDrop.burn` is `external` and not `virtual`, so it cannot be overridden; `_beforeTokenTransfers` refuses `to == address(0)` with `BurnDisabled`. ERC721A's `transferFrom` checks the zero address before the hook runs, so `MintABear` overrides `transferFrom` to refuse it with the same error, and `safeTransferFrom` routes through it. A bear sent to `0x…dEaD` stays in the supply; the royalty split excludes that address off-chain (ACT-10). When something inherited needs disabling, the hook is the lever.

**Supply is capped in code (COL-2).** `MAX_BEARS = 4444` is a constant checked on the mint path with `ExceedsMaxBears`, so raising the Studio-writable `maxSupply` cannot increase the supply delivered. `getMintStats` is final and advertises `maxSupply`, so the runbook sets `maxSupply` to exactly 4,444; at that value SeaDrop's own `MintQuantityExceedsMaxSupply` fires first, and `ExceedsMaxBears` binds only when Studio raises it.

**Metadata is stock SeaDrop (COL-5).** `tokenURI(id)` is `baseURI` followed by `id` when `baseURI` ends in `/`, and `baseURI` alone otherwise (the pre-reveal shape). `baseURI`, provenance and royalties (5% to the pot, COL-6) are set through Studio. Nothing about a bear's level reaches its metadata.

**No token-bound accounts (COL-9).** ERC-6551 is not part of the collection and there is no account guard. It can be added later without any change to `MintABear`, because the canonical registry derives an account address from `(chainId, tokenContract, tokenId)` for any ERC-721; the one property that cannot be retrofitted is a token-side guard against sending a bear into a bear's account.

**ERC-721C (COL-7).** `ERC721SeaDrop` implements `ICreatorToken`. The deploy script (OPS-2) sets the validator to Limit Break V3 `0x721C002B0059009a671D00aD1700c9748146cd1B` with its zero-state policy — security level 0, list 0, OpenSea's SignedZone as authorizer — so a holder's own transfers always pass and a sale settles only through OpenSea or a Payment Processor venue. One owner call, `setTransferValidator(address(0))`, lifts enforcement and one restores it (OPS-6). Never security level 5 or above. OpenSea's handling of a validated collection on 4663 is proven on testnet and with one team-bear sale before the drop page is published. The unit tests model the policy with `test/mocks/MockTransferValidator.sol`; the real V3 is the auditor's fork obligation (Fork-2 in `test/MintABear.tree.md`).

**The whitelist is an on-chain registry (WL-3, CQ-18 option A).** MINT's backend signs a short-lived voucher `Claim(wallet, allocationIndex, account, deadline)` when the wager API confirms a threshold; the wallet sends `claim` itself and pays the gas. `claim` checks, in order: `NotClaimant`, `BadSigner`, `Expired`, `CampaignClosed`, `SoldOut`, `WalletLimit`, `WrongAllocation`, `AccountLimit`. `allocationIndex` must be the wallet's next allocation, which makes every voucher single-use without a nonce. `account` is a hash of the getminted.io account id. The owner (MINT's admin, set in the constructor) can only `setSigner` and `setWindow`; nothing removes, reassigns or adds a claim. After the campaign, `script/WhitelistExport.s.sol` exports the CSV loaded into Studio and `compare` checks the root Studio set against the registry; `AllowListTree` builds the tree the way SeaDrop's reference tests do (merkletreejs, sorted leaves and pairs), which rehearsal item 3 confirms against Studio on 46630. The 48-hour gap between `closeAt` and the whitelist stage is a deploy value, not enforced on-chain.

**Ownership (COL-10).** SeaDrop's `TwoStepOwnable`: Calea deploys, calls `transferOwnership(admin)`, and MINT's admin calls `acceptOwnership`. Afterwards Calea holds no role. Never call `renounceOwnership`: Studio configuration would freeze for good.

## Commands

```shell
forge build --sizes        # compile + size report (what CI runs)
forge test                 # full suite
forge fmt --check          # format gate — run before pushing
forge coverage --no-match-coverage 'test/|lib/'
slither . --exclude-dependencies
```

The coverage filter `'test/|lib/'` also hides `script/lib/`; `forge coverage --no-match-coverage '^(test|lib)/'` shows `AllowListTree` as well.

Whitelist export and check (read-only, nothing broadcast; writes under `exports/`, which is gitignored):

```shell
forge script script/WhitelistExport.s.sol --rpc-url $RPC --sig "export(address,string)" $REGISTRY exports/whitelist.csv
forge script script/WhitelistExport.s.sol --rpc-url $RPC \
  --sig "compare(address,address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool))" \
  $REGISTRY 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5 $COLLECTION "(0,0,$START,$END,1,4444,$FEE_BPS,$RESTRICT)"
```

Targeting a single test:

```shell
forge test --match-contract MintABearCreatorTokenTest
forge test --match-test test_transfer_emitsTheResetEvent_withALevel -vvvv
```

Reproduce a CI run locally: `FOUNDRY_PROFILE=ci forge test`.

## Setup

Three submodules: `lib/forge-std`, `lib/seadrop`, `lib/solady`. After a fresh clone run `git submodule update --init --recursive`. SeaDrop carries its own nested libs (ERC721A, OpenZeppelin, solmate, utility-contracts), which the remappings in `foundry.toml` point into — do not install those separately.

## Configuration notes

- **`solc_version = "0.8.17"` is forced, not chosen.** SeaDrop declares `pragma solidity 0.8.17;` — an exact pin, not a caret range — so everything in its import graph must compile at that version. This deviates from the `^0.8.20+` convention in the global instructions; the mandated dependency is the justification. Do not "upgrade" it without removing SeaDrop.
- **`evm_version = "london"` follows from that.** `paris` only arrived in solc 0.8.18, so london is the ceiling here. No PUSH0, no transient storage. Nothing in this codebase needs them and the bytecode is maximally portable as a result.
- `optimizer_runs = 1_000_000` matches SeaDrop's own setting. Robinhood Chain's contract size limit is ~96 KB (four times Ethereum's), so size is not a constraint — `MintABear` is 20 KB and fits under even the Ethereum limit.
- `[profile.ci]` raises only fuzz/invariant runs. Keep build settings in `[profile.default]` so `forge build --sizes` matches between local and CI.
- **`forge build` prints forge-lint warnings and they count against the warning-free gate.** There are none; forge-lint *notes* remain on the test mock `MockMNTD` (constant naming) and on the whitelist export's file I/O (`unsafe-cheatcode` — the I/O is the script's purpose). Do not silence a lint with a directive.

## Test conventions

Developer scope is **deterministic unit tests only**, with a BTT tree per contract (`test/<Contract>.tree.md`) and a `/* Scenario: Given / When / Then */` block in every test. A test that satisfies a requirement's Scenario opens its block with `Scenario: COL-n — <Scenario title>` and quotes the spec's lines; the tree leaf cites the same id. Tests that only read state are declared `view`: solc's mutability warning would otherwise fail the warning-free build gate. Coverage gate: **≥90% line, ≥80% branch**; the suite sits at 100% on both, so a drop means something was added without a test.

`test/poc/` holds proofs of concept from security review, kept as regression guards with the finding written up in the contract's NatSpec. A PoC that gets fixed is inverted to assert the refusal rather than deleted; when the code it depended on leaves, the PoC keeps the assertions that survive and its NatSpec says what changed.

**Do not write fuzz, invariant, mutation, formal-verification or fork-test harnesses.** Those belong to the auditor and are run independently; dev-authored invariant suites anchor the reviewer and create a false "invariants done" signal. The trees may *document* INV-N and Fork-N obligations, and they do — leave them documented and unimplemented. Deterministic single-scenario tests that happen to pin an invariant are in scope.

Write specs and docs as **final state, not changelog** — no "was X, now Y" in body prose.

## CI gates

Push and PR run `forge fmt --check`, `forge build --sizes`, `forge test -vvv`, then the spec lint and the generated-prose check. All must pass.
