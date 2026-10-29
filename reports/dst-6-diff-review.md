# Differential review — BearDropList (DST-6)

**Target:** `git diff feat/contracts` on `mnt/DST-6` in mintdotio/NFT. New: `script/BearDropList.s.sol`,
`script/lib/CsvText.sol`, `test/BearDropList.t.sol` and `.tree.md`, `test/fixtures/bear-drop-csv/` (24 files).
Changed: `script/WhitelistExport.s.sol` (helpers moved out), `foundry.toml` (one read path).
**Spec:** DST-6. **Date:** 29 October 2026. **Reviewer:** Claude Code.

## Triage

| Change | Risk | Why |
|---|---|---|
| `_amount`, `_row`, `csvRows` | HIGH (value) | Turns MINT's whole-token text into the base units every holder is paid |
| `check` | HIGH (assurance) | The guard I-2 relies on: the only proof the chain matches the file before `openRound` |
| `load` | MEDIUM | Sends owner transactions; its embedded check stops a bad broadcast |
| `CsvText` extraction, `WhitelistExport` | MEDIUM (regression) | Live tooling for the whitelist's WL-4 check |
| `foundry.toml` | LOW | One more read-only path, a fixture directory |

## Analysis

**Parsing amounts.** The format is digits, then optionally one `.` and 1 to `decimals` digits. The value
is `whole × 10^decimals + fraction × 10^(decimals − places)`:
- whole digits are capped at 39 before parsing, so the multiplication cannot overflow for decimals ≤ 38;
- the result is refused above 2^128 − 1, so `setAmounts`' `uint128` total is the only bound left,
  and it reverts on its own;
- refused: `.5`, `5.`, two points, signs, exponents, separators, spaces, quotes and hex;
- the planted breakage on the two-point check survived at first, because no fixture held `1.2.3`.
  The fixture was added, and the breakage is now caught.

**Decimals.**
- `load` and `check` read `decimals()` from the drop's own `MNTD`. A 6-decimal stand-in proves the
  scaling follows it.
- `hash(path)` assumes 18, as the spec's signature takes no token. A different-decimal token would
  give a different hash, and `check` then reports `HashMismatch` once the round is open, so the
  assumption cannot pass silently.

**Check completeness.**
- `check` walks every id 1–4,444, so a bear left from an earlier load that the file omits fails with
  `AmountMismatch(id, onChain, 0)`. That is tested.
- Then it checks the round's total, and the `listHash` once the round is open.
- `TotalMismatch` cannot happen against `BearDrop` (INV-38), so it is reached with a stand-in drop.

**load.**
- Batches of 500 cost about 12M gas each. A full round is 9 transactions.
- It runs `check` after the broadcast block, in forge's simulation, so a mismatch reverts the script
  before anything is sent. A non-owner broadcaster is refused with `Unauthorized`.

**listHash.** It is `keccak256(abi.encode(uint256[] ids, uint256[] amounts))` over rows sorted by id,
pinned as `OK_HASH` for the client (MNT-211) to match. `abi.encodePacked` would differ, and that
breakage is caught.

**Refactor.**
- `trim`, `isUtf8`, `shown`, `isDigits`, and the private `escape` and `isPad`, moved verbatim into
  `CsvText`. `WhitelistExport` calls them.
- Its 17 tests pass unchanged, and `CsvText` shows 100% line and branch coverage through both
  suites.

**Tests.**
- 11 new tests, among them the DST-6 Scenario quote.
- Every format refusal has a fixture.
- 15 planted breakages are all caught, after the `1.2.3` fixture was added.

## Findings

No Critical, High, Medium or Low.

### I-7 — `hash(path)` assumes 18 decimals (Informational)
As analysed, a mismatch is caught by `check`. The RUNBOOK (MNT-210) should run `check` both before
and after `openRound`, so the hash printed and the hash stored are compared on-chain.

### I-8 — `check` reads 4,444 storage slots over RPC (Informational)
On mainnet each `amountOf` is one `eth_getStorageAt` from forge's fork, which takes about a minute
on a public RPC. This is acceptable for a once-per-round check. The RUNBOOK should name a provider
RPC.

## Coverage and confidence
High for the parser and the check. Not covered here: the deploy entry point (MNT-210) and the
client's `listHash` builder (MNT-211), which must equal `OK_HASH`.
