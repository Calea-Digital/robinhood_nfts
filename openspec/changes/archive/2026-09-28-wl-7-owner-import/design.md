# Design

## Context

`WhitelistClaim` (WL-3) records claims that holders make themselves with the signer's vouchers.
MINT asked for a list it writes itself (CQ-18), and has not yet answered Calea's counter-offer. The
contract is due on 29 September and is never audited (MINT, 28 September 2026). So the second
variant is a separate contract, and the existing reviewed one stays unchanged.

## Decisions

- **A separate contract.** `WhitelistClaim` is reviewed and stays as it is, and MINT deploys
  exactly one of the two. There is no mode switch inside one contract.
- **Reads shared with `WhitelistClaim`.** `TOTAL_SPOTS`, `MAX_PER_WALLET`, `spotsLeft`,
  `claimsOf`, `claimants` and `closeAt` have the same names and types, so `WhitelistExport.s.sol`
  and the client's allowlist tree work on either registry. `frozen()` is added so the export can
  tell a closed list from a sold-out one: a full import can still be corrected until `closeAt`.
- **Correction before the freeze, nothing after it.** A CSV import with no way to correct it would
  make a typo permanent. Before `closeAt` the owner already controls the whole list, so removing
  an entry adds no power it lacks. After `closeAt` nobody can change anything, and that is the
  guarantee the registry sells. Removal swaps the last row into the gap, so `claimants` stays
  dense and the export's paging does not change; the order of rows carries no meaning here.
- **The freeze is `closeAt`, not a separate call.** It is one clock that the deploy script checks
  against the whitelist stage (at least 48 hours before, as in WL-5). `setCloseAt` covers both
  early freezing and extension.
- **All or nothing per batch.** Any bad row reverts the whole batch, so a failed import leaves no
  partial state and can be retried once the CSV is fixed.

## Risks

- The owner decides the list: centralised by MINT's choice. The chain shows every write, with its
  events, until the freeze.
- An EOA owner key (CQ-12) could be used to write the list. It is readable on-chain and frozen
  after `closeAt`.
