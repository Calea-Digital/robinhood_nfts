# Proposal

## Why

The WL-7 build (MNT-134) settled three details that WL-7's text left open.

## What Changes

- The constructor also refuses a close in the past (`InvalidWindow`).
- `AllocationsAdded`'s `total` is the wallet's allocations after the add.
- The export refuses a list that is not yet frozen, with `CampaignStillOpen`, even when it is full.

## Capabilities

### Modified Capabilities

- `whitelist` (WL): WL-7.

## Impact

Spec text only; the code already does this (merge `451554c`).
