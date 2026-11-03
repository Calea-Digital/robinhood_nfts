# Mystery box worker key: what MINT needs to do

*From Calea, 3 November 2026*

## In short

The mystery box worker's key (`WORKER_PRIVATE_KEY`) was stored in Railway during Railway's
security incident. Railway did not rotate environment variables, so **we treat that key as
compromised**. It must never be used on mainnet.

**Nothing is at risk today.** The mainnet draw, prize vaults and mystery box are not deployed yet,
and the current key only has roles on testnet. Before launch, MINT needs to create a **new key**
and secure Railway. Calea then deploys the contracts with the new key's address built in from the
start.

## Why this matters

The worker key has two jobs on mainnet:

| Role | Where | What it does |
|---|---|---|
| **Worker** | `PrizeDraw` on Arbitrum One | Sends each box opening to the draw, applies outcomes, records payouts |
| **Signer** | `PrizeVault` on every prize chain (Robinhood Chain, Ethereum, ApeChain) | Signs each winner's claim ticket |

If someone else had this key on mainnet, they could:

- **sign claim tickets for themselves and claim every prize in the vaults.** This is the serious
  risk;
- send the draw made-up box openings and win prizes that way;
- write false payout records.

They could **not** withdraw unreserved funds, pause anything, change owners, or touch the collection,
`Activation`, $MNTD or `BearDrop`.

The key holds only a small amount of ETH on Arbitrum One for gas. It never holds prizes, but it
controls who can claim them. That is why it has to be clean.

## What MINT needs to do

### Step 1: Secure Railway

Do this before creating the new key, so the new key doesn't go into an environment that may still
be exposed.

- [ ] Rotate **every** token and secret in the Railway project, not only the worker's.
- [ ] Turn on two-factor authentication (2FA) for every team member.
- [ ] Remove any member who doesn't need access.
- [ ] Read Railway's audit log for the incident window and note anything unexpected.

### Step 2: Tell us about the old key

- [ ] Confirm whether `0x18D2…1Eff` (the testnet worker) is the address of the key that was in
  Railway.
- [ ] Tell us whether that key is stored anywhere else (another service, a laptop, a password
  manager).

Calea then points the testnet draw at a fresh testnet key and moves the old key's leftover ETH out.

### Step 3: Create the new mainnet key

On a **clean, trusted machine**:

1. Create a new wallet:

   ```sh
   cast wallet new
   ```

   This prints an **address** and a **private key**. Any wallet tool that can export a raw private
   key works too.

2. Store the **private key** in exactly two places:
   - in Railway, as a **sealed** variable named `WORKER_PRIVATE_KEY` on the worker's service;
   - in MINT's own secret store (password manager or vault), as the backup.

3. Decide and record **who** created the key, **where** the backup is kept, and **who** can access it.

**Never** paste the private key into chat, email, a ticket, a document or a commit. Calea never needs
it and will never ask for it.

### Step 4: Send Calea the address only

- [ ] Send the new key's **address** (starts with `0x`, 42 characters) to Calea.
- [ ] Send it through a channel **other than** the usual chat (for example a call or a signed
  email), and confirm it by reading back the first and last four characters, so nobody can swap the
  address on the way.

### Step 5: Choose one key or extra protection (optional)

By default, one key does both jobs (worker and signer). That keeps things simple, and it's what we
recommend for launch.

For extra protection, the signer can live in a cloud key service (AWS KMS or Google Cloud KMS), so
the raw key never sits in an environment variable. That needs a KMS account on MINT's side and a
change to the worker. Tell us if you want it. It is a cost and effort decision.

## What happens next

Once Calea has the new address:

1. Calea creates the Chainlink VRF subscription on Arbitrum One.
2. Calea deploys `PrizeDraw`, owned by MINT's admin. **MINT's admin calls `setWorker(<new address>)`.**
3. Calea deploys the prize vaults (with the new address as signer) and the `MysteryBox`, all verified
   and checked on-chain.
4. **MINT** creates the worker's Railway service with the sealed key and the contract addresses, and
   sends **0.02 ETH on Arbitrum One** to the new address for gas.
5. We check together that the worker's `/ready` page reads ready, with no `not-the-worker` or
   `not-the-signer` alarm.
6. **MINT's admin** sets up the first cycle: funds the vaults, registers the prize list, and
   schedules the cycle on both chains.

Because the new address is built in from the start, the key never has to be swapped on a live
system before launch.

## If a key is ever leaked again

Keep these steps to hand. The worker's README has them under "Restarting, redeploying, replacing
the key".

1. **Pause every prize vault.** This stops claims immediately.
2. Create a new key (Step 3 above) and fund it with ETH on Arbitrum One.
3. MINT's admin calls `setWorker(<new address>)` on the draw and `setSigner(<new address>)` on every
   vault. The old key loses both roles as soon as these transactions confirm, and tickets it signed
   stop working.
4. Replace `WORKER_PRIVATE_KEY` in Railway and redeploy the worker. It re-signs every unclaimed win
   on its first pass.
5. Lift the vaults' pause.
6. Move any ETH left on the old key to a safe address.

## Questions we need answered

1. Is `0x18D2…1Eff` the key that was in Railway, and is it stored anywhere else?
2. Who creates the mainnet key, where is the backup kept, and who has access?
3. Has Railway been secured (secrets rotated, 2FA on for everyone, audit log checked)?
4. One key, or the cloud key service option?
5. When should the first mystery-box cycle open? It can't be before holders have bears, so it comes
   after the mint.
