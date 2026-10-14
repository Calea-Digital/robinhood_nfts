# Integrity check — session of 15 October 2026 (run 14 October)

**Scope:** the session's work in both repositories, the board, and the spec-side checks.

**State of NFT** (local only; nothing pushed):
- `feat/contracts` `10279d5` = `release/1.1` `f1f9ce6` plus MNT-160 (`5ef3736`) and MNT-161 (`10279d5`), both Done on the person's accept.
- Waiting for review:
  - `mnt/OPS-4-prep` `8e8203b`: MNT-162 and `tasks.md` 0.5.
  - `mnt/OPS-2-163` `55fc4bc`: MNT-163 and `tasks.md` 0.4. Stacked on `mnt/OPS-4-prep`.
  - `mnt/RAF-14` `73273fa`: MNT-55 and `tasks.md` 4.1.
- In progress, not for review:
  - `mnt/RAF-18` `ce7606a`: MNT-59, gated by CQ-22.
  - `feat/contracts-client-workspace` `7087acc`: PR B, MNT-154, `tasks.md` 0.3.

## Checks

| Check | Result |
|---|---|
| `openspec validate --specs` | 6 passed (one existing wording warning on WL-8) |
| `lint_spec.py` | OK: 60 active requirements, 24 decisions |
| `render_calea_prose.py --check`, `build_client_doc.py --check` | current; §10 matches the register |
| `check_scenario_quotes.py` on `feat/contracts` | 40 / 0 (37 / 3 this morning); `mnt/RAF-14` 41 / 0 |
| `check_tree_tests.py` | 26 / 0 |
| `board.sh --dry` | 78 CURRENT, no drift, nothing new |
| Gates on each branch (fmt, 0 warnings, tests, coverage 100/100, Slither 41 with no High or Critical, `verify.sh`, client 104) | green: `feat/contracts` (246 tests), `mnt/OPS-4-prep` (253), `mnt/OPS-2-163` (258), `mnt/RAF-14` (247) |
| `apps/box-worker` | typecheck; 17 tests; a smoke run of `src/main.ts` on anvil |
| PR B | lockfile +345 / −0; both Railway images built; whitelist-core 12, mintabear 22, nft-generator 24, claim 75, whitelist-api 68 |

## Found and filed this session

- **MNT-162** (Defect, OPS-2). `runActivation` against the test $MNTD fails in forge's London simulation (`NotActivated`, PUSH0). The reference token is also compiled for `cancun`, so mainnet's 20 October deploy was exposed too.
  - Fixed by `evm_version = "cancun"`. solc 0.8.17 still gets `london`, and all four contracts' bytecode and metadata are byte-identical to before.
  - In Review.
- **MNT-163** (Defect, OPS-2). There were no deploy entry points for the box and the draw, and nothing held the draw's `playable` at 4,444 (MNT-161's review, R-1: a draw deployed with 4,222 wedges the in-order relay).
  - Now the script passes 4,444 itself, checks the coordinator first and reads every value back.
  - The fork run caught an EIP-7702 delegated account passing a code-length "is a coordinator" check; it is now a low-level `s_config` read.
  - In Review.
- **MNT-160 review.** Five leftovers fixed before the merge (dead aliases, stale fixture, audit-response and runbook text).
- **MNT-161 review.** Carried forward:
  - R-2: RAF-27's Scenario title "Opening freezes the odds" is stale; it needs a spec wording change.
  - R-4: no test fills a message from decoded revert arguments.
  - R-5: `idsLeft` starts at 4,444 every cycle, so if the mint doesn't sell out, some prizes per cycle go unawarded.

## Open, by owner

| # | Item | Owner | When |
|---|---|---|---|
| O-1 | Review `mnt/OPS-4-prep`, then `mnt/OPS-2-163`, then `mnt/RAF-14` | the person | before 16 Oct for the first |
| O-2 | The rehearsal wallet's address (`46630.json`, `421614.json`) and test $MNTD for it | the person; MINT | 16 Oct |
| O-3 | The VRF subscription id (`421614.json`, `42161.json`) and the VRF settings (ETH, 300,000 gas, 3 confirmations) | Calea | before the draw's deploy |
| O-4 | The collection's name and symbol (`MintABear` / `BEAR` in the configs): fixed at deploy | the person, with MINT | before 19 Oct |
| O-5 | CQ-22. Then RAF-18's payout step, and RAF-18's Scenario on the testnets | MINT; then Calea | needed 17 Oct |
| O-6 | PR B: push and PR on the person's word; Lorenzo merges; one Privy login on staging. It touches `pnpm-lock.yaml`, so staging redeploys | the person; Lorenzo | 20–21 Oct |
| O-7 | After PR B: the worker joins the workspace (`workspace:*`, its exclusion dropped, its lockfile importer) | Calea | after PR B |
| O-8 | R-2 wording change through `/opsx:propose` | Calea | any time |
| O-9 | The worker's README funding figure (0.02 ETH) waits on the gas per relay measured in the rehearsal | Calea | rehearsal |

## Verdict

The spec, register, board and code agree. Every branch's gates are green. `feat/contracts` holds only accepted work, and nothing was pushed.
