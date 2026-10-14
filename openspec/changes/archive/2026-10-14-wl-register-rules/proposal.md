# Proposal

## Why

MINT's whitelist register runs in production on `nft.getminted.io` (since 1 October 2026,
147 of 1,000 wagering spots claimed on 14 October). Its rules are MINT's of 1 October, as
built, and the specification doesn't state them all. The 27 October hand-off from the register to
Studio was agreed on 14 October.

## What Changes

- **WL-1**: the thresholds count wagering from before the first login up to $50 and everything
  after it in full; the first claim locks the account's wallet, and a wallet takes wagering spots
  from one account only.
- **WL-2**: Calea wrote the register's code at MINT's request; MINT deploys, runs and owns it.
- **WL-5**: the 27 October hand-off: other channels loaded before 12:00 UTC, the freeze and export
  by MINT's CTO at 12:00 UTC, the list and its checksum to Iñigo and Calea by 14:00 UTC.
- **WL-8**: wallet signatures, server-side wager reads, display-only team spots and the
  production addresses.

No requirement is added or retired, and no Scenario changes.
