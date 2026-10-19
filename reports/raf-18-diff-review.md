# Differential review: RAF-18 (MNT-59), the worker's payout step and workspace move

**Branch:** `mnt/RAF-18` in `~/trees/NFT-RAF-18`, from `ce7606a` (14 October, built up to prize
distribution).

**Changes reviewed:**
- `264035e`: `feat/contracts` `6cc0708` merged in. The conflict in `pnpm-workspace.yaml` was
  resolved to `feat/contracts`' version.
- `7e4257c`: the worker joins the pnpm workspace.
- `c912fe4`: the `vaultClaims` payout step.
- `8c9a8a4`: the measured gas in the README.
- The review fix below.

**Risk: medium.** The worker's key signs the claim tickets every vault accepts (it is each vault's
`signer`), and it records payouts on the draw.

## What the change guarantees

- **Who a ticket names.** It names the draw's recorded opener of the win (`OutcomeRecorded`), the
  only wallet the vault pays. Its EIP-712 domain names the prize chain and the vault, so it is valid
  there only. The test "ticket for the wrong winner" is caught.
- **When the worker signs.** Not before the prize chain's vault has the cycle registered and
  started, because until then the list can still be replaced and a ticket does not name the list
  (the RAF-36 review's rule). Not while that vault trusts another signer.
- **What it records.** `recordPayout(openIndex, chainId, txHash)` is sent only once the vault reads
  the prize claimed. `txHash` is the transaction of the vault's own `PrizeClaimed` for
  `(cycleId, openIndex)`; only the configured vault address is read. The draw itself refuses a
  second record (`AlreadyPaid`), so a race between two instances fails one tick and nothing is
  recorded twice.
- **State across a restart.** The ticket book is memory only. Signatures are deterministic
  (RFC 6979), so a restart serves the same tickets, and claims are read back from the vaults.
- **Serving.** `GET /tickets/:openIndex` and `GET /tickets?wallet=` return no secret: a ticket is
  useless to anyone but its winner. The README says to keep the service private behind the
  webapp's server.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | Low | A ticket signed before the vault's signer changed stayed in the book and kept being served, though the vault no longer accepts it | **Fixed:** the ticket is dropped when the vault does not trust the worker. Pinned in the not-the-signer test, and the planted breakage is caught |
| F2 | Info | The Docker image could not start: the client's `viem` is a peer dependency, and a production install does not link it | **Fixed in `c912fe4`:** the final image links the client's `viem` to the worker's. Proven with `docker build` and a run that stops on missing configuration as designed |
| F3 | Info | A lockfile re-resolution moved `@scure/bip32`'s `@noble/curves` from 1.9.7 to 1.9.1 | **Restored to 1.9.7.** The lockfile change is the worker's importer only (+22 / −0), and `--frozen-lockfile` passes |
| F4 | Info | MINT's CI does not build or test `@mint/box-worker`, as it does not for `packages/contracts*` | Accepted; the worker's check runs locally with our gates |
| F5 | Info | The testnet run used a test draw with `PLAYABLE` 4 so that wins occur; the real draw plays 4,444 | Accepted for the run; same bytecode, constructor argument only |

## Evidence

- Worker tests: 24 (7 new on a prize vault), all passing.
- Planted breakages on `vault-claims.ts`: 10, all caught (signing before the start, for another
  signer, a stale ticket kept, no record, no expiry, the wrong winner, both alarms, the wrong hash,
  a claimed ticket kept).
- Docker image built and run.
- RAF-18's Scenario passed on Robinhood Chain testnet and Arbitrum Sepolia through two cycles:
  four wins claimed and recorded with the claims' own transactions; `OutOfOrder` for a relay out of
  turn; bear 1 opening again in cycle 4. The board comment on MNT-59 has the transactions.
