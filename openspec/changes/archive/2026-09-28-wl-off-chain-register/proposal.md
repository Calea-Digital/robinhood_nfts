# Proposal

## Why

MINT answered the whitelist brief on 28 September 2026. The whitelist stays off-chain, in MINT's
backend, so that no contract has to be deployed or audited and holders need no gas. MINT
accepted Calea's conditions:
- a free wallet signature for pasted addresses;
- one merged row per wallet;
- a counter that cannot over-claim;
- the list frozen at least 48 hours before the whitelist stage;
- the whitelist stage first and not overlapping.

The team bears are minted from the owner wallet and are not on the whitelist.

## What Changes

- ADDED WL-8, the off-chain register. REMOVED WL-3, WL-6 and WL-7. MODIFIED WL-1, WL-2, WL-4 and
  WL-5.
- `compare` (WL-4) checks Studio's root against MINT's CSV instead of a registry.
- OPS-1 no longer has an eligibility signer. OPS-2 no longer deploys a registry. OPS-4 and OPS-5
  cover the CSV path.
- DEL-6, DEL-8, DEL-9 and DEL-10 drop the registries.
- COL-11: the whitelist stage is loaded from MINT's CSV.
- CQ-18 resolved. CQ-1, CQ-12 and CQ-14 updated.

## Capabilities

### Modified Capabilities

- `whitelist` (WL), `operations` (OPS), `deliverables` (DEL), `collection` (COL).

## Impact

- `script/WhitelistExport.s.sol`: a `compare` over a CSV file, with tests and tree.
- The client library builds proofs from a CSV. `src/WhitelistClaim.sol`, `src/WhitelistImport.sol`,
  their deploy entry points and the client's claim and import modules stay in the repository,
  unused and undelivered.
- The documents: §2, §4, §8 and §10, the runbook's whitelist sections, HANDOVER, CLAUDE.md and the
  client document.
