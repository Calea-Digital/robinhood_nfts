# Proposal

## Why

The worker could ask Chainlink again only after 24 hours. A re-request is no security measure:
every request stays valid and the first answer is used, at any delay. It matters in one case, a
request Chainlink drops, and there a day's wait holds every later opening in the queue for a day.
An answer normally takes seconds to minutes, so an hour without one already means something is
wrong; a shorter wait costs at most a duplicate request, cents on Arbitrum. A subscription run dry
is not helped by asking again (both requests wait for the top-up); its protection is the balance
alarm.

## What Changes

- `REREQUEST_AFTER` is 1 hour.

## Capabilities

### Modified Capabilities

- `mystery-box` (RAF): RAF-8, RAF-14, RAF-19.

## Impact

`PrizeDraw` on `mnt/RAF-8` (MNT-51, In Review): the constant, its NatSpec, the tests and the tree.
