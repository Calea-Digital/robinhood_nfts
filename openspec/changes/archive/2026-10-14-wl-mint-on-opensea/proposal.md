# Proposal

## Why

MINT's answers at the meeting of 12 October 2026:
- the whitelist campaign closes on 27 October at 12:00 UTC and the whitelist stage opens on
  29 October at 12:00 UTC (CQ-1);
- holders mint on OpenSea's drop page, not on getminted.io (CQ-19);
- the undeployed whitelist registries `WhitelistClaim` and `WhitelistImport` are removed now
  rather than after the whitelist stage (CQ-18).

With the mint on OpenSea's page, getminted.io sends no mint transaction, so the client library
needs no mint calls or allowlist proofs. It keeps the mint reads, so the page can show the
mint's progress.

## What Changes

- **WL-2**: Calea's part is the root check and the review; no mint proofs.
- **WL-4**: holders mint on OpenSea's drop page, which serves each wallet's proof; the client's
  `buildAllowList` is no longer part of it.
- **WL-5**: the window's times, 30 September to 27 October 12:00 UTC, stage 29 October 12:00 UTC.
- **DEL-6**: the play page reads the mint's progress; no mint calls or proofs.
- **DEL-8**: no undeployed registries to name.
- **DEL-10**: whitelist support is the check and the review.
- **OPS-4**: the rehearsal mints through OpenSea's drop page.

No requirement is added or retired. WL-2's Scenario drops the mint proofs from Calea's part.
The code removal (both registries, the deploy and export entry points that serve them, and the
client's mint writes, proofs and registry modules) is a `NONE` Task in `../NFT`.
