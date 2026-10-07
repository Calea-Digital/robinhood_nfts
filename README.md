# MintABear — workspace

A 4,444-supply free-mint NFT collection on **Robinhood Chain (chain id 4663)**. Holders burn
$MNTD to raise a bear's activation level (0–5), which multiplies the reward rate their
off-chain MINT Status already pays. Activation resets when a bear changes hands. Holders also
open a mystery box with their bears, one shot per bear per cycle, decided by Chainlink VRF on
Arbitrum One; prizes are paid from MINT's wallet on each prize chain.

**This repository is the private workspace; the code is in MINT's repository,
[`mintdotio/NFT`](https://github.com/mintdotio/NFT)** — `packages/contracts` (Foundry: the
contracts, scripts, tests, `docs/RUNBOOK.md`, `docs/DESIGN.md`, `audit/`) and
`packages/contracts-client` (the typed TypeScript client). Clone it beside this one as `../NFT`
and start Claude Code here with `--add-dir ../NFT`.

**Start here: [`docs/HANDOVER.md`](docs/HANDOVER.md)** — current state, settled decisions,
accepted risks, and the questions still open with the client.

## What is here

| Path | Holds |
|---|---|
| [`openspec/`](openspec/) | the specification: one `spec.md` per requirement family, `decisions.md` (the `CQ-n` register), the active change `changes/tranche-1/` |
| [`docs/`](docs/) | `HANDOVER.md`; `SPECIFICATION.md` and `OPEN-QUESTIONS.md` (generated where their markers say so); `client/` documents; `prompts/`; `tools/` (spec tools, the client-document builder, `board.sh`, the scenario-quote check) |
| [`reports/`](reports/) | review reports |
| `.claude/` | the `/mnt:*` work-loop and `/opsx:*` spec commands |
| [`CLAUDE.md`](CLAUDE.md) | how the two repositories, the specification and the board fit together |

The board (YouTrack project `MNT`) is a function of `openspec/`: after a spec edit, commit and
run `docs/tools/board.sh`.

## Checks

```shell
python3 docs/tools/spec_tools/lint_spec.py --root .                 # spec lint (CI)
python3 docs/tools/spec_tools/render_calea_prose.py --root . --check # generated prose is current (CI)
python3 docs/tools/check_scenario_quotes.py                          # tests quote their Scenarios; reads ../NFT/packages
```

The code's gates (format, build, tests, coverage, Slither, the verify script, the client check)
run in `../NFT/packages/contracts` and `../NFT/packages/contracts-client`; see CLAUDE.md, "Gates".
