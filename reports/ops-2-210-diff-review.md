# Differential review — OPS-2 / Defect MNT-210 (BearDrop's deploy step and runbook)

**Target:** `mnt/OPS-2-210` in mintdotio/NFT, stacked on `mnt/DST-6` (`48d747c`, merged in). Changed:
`script/Deploy.s.sol`, `test/Deploy.t.sol`, `test/Deploy.tree.md`, `docs/RUNBOOK.md`, `docs/DESIGN.md`.
**Spec:** OPS-2 (holders' $MNTD line, technical note). **Date:** 29 October 2026. **Reviewer:** Claude Code.

## Triage

| Change | Risk | Why |
|---|---|---|
| `deployBearDrop`, `runBearDrop` | MEDIUM (ownership) | Decides who owns the drop before the handover |
| RUNBOOK "Holders' $MNTD — BearDrop" | MEDIUM (operations) | The order that keeps MINT's funding safe (I-1) |
| DESIGN note, tree, tests | LOW | Documentation and tests |

## Analysis

- **Owner = `tx.origin`, the broadcasting wallet.** Forge broadcasts from the `--sender` or the
  single key, which is the script's `tx.origin`. Tests use forge's default sender. It is read back
  (`ReadBack("owner")`). It is not an authorisation by `tx.origin`, and Slither raises nothing.
- **Correct from the first block.**
  - The collection is checked, and nothing is created on a refusal.
  - Construction is the only write, in both `deployBearDrop` (the OPS-2 Scenario test) and
    `runBearDrop`, where a state diff counts the broadcaster's creates and calls.
  - The drop is read back empty.
- **No new config field.** The task line foresaw one; the chain config already holds `mntd`.
- **RUNBOOK.**
  - **Order:** deploy → list and hash → load and check → handover, then MINT reads `owner()` →
    fund → open → check again.
  - **Never fund before the handover** (I-1), with the reason given.
  - **Pause:** never near a window's end.
  - **Close and withdraw** after the window; the steps for a later round.
  - **Timing:** `load` reads every slot it writes (about 0.24 s a bear on the public RPC), and
    `--offline` is needed if forge stalls after a run.
- **Run on a fork of 46630.** Steps 1–4 ran as written, against the real `46630.json` and the
  rehearsal collection:
  - `runBearDrop` deployed the drop, owned by the broadcaster, with `MNTD` from the config;
  - `hash` printed `0x54e0…adba` for 4,444 × 500;
  - `load` sent 9 batches of about 16.6M gas (149.7M in all), and its check matched 4,444 bears
    with a total of 2,222,000;
  - the handover moved ownership to the admin.

  Step 5's transfer then failed because the public RPC had pruned the fork's state. That is an
  environment limit, and the transfer, open, claim, close and withdraw commands were each exercised
  in the DST-1…4 reviews.
- **Planted breakages.** Five; all caught after `runBearDrop`'s construction-only assertion was
  added. An extra call inside `runBearDrop` survived at first.

## Findings

None above Informational.

- **I-9: `load` is slow on a public RPC (Informational).** About 17 minutes, measured per slot. It
  runs once per round and is documented. `check` is fast through Multicall3 (MNT-205's change).
- **I-10: forge's post-run lookup (Informational).** On this machine forge waited about 10 minutes
  after each script. This is environment-specific, and `--offline` is documented. The testnet run
  (`tasks.md` 4.1) measures real timings.

## Coverage
- `Deploy.s.sol`: 100% lines and branches.
- `BearDropList.s.sol`: 92.9% lines, with the `vm.rpc` path proven live (MNT-205).
- Total: 99.0% lines, 98.7% statements.
