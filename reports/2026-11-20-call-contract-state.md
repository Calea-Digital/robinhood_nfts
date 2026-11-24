# Call with MINT, Friday 20 November 2026 — contract state, ownership, keys

Prepared by Calea on 20 November 2026. Every on-chain value was read that day between 10:15 and
10:30 UTC (Robinhood Chain block 118,976,682). Repository facts are from `mintdotio/NFT` at
`release/1.5` `2a07426`.

## 1. In one paragraph

**The collection that mints on 26 November is not the one Calea deployed.** MINT's site and MINT's
launch checklist name `0x96ba687Ad4F1F5213E676cEb7556c48F02ab4dD1`, a stock OpenSea Studio collection
that MINT's admin created on 23 September, four weeks before our deploy. Our `MintABear`
(`0x655e…cB28`) is unused: nothing minted, nothing configured, and the ownership offered to MINT's
admin on 20 October was never accepted. The Studio collection has no transfer counter, so
`Activation` as built cannot work with it, and the `Activation` already on mainnet is bound to our
collection for good. The box, the draw, the vaults and `BearDrop` only read `ownerOf` and can be
deployed against either collection. No key that was in Railway has ever held a role on any contract,
mainnet or testnet, so there is nothing to rotate on-chain: the testnet draw's worker is Calea's own
throwaway key from the 15 October rehearsal. MINT has not sent the new mainnet key's address.

## 2. Mainnet: what exists and who owns it

| Contract | Chain | Address | Owner today | State |
|---|---|---|---|---|
| `MintABear` (Calea, 20 Oct) | Robinhood Chain 4663 | `0x655e88103f77a48E0b7875511318d3c5f79FcB28` | **Calea's deployer `0x7672…04Aa`**; pending owner MINT's admin `0x1530…6141`, never accepted | 0 minted, `maxSupply` 4,444, validator V3 set, no drop, no URI, no royalty. Not on OpenSea, not on MINT's site |
| `Activation` (Calea, 20 Oct) | 4663 | `0xAbd272C95F20B59659E3E21Ed75A58652e93159b` | MINT's admin `0x1530…6141` | paused; `BEARS` is `0x655e…cB28` (immutable), `MNTD` is `0x62Ed…a967` |
| "Mint A Bear" / `MINTABEAR` (MINT, 23 Sep, through OpenSea's factory `0x008e…0066`) | 4663 | `0x96ba687Ad4F1F5213E676cEb7556c48F02ab4dD1` | MINT's admin `0x1530…6141` | 0 minted, `maxSupply` 4,444 (changed eight times since September), pre-reveal `baseURI` set. **The collection MINT's site and OpenSea use** |
| $MNTD (MINT) | 4663 | `0x62Ed300A5916aeD339a65E04754392763982a967` | none (no owner, no proxy) | 1,000,000,000 supply |
| `MysteryBox`, `BearDrop`, `PrizeVault` | 4663 | not deployed | | |
| `PrizeDraw` | Arbitrum One | not deployed | | `42161.json` still reads `subscriptionId` 0 |
| `PrizeVault` | Ethereum, ApeChain, Base | not deployed | | `vault.json`'s `signer` is still unset |

MINT's addresses as given to us, all plain wallets (no code):
- Admin `0x153052B43c8fD4ec01f14D1Edd8660778daa6141`: 18 transactions on 4663, 0.0018 ETH there;
  3 on Ethereum; **none and no ETH on Arbitrum One**, ApeChain or Base.
- Royalty receiver `0xf7E70F5ef311232dBd1b0E4dFB1e3e8FBE7b0e63`: never used, no ETH.
- Prize wallet `0xf6c02F0fDAC5c03EE9f1cc60A5D9875Efc4c83e3`: 3 transactions on 4663, 20 on Ethereum.

MINT's own contracts, outside what Calea built (read for context): `LockedStaking`
`0x3cFf…2242` is owned by `0xE3e6e0845C1dD0B5E86D16C9AB173959C2D29509`, a plain wallet never given to
us; the distributor `0xFC53…B601` and lsMNTD `0xc4Ce…A396` have no `owner()`. MINT's checklist also
names an Airdrops Safe `0x5302b15c6C355985e51b5E24488371CF2669b62F` holding 22.57M $MNTD.

Calea's deployer `0x7672…04Aa` holds no role except the unaccepted `MintABear`. Balances for the
remaining deploys: 0.0099 ETH on 4663, 0.099 ETH on Arbitrum One (4 transactions there, none a
contract creation; whether the VRF subscription exists was not confirmed from the chain), 0.006 ETH
on Ethereum (tight for a vault), 63.9 APE on ApeChain, nothing on Base.

## 3. The two collections side by side

| | Ours `0x655e…cB28` | Studio's `0x96ba…4dD1` |
|---|---|---|
| Code | `MintABear`, 20,465 bytes, Sourcify `exact_match`, covered by the 6 October review | EIP-1167 clone (45 bytes) of OpenSea's implementation `0x09a2…dd6a`; cannot be upgraded or extended |
| `transferNonce`, `exists`, `MAX_BEARS` | present | **absent: each call reverts** |
| Supply cap | 4,444 in code (`MAX_BEARS`) | `maxSupply` only, which the owner can raise |
| Burning a bear | refused | allowed (stock `burn`) |
| Renouncing ownership | refused | allowed |
| Transfer validator | Limit Break V3 `0x721C…cd1B` | **`0x0`**: set to `0xa000…0000` on 24 September and cleared days later |
| `royaltyInfo(1, 10000)` | `0x0, 0` | **`0x0, 0`** (MINT's checklist wants `0xf7E7…0e63`, 690) |
| SeaDrop public stage | none | free, 1 per wallet, **26 Nov 18:00 to 20:00 UTC**, fee 10% to OpenSea's recipient, creator payout `0x1530…6141` |
| SeaDrop allowlist root | zero | **zero**: the whitelist is not loaded yet |
| Allowed signers and payers | none | 1 signer (`0xfCe4…F8C3`), 2 payers (`0xb92f…Ff4f`, `0x0729…97f7`); presumably Studio's defaults |

What that means for each contract of ours:

| Contract | Reads from the collection | With the Studio collection |
|---|---|---|
| `Activation` | `ownerOf`, `transferNonce`, `exists` | **every `burn`, `levelOf` and `snapshot` reverts.** Needs a new version and a new deployment |
| `MysteryBox` | `ownerOf` | works as built |
| `BearDrop` | `ownerOf` | works as built |
| `PrizeDraw`, `PrizeVault` | nothing | unaffected |
| `Deploy.s.sol` | `MAX_BEARS() == 4444` before the box, `Activation` and `BearDrop` | refuses the Studio address (`NotTheCollection`); the guard needs a change |
| `@mint/contracts-client` | `transferNonce`, `exists` in the bear reads and guarded transfers | those reads fail; needs a path for a stock collection |
| `WhitelistExport.compare` | SeaDrop's root for the address given | works for either collection |

**`Activation` without the counter.** The only on-chain substitute is to record the owner with the
level and treat the level as void while `ownerOf` differs. A buyer still starts at zero. The
difference: a bear that returns to the wallet that burned gets its level back (sell and buy back, or
any escrow that takes custody and returns it). That is a change to the reset rule (COL-3, COL-4,
ACT-4, ACT-5) that MINT has to accept in writing, and it is code the 6 October review did not see.

## 4. "Transfer of ownership": three readings, ask which

1. **Accepting our collection.** `acceptOwnership()` on `0x655e…cB28` has been pending since
   20 October. If the Studio collection is final, this contract is retired and nothing needs
   accepting; Calea can cancel the offer.
2. **Handing over what Calea deploys next.** Already the design: the box, the draw and every vault
   are constructed owned by MINT's admin; `BearDrop` is handed over in two steps (the admin
   requests, Calea completes within 48 hours). Calea keeps no role.
3. **Moving everything off the admin key `0x1530…6141`** because it is the key they consider
   compromised. Then, before the mint:
   - Studio collection: `transferOwnership(new)` by `0x1530…`, then `acceptOwnership()` by the new
     wallet; also SeaDrop's creator payout address, which is `0x1530…` today.
   - `Activation` `0xAbd2…159b`: the new wallet's `requestOwnershipHandover()`, then `0x1530…`'s
     `completeOwnershipHandover(new)` within 48 hours (moot if it is replaced).
   - Our configs (`4663.json`, `42161.json`, `vault.json`) take the new address before any deploy.
   - Until it moves, whoever holds that key can raise `maxSupply`, allow their own minter and mint
     the supply, change the stages, or take the collection.

## 5. The key from the incident: has it been rotated?

**Nothing needs rotating on-chain, on mainnet or on testnet.**
- **`0x18D215575D36608ED58afFB2d336298Fa6401Eff` is not the Railway key. It is Calea's own throwaway
  key from the 15 October rehearsal** (`reports/ops-4-rehearsal-2026-10-15.md`, "Worker …
  (throwaway)"). Traced on Arbitrum Sepolia: Calea's wallet called `setWorker` for it on 15 October at
  12:16 UTC, the only `setWorker` in the draw's history; the key sent its transactions between 12:20
  and 12:39 that day (six relays, three payout records) and nothing since; it has never transacted on
  any other chain. The brief of 29 October asked MINT whether this address was the Railway key; the
  answer is on the chain. MINT's checklist repeats it as fact and should be corrected.
- So no key MINT ever held has been the worker of any draw or the signer of any vault. The testnet
  vault's signer is Calea's wallet. No mainnet draw or vault exists.
- Whether a worker key was ever in Railway at all is unknown: MINT's PR #52 (19 November) still lists
  creating the worker's Railway service as a missing piece. If one was there, it held no role
  anywhere; it only has to be discarded.
- Our records say Railway's incident; MINT says "Relay". Relay is the swap provider and holds no key
  of this system. If they mean a key other than the worker's, ask for its address.
- What is still required, all MINT's:
  - the mainnet key is new, never the one that sat in Railway, and its address comes to Calea (decided
    on 3 November; **not received**; `vault.json`'s `signer` is still zero and the vault deploy refuses
    until it is set);
  - Railway is hardened before the new key goes in: every secret rotated, 2FA, the audit log read.
    Never answered;
  - the same question for the other secrets in that project, above all the whitelist database's
    credentials: the register was frozen and exported from that database this week.
- For staging, the testnet draw needs a live worker again (its key is deleted): MINT sends the
  staging worker's address and Calea's wallet calls `setWorker`, or staging moves to the MINT-owned
  set that `bears:testnet` deploys.

## 6. Testnet: what is deployed

All Calea's rehearsal set of 15 and 19 October, all owned by `0x7672…04Aa`, all Sourcify-verified.

| Contract | Chain | Address | State | Mainnet counterpart |
|---|---|---|---|---|
| `MintABear` | 46630 | `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` | 3 minted | deployed, unused (§2) |
| `Activation` | 46630 | `0x389578ECe1E63DBEe48c9b22504D1Af29E2aef2f` | paused | deployed, bound to our collection |
| `MysteryBox` | 46630 | `0xA15a5B96849435B0030F1F6D6E3f886c8C0d55a7` | not paused | **to deploy** |
| `PrizeVault` | 46630 | `0xae51fa4e8f5089fe0d3017589fda851475bf383d` | owner and signer `0x7672…04Aa` | **to deploy** |
| `PrizeDraw` | Arbitrum Sepolia 421614 | `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` | worker `0x18D2…1Eff`, the rehearsal's deleted throwaway key | **to deploy** |
| `BearDrop` | 46630 | never deployed (the run planned for 12 November did not happen) | | **to deploy**, after its testnet run |

MINT's staging config still points at this set. MINT's own testnet set (`bears:testnet`) and its
stand-in royalty router are not in the repository's records, so they could not be read.

## 7. What goes to mainnet: parameters, what MINT must supply, order

| # | Contract, chain | Constructor and config | From MINT before it can be sent | After the deploy |
|---|---|---|---|---|
| 1 | `PrizeDraw`, Arbitrum One | owner = admin; coordinator `0x3C0C…7a3e`; key hash, 2 gwei lane; `subscriptionId` (Calea creates and funds it); callback gas 300,000; 3 confirmations; paid in ETH; playable 4,444; first opening 1 | the admin address confirmed (§4) | Calea adds the draw as the subscription's consumer. **Admin calls `setWorker(new key)`: needs about 0.002 ETH on Arbitrum One, has none** |
| 2 | `PrizeVault`, 4663 first; Ethereum and ApeChain when a prize needs them | owner = admin; **signer = the new worker address**; fixed salt, so one address on every chain | **the new worker key's address** (blocks the deploy); which prize chains at launch | address written to `expectedVault`; MINT's worker service gets it |
| 3 | `MysteryBox`, 4663 | owner = admin; bears = the collection | **which collection** (§3) | none; the first cycle is the admin's, on `/nft/admin` |
| 4 | `Activation`, 4663 | owner = admin; bears; $MNTD `0x62Ed…a967`; thresholds 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD; weights 100 / 110 / 125 / 145 / 170 / 200; constructed paused | **which collection**, and for the Studio one **the reset rule accepted in writing**; the switch-on date | admin's `setPaused(false)` on the switch-on date |
| 5 | `BearDrop`, 4663 | owner = deployer until the handover; bears; $MNTD | **the amount** (our list: 500 per bear, 2,222,000 in all, 90 days, sha256 `6161d7ad…c910`; MINT's checklist: 888 in two parts); **open claim, a wagering voucher, or on mint.io instead** | list loaded and checked; two-step handover; the Airdrops Safe funds it; admin opens the round |
| 6 | Royalty router, 4663 | **not specified, not built.** MINT's checklist calls it "Calea's to write and audit": holder-triggered rounds and a swap of half the pot to $MNTD with a price guard | a specification, a commercial agreement, an audit | until then royalties collect in `0xf7E7…0e63` |

Nothing above is needed for the mint itself: the collection calls none of these contracts.

A workable order (Calea's estimate, each step waiting on its inputs):
- **By 25 November, MINT, on the Studio collection:** royalty and validator read back
  (`royaltyInfo` is zero today); the whitelist loaded and `compare` run; the team's bears minted in
  batches of at most 200.
- **Two working days after the worker address and the collection decision arrive:** the deploy
  guard changed and gated, the VRF subscription created and funded, then the draw, the 4663 vault
  and the box deployed, verified and read back; the admin's `setWorker`; MINT creates the worker's
  Railway service and funds the key with 0.02 ETH on Arbitrum One.
- **`Activation` for the Studio collection:** about a week from MINT's written decision: change,
  tests, internal review, deploy paused. An external look at the changed contract is MINT's call.
- **`BearDrop`:** the open-claim version is two days (testnet run, then mainnet) from MINT's
  confirmation of the amounts. A voucher version is new contract work.
- **Royalty router:** weeks, and not before an audit. Not a launch item.

## 8. Decisions and answers to get on the call

1. **Is `0x96ba…4dD1` the final collection?** Does MINT know it differs from the audited
   `MintABear`, and that the supply cap in code, the burn refusal and the transfer counter are not
   in it? (Switching to ours six days before a published drop is not realistic: Studio's takeover
   of a contract it did not create was never proven on mainnet.)
2. **The reset rule for `Activation`** on the Studio collection (§3): accept "a bear that returns
   to the wallet that burned regains its level", or name another rule.
3. **Which key do they mean?** If the worker's: nothing on-chain needs rotating (§5); was a worker
   key ever in Railway, and has Railway been hardened? If the admin's: the new admin address today,
   and the moves in §4.3 before the mint.
4. **The new worker key's address**, sent as agreed on 3 November. **Were the whitelist database's
   credentials rotated after the incident**, before this week's freeze?
5. **Royalties:** 6.9% in MINT's checklist against 5% in the specification; `royaltyInfo` and the
   validator are zero on the Studio collection today. Who sets them, and when?
6. **The public stage is two hours long** (26 Nov 18:00 to 20:00 UTC). Intended? When are the team
   mint and the whitelist stage?
7. **`BearDrop`:** 500 or 888, open claim or wagering unlock, on-chain or on mint.io.
8. **The royalty router:** scope, price, audit, date.
9. **The first mystery-box cycle:** its date and the prize chains (their checklist: start with
   Robinhood Chain only). **`Activation`'s switch-on date.**
10. **Gas:** about 0.002 ETH on Arbitrum One for the admin.

## 9. The whitelist freeze

MINT reports the sequence done: backup, status (unfrozen, 750 spots), freeze, export with the same
sha256, CSV to Iñigo.
- **The CSV and its sha256 have not reached Calea** (`exports/` holds none). Step 5 sends them to us
  for the root check.
- On-chain the allowlist root is still zero, so Studio's upload has not happened.
- `compare` needs the CSV, the collection address (`0x96ba…4dD1`) and every field of the whitelist
  stage as Studio shows it (price, start, end, stage index, stage supply, fee, restrict flag).
- The commands ran inside the container, and the CSV was written to its temporary folder: confirm
  the file Iñigo received hashes to the sha256 both commands printed.
- The register's public endpoint (`mintabear-api.mint.io/public/pool`) now answers Railway's
  "Application not found", so the freeze could not be confirmed from outside.

## 10. Other changes since 3 November

- **Branches:** production is `release/1.4`, staging is `release/1.5`. `feat/contracts` `c94c036`
  (BearDrop and two webapp fixes, PR #43, merged 2 November) is in both. Calea's pull requests now
  target `release/1.5`.
- **Pins:** Node 24.22.3 (`engines` `>=24.22.3 <25`), Next 16.4.6, React 19.3.1, pnpm 12.14.0.
- **MINT changed Calea's packages** in PRs #52 and #53 (18 and 19 November): the box worker
  (`finality.ts`, `vault-claims.ts`, `worker.ts`), the client (`prizeVault.ts`, `client.ts`) and a
  new `test/mocks/MockRoyaltyRouter.sol`, about 200 lines. Our gates have not run on `release/1.5`.
- **MINT's frontend exists:** `/nft` on staging is the holder hub (level-up, box, per-bear $MNTD,
  marketing rewards, Status boost) with `/nft/admin`. PR #52 asks Calea and Lorenzo to list what is
  missing for a testnet run and for mainnet; `docs/post-mint/LAUNCH-CHECKLIST.md` there is MINT's
  own list and reads as if the Studio collection had been the plan throughout.
- **New asks in that checklist:** the royalty router, a `BearDrop` with a wagering voucher, an
  `onSent` callback and an `activatedOnly` split option in the client, and facade calls for the
  reads the pages make directly.
