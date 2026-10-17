# Integrity check — 18 October 2026 (run 17 October), before `tasks.md` 5.4

**Scope:** the internal docs, YouTrack and the code, checked against each other before 5.4 (OPS-2,
`runPrizeVault`). This is a report only; nothing was fixed.

**State of NFT** (after `git fetch --prune`):
- `release/1.1` is `d6f2022` (#22 merged). Since the last check, #16, #18, #19, #20, #21 and #22
  have merged, all on 17 October.
- `feat/contracts` is `c5f053b`, in `~/trees/NFT-every-bear`. It is local only, 0 behind and
  10 ahead (the vault: RAF-35, 36 and 37 with their merges, plus the merge of `release/1.1`).
  `origin/feat/contracts` does not exist (#17's merge deleted it), so the vault PR's push
  recreates it.
- `~/trees/NFT` is on `feat/contracts-client-workspace` `363b269`, which is merged (#20). Its
  remote branch is gone.
- `mnt/RAF-18` is `ce7606a`: 56 behind and 1 ahead.

## Checks

| Check | Result |
|---|---|
| `board.sh --dry` | 0 created, 0 refreshed; 81 CURRENT; WL-1 and WL-5 tracked but excluded; validate and lint OK |
| `render_calea_prose.py --check` · `build_client_doc.py --check` | both current; §10's open items match the register |
| `tasks.md` against the board | Unticked lines: 0.3 (MNT-154, In Progress), 4.2 (MNT-59, In Progress), and 5.4–5.6 (no issue yet; each becomes a Defect when picked). 5.1–5.3 are ticked, and MNT-166, 167 and 168 are Done. Besides those, only CQ-2 (MNT-73) is In Progress. Nothing is In Review |
| Open PRs | only #23 (`feat/webapp-nav-wallet-fixes`, MINT's, MERGEABLE): `apps/webapp`, `packages/wallet`, `packages/ui`, `packages/whitelist-client`, `AGENTS.md`, one `apps/whitelist-api` file. It does not touch `packages/contracts*` or `pnpm-lock.yaml` |
| Private text in NFT since `f1f9ce6` | None on `feat/contracts`. The only matches are the word "handover" and MINT's own `MNT-1024` |
| Worktrees and branches | `~/trees/NFT` (merged PR B branch) and `~/trees/NFT-every-bear` (`feat/contracts`, untracked `packages/contracts/broadcast/`: keep it). Local branches: `main`, `release/1.0`, `release/1.1`, `feat/contracts`, `feat/contracts-client-workspace` (merged), `mnt/RAF-18` |
| Gates on `feat/contracts` `c5f053b` | `fmt --check` OK. `build --force --sizes`: 0 warnings (`PrizeVault` 11,794 B). 308 tests pass. Coverage is 100% on lines, statements, branches and functions. Slither: 47 results (4 Medium, 15 Low, 28 Informational), no High or Critical. `verify.sh`'s dry run matches the expected output, and `verify.test.sh` passes |
| Client in the workspace | `npx pnpm@12.14.0 install --frozen-lockfile` is up to date. `pnpm run check` passes 134/134 (18 files) |
| `check_scenario_quotes.py` · `check_tree_tests.py` (`--code-root NFT-every-bear/packages`) | 44 / 0 · 26 / 0 |
| `PrizeVault` against RAF-14, 16, 17 and 32–37 | Every error (19), event (6) and public read is named in those requirements. The only unnamed parts are the receiver hooks and Solady's `cancelOwnershipHandover`; the interface pin covers both (`PrizeVault.t.sol:1333–1340`), as it does for the box and the draw |
| The vault against README, DESIGN, the tree and CLAUDE.md | NFT's README has the vault's row and the funding paragraph. DESIGN mentions the vault 22 times. `PrizeVault.tree.md` has INV-32…36 and the claim and release obligations, and the global INV list names INV-32…36. CLAUDE.md's file-table row matches the code. RUNBOOK and the client README do not mention the vault yet; that is 5.4 and 5.6 |
| CREATE2 deployer `0x4e59…956C` (5.4's base) | Code is present on all eight chains, each RPC answering its own chain id: 4663, 46630, 1, 11155111, 33139, 33111, 8453 and 84532 |
| This repository | Clean apart from `.memsearch/` and `lib/`. `main` is 1 ahead of `origin/main` (`999f4af`), not pushed |

## Findings

### New, sorted by what blocks the next Task

**IC-22. MINT restructured the workspace on 17 October, and our docs describe the old layout.**
- #21 and #22 replaced `apps/mintabear`, `apps/claim` and `apps/swap` with one Next.js 16 app,
  `apps/webapp`. In it, `/nft`, `/claim` and `/swap` are feature folders, tests use `node:test`,
  and it needs Node 24. `apps/getminted` (#19) has also gone.
- MINT added CI, `.github/workflows/ci.yml`. It runs the webapp, the shared packages, the whitelist
  API and the generator. It does not run `packages/contracts` or `packages/contracts-client`.
  `AGENTS.md` now says "A PR is not done until CI is green and the Railway PR environment
  deploys". `AGENTS.md:9` calls `packages/contracts*` "Kalea's".
- What is now stale here:
  - CLAUDE.md:25 lists the Railway-watched paths as `apps/mintabear/**`, … They are now set per
    service: `apps/webapp`, `apps/whitelist-api`.
  - CLAUDE.md:161 and HANDOVER:135 say "`../NFT` has no CI". It has CI now, just not for our
    packages, so our gates stay local.
  - HANDOVER:14–24 still describe PR B as "no PR open yet".
- Effect on 5.4: none. It touches only `packages/contracts`. The vault PR's description should
  say that MINT's CI does not cover these packages and that our gates ran locally.
- **Proposed:** correct CLAUDE.md:25 and :161 and the HANDOVER lines in one commit, then mention
  "Kalea's" to MINT. **Owner:** Calea. Blocks nothing.

**IC-23. `tasks.md` 0.3's staging hand checks cannot run as written.**
- Two of the remaining checks need an app that imports `@mint/contracts-client`: MNT-170's pasted
  address and MNT-171's `WRONG_CHAIN`. No app does (`git grep` over `apps/` and
  `packages/wallet`), and `apps/mintabear` has gone.
- The Privy login is the only check that still means something. It tests whether #20's lockfile
  moved the wallet stack, and it now runs on `apps/webapp` staging.
- **Proposed:** tick 0.3 and close MNT-154 on the person's word after one Privy login on the
  webapp's staging. Move the two client hand checks to the first app that imports the client
  (5.6, or MINT's level-up page). **Owner:** the person.

**IC-24. MINT's prompts (IC-17) target apps that no longer exist.**
- Prompt 1 (lines 10–15) still asks MINT to wait for #17 and PR B, which are both merged.
- Prompts 1–3 build in `apps/mintabear` or `apps/claim`:
  - prompt 1:71 and :107;
  - prompt 2:29 and :35 ("the same dependency versions as `apps/claim`");
  - prompt 3:44 and :129.
- They should name `apps/webapp`'s feature folders and its conventions (`AGENTS.md`: `server/`
  with `server-only`, a route under `app/`, `AppNav.tsx`, `seo.ts`, `node:test`).
- This supersedes IC-17. **Proposed:** rewrite the prompts before they are sent, together with
  the vault calls from 5.6. **Owner:** Calea.

**IC-25. `mnt/RAF-18` is now 56 behind, across the restructure (grows IC-21).**
- The worker branch keeps `apps/box-worker` out of the workspace with `!apps/box-worker` and
  takes its packaging from the whitelist API.
- Since then the workspace has moved to pnpm 12 (`allowBuilds`, `minimumReleaseAge`) and Node 24,
  and gained CI. The merge at 4.2 is therefore more than a lockfile regeneration: the worker's
  Dockerfile, its Node version and whether CI should run it.
- Not blocking 5.4. **Owner:** Calea, at 4.2.

**IC-26. `PrizeVault` adds three forge-lint notes that CLAUDE.md does not list.**
- The notes are `asm-keccak256` at `PrizeVault.sol:472–474` (`_assetKey`). They are notes, not
  warnings, so the build gate is unaffected.
- CLAUDE.md's "Configuration notes" lists every other remaining note.
- **Proposed:** add the line at the next CLAUDE.md edit. Keep `abi.encode` here: the hash runs
  once per entry, and readability beats a few gas. **Owner:** Calea.

### Carried

| Item | Where it stands |
|---|---|
| IC-8 | open: `check_scenario_quotes.py` still does not print the requirements no test quotes |
| IC-9 | open: `docs/tools/` still lacks `fold_archive.py` and `schema_drift.sh`; re-run ai-stack's `install.sh` here |
| IC-10 | Partly done: NFT's README and DESIGN now describe the vault. Still stale: `PrizeDraw.sol:21–22` ("Prizes are paid from MINT's prize wallet"), `contracts-client/src/prizeDraw.ts:11`, and `contracts-client/README.md:267`. The NatSpec changes `PrizeDraw`'s bytecode metadata against the rehearsal deploy; the two client lines go with 5.6 |
| IC-11, IC-12 | open, not re-examined (the client's error-table generator; the ai-stack `/mnt:done` template) |
| IC-13 | Open: CLAUDE.md:7 still says "prizes are paid from MINT's wallet on each prize chain". Fix it with IC-22 |
| IC-15 | open: `docs/SPECIFICATION.md:110`, "Prize wallet … holds and pays prizes"; before the next client document |
| IC-16 | Open: MNT-95 (Sourcify on 46630) is Open, though the rehearsal verified all four contracts. Closing it (Done) is the person's call |
| IC-17 | superseded by IC-24 |
| IC-19 | open: `openspec/decisions.md:749` and `OPEN-QUESTIONS.md:749`, "there is no vault to claim from" |
| IC-20 | closed: #16, #19 and #20 merged |
| IC-21 | grown into IC-25 |
| R-2 | open: RAF-27's Scenario title needs its own change |
| MNT-146 | open: MINT's multisig task, against CQ-12's single EOA |
| MNT-164 | Open: OPS-4's mainnet checks before the drop page |
| `tasks.md` 0.3 | see IC-23 |

## Verdict

The board, `tasks.md`, git and the specs agree. Every gate is green on `feat/contracts`
`c5f053b`, including the client inside MINT's pnpm-12 workspace. The vault as built matches
RAF-14, 16, 17 and 32–37, and nothing private is in NFT.

The drift comes from MINT's restructure of 17 October (IC-22 to IC-25). It affects our
description of their repository, the 0.3 hand checks and the prompts, but not the contracts.

**Nothing blocks 5.4 (OPS-2, `runPrizeVault`).** The CREATE2 deployer is present on every prize
chain and testnet. 5.4 should get a new worktree off `feat/contracts` `c5f053b`. The two old
worktrees are better reorganised first: switch `~/trees/NFT` to `feat/contracts`, move the
broadcasts, and remove `NFT-every-bear`, as the HANDOVER proposes. That can also wait until
after 5.4.
