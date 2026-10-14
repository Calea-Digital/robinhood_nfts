# Proposal

## Why

MINT's answers at the meeting of 12 October 2026 (CQ-20): ApeChain holds prizes, and Base may
hold prizes in a later cycle, not the first. Prizes are paid by transfer from MINT's prize
wallet, an EOA with the same address on every EVM chain, and `PrizeDraw.recordPayout` accepts any
non-zero chain id. A prize chain therefore needs no contract and no code change.

## What Changes

- **RAF-33**: prizes on Robinhood Chain, Ethereum and ApeChain, and Base possibly in a later cycle;
  a chain is added through the prize list and the page; the technical note lists the chain ids
  and says no chain list is fixed in code.

No requirement is added or retired, and no Scenario changes.
