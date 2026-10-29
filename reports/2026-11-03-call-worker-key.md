# Call with MINT, Tuesday 3 November 2026 — the worker key

Prepared by Calea on 29 October 2026. On-chain facts were read on that day.

## 1. In one paragraph

`WORKER_PRIVATE_KEY` is the mystery box's single operational key. It was in Railway's environment
variables during Railway's incident, and Railway did not rotate environment variables. **Nothing of
value is exposed today**: the mainnet draw and the prize vaults are not deployed yet, and the key only
holds testnet roles. On mainnet, though, this key would control every prize. So we treat the current
key as burned, keep it on testnet until it is replaced, and make the mainnet key fresh, after the
incident. The call settles who makes it, where it lives, and how the box goes live.

## 2. What the key does

One externally owned account, MINT's, held only in Railway (a sealed variable) and in MINT's own secret
store. Calea never sees it.

| Role | Contract, chain | Calls |
|---|---|---|
| The draw's worker | `PrizeDraw`, Arbitrum One | `resolve` (relays each opening, in order), `recordPayout`, `applyOutcomes` |
| Every vault's signer | `PrizeVault`, each prize chain (Robinhood Chain, Ethereum, ApeChain) | signs each winner's EIP-712 claim ticket off-chain; no transaction |

It holds only ETH on Arbitrum One for gas (a full cycle of 4,444 relays costs about 0.014 ETH). It holds
no prize.

## 3. What a leaked key could do on mainnet

- **As the signer: claim every reserved prize.** A ticket names only the cycle, the opening, the prize
  and the claimer (`Claim(cycleId, openIndex, prizeIndex, claimer)`). The vault on a prize chain cannot
  see the draw on Arbitrum, so it accepts any ticket the signer signs, for any address, during a
  cycle's claim window. This is the serious case.
- **As the worker: relay openings that never happened.** `resolve` takes the opener from the worker. The
  draw cannot read Robinhood Chain, so a leaked key could relay made-up openings in turn, with its own
  address as the opener, and win prizes. It could also write false payout records.
- **It cannot:**
  - withdraw anything a vault holds unreserved;
  - pause, change an owner, or change a cycle's terms;
  - touch the collection, `Activation`, $MNTD or `BearDrop`.

What already limits the damage:
- Each vault's pause stops claims.
- `setSigner` and `setWorker` take effect at once, and from then on the old key's tickets fail.
- A cycle's claim window ends one hour after the cycle.
- The worker raises `not-the-signer` and `not-the-worker` when it no longer holds a role.

## 4. Where things stand (read on-chain, 29 October)

| What | State |
|---|---|
| `PrizeDraw` on Arbitrum One | not deployed; the VRF subscription is not created yet (`42161.json`: `subscriptionId` 0) |
| `PrizeVault` on the prize chains | not deployed; `vault.json`'s `signer` is unset (the deploy script refuses until it is set) |
| `MysteryBox` on Robinhood Chain | not deployed |
| Testnet `PrizeDraw` (Arbitrum Sepolia, `0x8108…0A05`) | worker `0x18D2…1Eff`, 10 transactions sent, about 0 ETH; owner is Calea's rehearsal wallet |
| `MintABear` on Robinhood Chain (`0x655e…cB28`) | 0 minted, `baseURI` empty, **owner still Calea's rehearsal wallet: MINT's admin has not called `acceptOwnership()`** |
| `Activation` on Robinhood Chain (`0xAbd2…159b`) | paused, owned by MINT's admin `0x1530…6141` |

## 5. What we recommend

1. **Retire the current key.** If `0x18D2…1Eff` is the Railway key, Calea points the testnet draw at a
   new testnet key and empties the old one's ETH. The current key is never used on mainnet.
2. **Make the mainnet key fresh, after the incident.** MINT runs `cast wallet new` (or any wallet tool
   that exports a raw key) on a clean machine. The private key goes straight into Railway as a sealed
   variable and into MINT's secret store. Only its **address** goes to Calea, by a channel other than
   chat. It is never pasted into chat or email.
3. **Harden Railway first:**
   - rotate every token and secret in the project, not only the worker's;
   - turn on 2FA for every member;
   - remove members who don't need access;
   - read the audit log for the incident window.
4. **Deploy with the new address from construction.** It goes into `vault.json`'s `signer`, and the
   vaults are created with it. `setWorker` on the draw follows from MINT's admin. So the key is never
   rotated live before launch.
5. **Keep the leak runbook to hand** (worker README, "Replacing the key"):
   - pause the vaults;
   - create and fund a new key;
   - `setWorker` and every `setSigner` from the admin;
   - replace the Railway variable and redeploy;
   - lift the pauses;
   - move the old key's ETH out.
6. **Optional hardening (a cost decision for MINT): split the two roles, or sign through a KMS.** One
   key was chosen on 15 October for simplicity. A signer kept in a cloud KMS (AWS or GCP), with the
   worker signing through it, means the raw key never exists in an environment variable. It needs a
   change to the worker and a KMS account on MINT's side.

## 6. The go-live sequence that follows

1. Calea creates the VRF subscription on Arbitrum One (CQ-17) and fills in `42161.json`.
2. Calea deploys `PrizeDraw` (owner MINT's admin) and adds it as the subscription's consumer. MINT's
   admin calls `setWorker(new address)`.
3. Calea deploys `PrizeVault` on 4663, Ethereum and ApeChain with `signer` set to the new address, and
   `MysteryBox` on 4663. Everything is Sourcify-verified and read back.
4. MINT creates the worker's Railway service, with the sealed key and the addresses and deploy blocks
   above, and funds the key with 0.02 ETH on Arbitrum One.
5. The worker's `/ready` reads ready, with no `not-the-worker` or `not-the-signer` alarm.
6. MINT's admin sets up the first cycle: funds the vaults, registers the list, and schedules it on both
   chains.

## 7. Questions for MINT on the call

1. Is `0x18D2…1Eff` the address of the key in Railway? Is that key stored anywhere else?
2. Who creates the mainnet key, where is it kept, and who holds the backup?
3. Railway: have tokens been rotated, is 2FA on for every member, and has the audit log been checked?
4. One key, or the KMS option (§5.6)?
5. **When does the first mystery-box cycle open?** It was set for 4 November, but the mint now follows
   the 7 November close, so no holder would have a bear by then.

**Other items for the same call:**
- **Mint dates (CQ-1):**
  - the hour the whitelist campaign closes on 7 November;
  - the whitelist stage's date and hour (at least 48 hours after the freeze), and the public stage's;
  - Activation's switch-on, the first royalty split (5 November) and the handover (19 November).
- **Ownership:** MINT's admin calls `acceptOwnership()` on `MintABear` `0x655e…cB28`. Then Iñigo sets
  Studio's metadata, provenance, royalties and stages.
- **BearDrop:** round 1 is 4,444 bears at 500 $MNTD (2,222,000 in all) for 90 days. Calea sends the list
  and its checksum for MINT to confirm. The testnet run is by 12 November and mainnet on 13–14 November.
  After the handover, MINT funds the contract with 2,222,000 $MNTD and opens the round.
