# WL-7 differential review — `WhitelistImport` (MNT-134)

**Range:** `8cf683c..mnt/WL-7` (99c5217, 51b8123, and the fix commit that carries this report).
**Strategy:** small diff, DEEP. 35 files; one HIGH-risk file (`src/WhitelistImport.sol`: an
owner-writable list that becomes the whitelist stage's allowlist). The rest are MEDIUM (the deploy
entry point, the export's registry detection, the client's plan) or LOW (tests, trees, docs).
**Deletions:** 35 lines, none of them security code. `Deploy.deployWhitelist`'s gap check moved into
`_requireCloseBeforeStage`, unchanged. `WhitelistExport.checkedRows`' finality check moved into
`_requireFinal`, which keeps the `WhitelistClaim` branch exactly as it was.
**Coverage:** `WhitelistImport` has 100% line, statement, branch and function coverage, and so
does the whole suite (393/393 lines, 80/80 branches). The client has 133 tests, 11 of them new.
**Confidence:** high for the contract and the scripts; medium-high for the client plan, which
depends on no other writer acting between plan and send (see F-3).

## Owner's powers

| | Before `closeAt` | After `closeAt` |
|---|---|---|
| `addAllocations` | any wallet, within 2 per wallet and 1,000 in all | `ListFrozen` |
| `removeAllocations` | any listed wallet | `ListFrozen` |
| `setCloseAt` | any time not in the past, later or earlier | `ListFrozen` |
| `transferOwnership` / handover | yes | yes, but the new owner can change nothing |
| `renounceOwnership` | `RenounceDisabled` | `RenounceDisabled` |

Before the close the owner decides the list alone, and that is WL-7's premise, not a defect.
After the close nothing can change: every writer goes through `_requireOpen`, and no other path
writes `claimsOf`, `_claimants`, `_position` or `_spotsClaimed`.

## Checks made

- **Swap-and-pop.** The removed wallet's slot takes the last row, the moved row's `_position` is
  rewritten, and the tail is popped. When the removed wallet is itself the last row, it writes
  itself into its own slot and the final `delete _position[wallet]` clears it. So the last row,
  the only row and a batch of several are all consistent. The tests cover each case and check
  that the list stays dense with each wallet listed once.
- **Narrow arithmetic.** `held ≤ MAX_PER_WALLET` and `claimed ≤ TOTAL_SPOTS` hold at every write,
  so `MAX_PER_WALLET - held` (uint8) and `TOTAL_SPOTS - claimed` (uint16) never underflow.
  `count` is compared with the room left before it is added, so `held + count` stays at most 2,
  and a count of 255 reverts `WalletLimit`, never a panic (tested). There are no narrowing casts,
  so forge-lint's `unsafe-typecast` is clean.
- **All or nothing.** Every refusal reverts the whole call, and `_spotsClaimed` is written once
  at the end.
- **Registry detection in the export.** `try WhitelistImport(r).frozen()` succeeds only on a
  contract that answers `frozen()`. `WhitelistClaim` has no such function and no fallback, so
  it lands in `catch` and keeps its old rule (closed, or sold out). A sold-out import is still
  refused until `closeAt`, because it can be corrected until then (tested). An address with no
  code already fails at `closeAt()` before the `try`.
- **Deploy.** `runWhitelistImport` reads only `admin`, `closeAt` and `whitelistStageAt`. It
  refuses a zero admin and a close less than 48 hours before the stage, and makes no call after
  construction (tested with state-diff recording, as OPS-2 is).
- **Gas.** A 200-row `addAllocations` of new wallets costs 14.0M gas (about 70k per row), and a
  200-row `removeAllocations` 0.9M. The client's default batch of 200 fits Robinhood Chain's
  Arbitrum-style per-transaction limit with room to spare.
- **Slither.** It adds one `locked-ether` Medium from Solady's payable ownership functions, the
  same accepted pattern as `WhitelistClaim` and `Activation`, stated in the NatSpec. Also:
  `timestamp` (Low, intended: the freeze is keyed on time per OPS-7) and `costly-loop`
  (Informational). No High or Critical.

## Findings

**F-1 — `planImport` trusted rows passed directly (Low, fixed).** The facade's `plan(rows)`
accepted rows that had not come through `parseAllocationCsv`. A duplicate wallet or a count of
3 produced a plan whose `total` and batches were wrong. The contract would have refused the
bad batch, but only after earlier batches had been mined. Fixed: `planImport` checks the rows
against the file's rules before reading the chain. Test: "refuses rows passed directly…".

**F-2 — `setCloseAt` can keep the list open indefinitely (Informational, by design).** The owner
can move the close as far out as a `uint40` allows, and until then the export refuses and the
list stays mutable. This is inherent to "correct before the close". The runbook keeps the close
at least 48 hours before the whitelist stage. The stage cannot sensibly open before the export,
so an unfrozen list delays the stage rather than corrupting it.

**F-3 — A concurrent writer can make a planned batch revert (Informational).** The plan is
computed from the chain at one moment. A second admin session writing in between can make a
later batch revert with `WalletLimit` or `NotListed`. Because the list is all or nothing per
batch and the plan is idempotent, planning again repairs it; the README says so. There is no
on-chain consequence.

**F-4 — `AllocationsAdded.total` is the wallet's new holding (Informational, interpretation).**
WL-7 names the argument `total` without saying whose. It is emitted as the wallet's allocations
after the add, which lets an indexer rebuild `claimsOf` from events alone. The spec should say so.

## Deviations from WL-7's text

- The constructor refuses a close in the past (`InvalidWindow`), the same rule as `setCloseAt`.
  WL-7 names no constructor refusal beyond the zero owner.
- `AllocationsAdded(wallet, count, total)`: `total` is the wallet's holding after the add (F-4).
- The export refuses an unfrozen import with the existing `CampaignStillOpen(closeAt, spotsLeft)`,
  not a new error.
