# Proposal

## Why

MINT's answer at the meeting of 12 October 2026 (CQ-23): the worker runs on MINT's
infrastructure, from an address MINT authorises, funded for gas. MINT's CTO sets up the key after
TGE. Calea builds the worker and writes the instructions (agreed 14 October). Only the client's
worker calls were specified (DEL-6), not a service that runs.

## What Changes

- **RAF-18**: the worker is a service Calea builds and MINT runs. It has no state of its own, its
  key is MINT's, its gas is ETH on Arbitrum One, and it raises alarms. Packaged like the whitelist
  API.
- **RAF-14, OPS-1**: MINT runs the worker.
- **OPS-5**: Calea keeps no contract role. The runbook covers setting up, funding and running the
  worker. The Scenario's last line follows.
- **DEL-10**: running the worker is not a Calea service.

No requirement is added or retired. OPS-5's Scenario changes its last line.
