# DEL-6 differential review — `packages/contracts-client`

**Scope.** `git diff main...mnt/DEL-6`, excluding the generated `src/abi/*.ts` and
`package-lock.json`: the TypeScript client (mint, allowlist tree, whitelist claim, voucher
backend, burn, link, transfers, events, royalty split, `bin/split.ts`), the CI job,
`test/mocks/MockOzMNTD.sol`, `docs/tools/check_scenario_quotes.py`, and doc pointers in
`CLAUDE.md` and `docs/HANDOVER.md`. No production Solidity changed.

**Method.** The package is new, with no earlier version to compare against, so this is a
risk-first read rather than a regression hunt. Files that build value-moving calls or handle keys
were rated HIGH (`mint.ts`, `activation.ts`, `transfer.ts`, `backend.ts`, `whitelist.ts`,
`split/*`, `calls.ts`, `errors.ts`) and read adversarially line by line; the rest were checked
against their tests. Blast radius: the package is the only call surface MINT's play page, voucher
backend and royalty split use (CQ-19), so a wrong amount, recipient or split input reaches every
holder. The Forge gates were re-run afterwards: Slither's results equal `main`'s (17
Informational, 4 Low, 2 Medium — the accepted `locked-ether`).

**Self-review caveat.** The reviewer is the author. The fixes below were found on this pass and
each has a test. An independent read by the human reviewer is still the gate.

## Findings

| # | Severity | Title | Status |
|---|---|---|---|
| F-1 | Medium | Events-mode split silently drops bears missing from the logs | Fixed |
| F-2 | Low | `accountHash` lower-cased every id, merging case-distinct system ids | Fixed |
| F-3 | Low | `planBurn` passed an out-of-range level to the contract | Fixed |
| F-4 | Informational | Snapshot paging reported RPC failures as "exceeds the gas budget" | Fixed |
| F-5 | Informational | CI ran dependency install scripts | Fixed |
| I-1 | Informational | `planBurn` / `planVoucher` are advisory pre-checks | By design |
| I-2 | Informational | Exact-amount `approve` assumes overwrite semantics | Accepted (CQ-2) |
| I-3 | Informational | `signVoucher` does not check the on-chain signer | Documented |
| I-4 | Informational | `readLinkStatus` reads one unbounded log range | Documented |

### F-1 — Events-mode split silently drops bears missing from the logs (Medium, fixed)

- **Impact:** in events mode, bears minted before the given `fromBlock`, or lost to an RPC that
  truncates `eth_getLogs`, were missing from the rows with no error. Their owners got nothing and
  every other holder was overpaid, while the split still summed exactly to the funding, so nothing
  looked wrong.
- **Root cause:** `src/split/inputs.ts` `rowsFromEvents` trusted the log replay as complete.
- **PoC:** `split.test.ts`, "refuses events-mode inputs that miss bears", uses
  `fromBlock = closingBlock − 2`. Before the fix this returned 0 rows instead of 8, and `computeSplit`
  then carried the whole funding with no error.
- **Fix:** `totalSupply` is read at the closing block, and the function throws unless the owned
  count equals it. No bear can be burned (COL-8), so every minted id has an owner.

### F-2 — `accountHash` lower-cased every id (Low, fixed)

- **Impact:** the canonicalization meant for typed emails (NFKC, trim, lower-case) was applied to
  every id. If MINT hashes a case-sensitive system id, two distinct accounts differing only in case
  would share one `account`, and so one two-per-account cap. The second person's claim would revert
  `AccountLimit` or `WrongAllocation`.
- **Root cause:** `src/backend.ts` `accountHash(serverKey, id: string)` always called
  `canonicalAccountId`.
- **Fix:** `accountHash(serverKey, { email } | { userId })`. An email is folded; a user id is
  trimmed only. The kind is prefixed (`email:` / `user:`), so an email and a user id that spell the
  same can't collide. Tests: "compares a user id exactly…"; HMAC known answer updated.

### F-3 — `planBurn` accepted any `targetLevel` (Low, fixed)

- **Impact:** a level of 0, 6 or a fraction reached `costToReach` and failed with a raw
  `InvalidLevel`, or a viem encoding error, instead of a clear refusal. There was no loss of
  funds, since the contract refuses.
- **Fix:** a `RangeError` for anything but an integer 1..5, before any read. Test: "refuses a
  target level outside 1..5".

### F-4 — Snapshot paging masked RPC errors (Informational, fixed)

- **Root cause:** any `eth_estimateGas` failure was treated as "does not fit". An RPC that refuses
  estimates at a past block halved the page down to 1, then threw "exceeds the gas budget", which
  pointed the operator at the wrong problem.
- **Fix:** the error for a single id now carries the RPC's failure as `cause`.

### F-5 — CI ran dependency install scripts (Informational, fixed)

- **Root cause:** `npm ci` in the new job ran every dependency's lifecycle scripts, a supply-chain
  exposure the suite doesn't need.
- **Fix:** `npm ci --ignore-scripts`. The full suite was checked to pass that way (94 tests).

### I-1 — Advisory pre-checks (by design)

- `planBurn` and `planVoucher` read the chain and then a transaction follows, so the state can
  change in between.
- The contracts stay the authority. `burn` re-reads the owner and counter in the same call, so a
  bear sold in between gives `NotBearOwner`. Two vouchers for one index both signed give
  `WrongAllocation` to the second claim (backend rule 2 in the README).

### I-2 — `approve` for exactly the amount (accepted)

- `planBurn` emits `approve(Activation, amount)` only when the allowance is short. That is correct
  for OpenZeppelin's overwrite semantics, which `Activation`'s NatSpec assumes of $MNTD.
- A token that requires a zero allowance first would need two approvals. Nothing to do unless
  CQ-2's token differs.

### I-3 — `signVoucher` does not read the chain (documented)

- A backend still signing with a rotated-out key issues vouchers that revert `BadSigner`. No funds
  are at risk.
- The README tells the backend to compare its key's address with `readCampaign().signer`.

### I-4 — `readLinkStatus` log range (documented)

- It reads one `eth_getLogs` from `fromBlock`. On an RPC that caps log ranges this fails.
- The README recommends serving it from an indexer (`ReferenceIndexer` is the reference).

## Checked and sound

- `mintPublicCall` / `mintAllowListCall`: `value = mintPrice × quantity`, which SeaDrop checks
  exactly (`IncorrectPayment` otherwise), so a stale price can't over- or under-pay. The recipient
  is the sender unless `minter` is given, and then only for an allowed payer. The allowlist leaf
  encodes the minter and the stage's eight fields in SeaDrop's order; it is pinned against the
  constants and merkletreejs.
- `approveBurnCall` approves `Activation` itself, never an adapter. `burnCall` burns only the
  sender's own $MNTD for the sender's bear.
- `planTransfer` refuses `from == to` and the zero address. Its warnings read the level and the
  link of `from`, which is right for an operator's transfer too.
- `decodeRevert` knows every error of the four contracts, deduplicated by signature, so bubbled
  reverts (for example `OwnerQueryForNonexistentToken` through `Activation`) decode by name.
  Revert strings decode as `Error`.
- `computeSplit` (bigint throughout):
  - `Σ floor(d·wᵢ/W) ≤ d` and `carried < wallets`.
  - Wallets are merged case-insensitively, and the dead-address exclusion is case-insensitive.
  - Duplicate, out-of-range and ownerless rows are refused.
  - With nothing eligible, everything is carried.
- Split inputs:
  - Both modes read at the closing block, not `latest`; the tests change state after the close.
  - Snapshot drops ownerless rows and refuses duplicate ids.
  - Events mode reads `weightOf` only for owned ids, so it never counts phantom bears.
- `accountHash`: HMAC-SHA256 through Web Crypto with a key of at least 32 bytes; the key never
  leaves the backend entry point, which the browser bundle does not import.
- Privacy: `account` is keyed, so the indexed `WhitelistClaimed` topic cannot be matched to a
  guessed email without the server key.

## Coverage limits

- Not reviewed: the generated ABIs (checked by the drift job instead) and the lockfile.
- Advisories are in dev-only dependencies (merkletreejs 0.2.32's `crypto-js`, `bn.js`, vitest's
  mocker). They are accepted, and none ships in the package.
- The real Limit Break V3's operator error, OpenSea's listing API, and Studio's root construction
  are outside the library's tests: Fork-2, MINT's integration, and rehearsal item 3.
