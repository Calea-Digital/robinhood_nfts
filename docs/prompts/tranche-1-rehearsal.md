# Tranche 1 — rehearsal prompt (OPS-4)

Open a fresh Claude Code session in `~/trees/robinhood_nfts` once the reviewer has been through
the In Review Tasks and MINT's rehearsal values are in hand. The YouTrack connector must be
connected. Paste everything below the line.

---

Prepare and record the OPS-4 testnet rehearsal of MintABear tranche 1 on Robinhood Chain testnet
(46630), through the project's work loop. The rehearsal itself is human-led: I run anything that
signs or spends; you prepare, check, and record.

**Where things stand (2026-09-23).** Branch `tranche-1` (off `main` at `746acbe`, not pushed, not
merged) carries all four tranche-1 contracts and the scripts; `tasks.md` has 36 of 37 lines ticked,
the one open line being 4.4 OPS-4. Every other tranche-1 Task is In Review or Done on the board;
Subtask MNT-95 (Sourcify on 46630) is Open and closes during the rehearsal. Suite 218 tests at
100 % coverage, no build warnings, Slither no High or Critical. ACT-5 and OPS-2 were amended on
2026-09-23 (archived changes under `openspec/changes/archive/`).

**Read first:** `CLAUDE.md` (the loop, the architecture, the commands), `docs/HANDOVER.md`
("Next session", "Unknowns to settle by rehearsal", "Verified on-chain facts" — never re-research
those), `docs/RUNBOOK.md`, `openspec/specs/operations/spec.md` (OPS-4), and the four scripts:
`script/Deploy.s.sol`, `script/verify.sh`, `script/Enforcement.s.sol`, `script/WhitelistExport.s.sol`.

**Loop.** `/mnt:resume`, then `/mnt:next` claims OPS-4 (MNT-64); the plan in the claim is the
rehearsal checklist below. Record each step's transaction hashes, addresses and outputs as
comments on MNT-64 (and on MNT-95 for verification). A step that fails and needs a code change is a
Defect issue (`Reproduce` / `Expected` / `Observed`), fixed on its own `mnt/` branch through the
gates, never patched in place.

**Checklist (each step is mine to run; you give me the exact command first):**
1. `script/config/46630.json` from `example.json` with MINT's admin, signer, dates, testnet $MNTD
   and its `decimals`; `loadConfig` read back and checked.
2. `runWhitelist`, `runCollection`, `runActivation` with `--verify --verifier sourcify`; then
   `script/verify.sh 46630` exits 0 (MNT-95).
3. OpenSea Studio attaches to the collection; the admin's `acceptOwnership` completes (rehearsal
   item 1).
4. A whitelist claim end to end: a voucher signed with the testnet signer → `claim` → after close,
   `WhitelistExport.s.sol` `export` → CSV into a Studio allowlist stage → `compare` passes → a
   two-per-wallet allowlist mint (rehearsal item 3).
5. `Activation` unpaused for the window, a burn through the adapter against the testnet $MNTD to a
   credited level, paused again (rehearsal item 4).
6. `Enforcement.s.sol` `disable` then `enable` once, each emitting `TransferValidatorUpdated`.

**Stop and report when:** a step needs a value MINT has not given; a step fails for a reason
outside the scripts; or the checklist is done — then `/mnt:done` for OPS-4 with every recorded
output in the summary, tick 4.4, and update `docs/HANDOVER.md` "Where things stand".

**Never:** handle a private key yourself, broadcast to 4663 (mainnet), push, merge into `main`,
set Done, or edit a bridge-owned field.
