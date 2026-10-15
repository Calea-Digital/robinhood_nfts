# OPS-4 — testnet rehearsal, 15 October 2026

MNT-64. Run on Robinhood Chain testnet 46630 and Arbitrum Sepolia 421614 from NFT branch
`mnt/OPS-4-rehearsal` (configs `b95e86e`, subscription `7b2b95c`; off `feat/contracts` `08f33ef`).
The Sepolia leg was skipped on the person's word: the prize was paid on 46630, which OPS-4's
technical note allows ("a payout from a prize wallet on 46630 or Sepolia").

## Verdict

Every testnet path OPS-4 lists completed end to end, with real Chainlink VRF v2.5 words:
the collection with enforcement on and a holder's own transfer passing; the whitelist on SeaDrop;
a burn through `Activation` against the test $MNTD to a recorded level, and its reset on transfer;
two mystery-box cycles — both chains scheduled with identical terms, three losses and three wins,
every win paid and recorded, and every bear opened again in the second cycle. Every outcome was
recomputed from its word with `(word mod idsLeft) < prizesLeft` (6/6). All four contracts are
Sourcify `exact_match` (`verify.sh 46630 --check`, `verify.sh 421614 --check`; MNT-95).

Still OPS-4's, on mainnet before the drop page (OpenSea does not support 46630): Studio takes the
collection over and `compare` passes over a test CSV against Studio's root; the team's bears are
minted and one is sold on OpenSea.

## Roles and addresses

| | Address |
|---|---|
| Rehearsal admin (MINT's admin's stand-in; owns every contract and the VRF subscription) | `0x7672D1F3C832796D378827019a9f9Bf4D80404Aa` (Foundry keystore, the person's) |
| Deployer (Calea's stand-in; holds no role after deploy) | `0xC8b309D5afE338bDC3089433690907320efa8C11` (throwaway) |
| Minter, two spots / one spot | `0xFDa1824264b2366dc9FB1E4846D2419CC445E783` / `0xF08bfD7294Ab9091bCf03e73Bf5894dE81c87603` (throwaway) |
| Worker / test prize wallet | `0x18D215575D36608ED58afFB2d336298Fa6401Eff` / `0x4f6773A39cdB4D9B46Ce39d6f1Bc46B449aCd9e2` (throwaway) |
| Test $MNTD (46630) | `0x63573eD184850Df903C908314Bc6aA3fD6d0128B` — same runtime as `0x15CF…211C` apart from the EIP-712 immutables; the wallet MINT funded holds this one |
| `MintABear` (46630) | `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` |
| `Activation` (46630) | `0x389578ECe1E63DBEe48c9b22504D1Af29E2aef2f` |
| `MysteryBox` (46630) | `0xA15a5B96849435B0030F1F6D6E3f886c8C0d55a7` |
| `PrizeDraw` (421614) | `0x8108AE7e4EB89CcCE253B8aD93d7c46250790A05` — the same address as the collection on 46630, since the deployer used nonce 0 on both chains |
| VRF subscription (421614) | `19717353174742848453250136096704075781277102858438568403532583806649557670789`, funded with 0.5 ETH, 50 gwei lane, 300,000 callback gas, 3 confirmations |

## Numbers

| | Gas |
|---|---|
| `MintABear` deploy | 4,648,795 |
| `mintAllowList`, 2 / 1 | 100,409 / 98,498 |
| `Activation.burn` (to level 1) | 121,249 |
| `MysteryBox.open` | 62,112 |
| `PrizeDraw.resolve`, first relay of a cycle / later | 155,322 / 135,422–137,422 |
| `recordPayout` | 75,492 |

VRF: six requests took the subscription from 0.5 to 0.49995143 ETH, about 0.0000081 ETH per request
at Arbitrum Sepolia's prices; mainnet's will differ (network fee plus Chainlink's premium).

## Found along the way

- **Operator error, not a defect:** `Activation.burn` takes `(uint256 tokenId, uint128 amount)`.
  Called as `burn(uint256,uint256)`, the call reaches no function and reverts with empty data after
  190 gas — which reads like a contract fault. The client calls through its generated ABI and is
  right by construction; the RUNBOOK's Activation section has no burn command, and the rehearsal
  window it describes (unpause, burn, re-pause) would be easier to run with one.
- **The test $MNTD has two deployments** on 46630; the funded one is `0x6357…128B`. `46630.json`
  names it.
- **Anvil forks of 46630 keep the real (dust) balances** of anvil's default accounts; a local run
  funds them first with `anvil_setBalance`.

## Log
### Funding (46630 0.0005 ETH each; 421614 0.01 ETH each)
- 46630: 0xbea9e7b1…, 0x25baea43…, 0x44d09132…, 0xe02f3e40…; 421614: 0x3098a9b3…, 0xc8370b1a…
### VRF subscription (421614)
- id 19717353174742848453250136096704075781277102858438568403532583806649557670789
- create 0xbddcdc537b8ab7d803cda391b0785c4625af346da7a25db8987db2f3dedadec7; fund 0.5 ETH 0x1 0x42eabc5d0d99e2418d71be8777df5d0e56465c43b5cc627238c92ea7d3ba77d2
### Collection (46630)
- MintABear 0x8108ae7e4eb89ccce253b8ad93d7c46250790a05, Sourcify verified at deploy
- accept 0x1 0xb9f707ce4a7855e5916b56b5be3174cd2567c025e9962beabf69e3afb09ecf95; payout address 0x1 0xdf30176fc347ce6a85143efa5c0885ac019f35748b098794356a0880f35a7d71
### Allowlist (46630)
- root 0x01b8…0ef6 set by the owner (0xaa31d1e7…), read back; compare matches
- MINTER2 mints 2 (0x663def6a…), MINTER1 mints 1 (0x489bd933…); supply 3
- refusals: MINTER1 second MintQuantityExceedsMaxMintedPerWallet(2, 1); 2 spots InvalidProof; other's proof InvalidProof
### Activation (46630)
- deployed by runActivation (Cancun simulation, test $MNTD 0x6357…128B), Sourcify verified; owner admin, paused, DECIMALS 18, thresholds 1666…41666, weights 100…200
- MINTER2 → admin bear 2 under validator V3 (holder's own transfer): 0x858d0209…, again 0xf2fb8f30…
- paused burn ContractPaused; unpause 0x9f6f63c1…; non-owner NotBearOwner; overshoot Overshoot(); zero ZeroAmount
- burn(2, 1666e18) 0x7ef31e0e… gas 121,249: level 1, weight 110, MNTD supply −1666
- re-pause 0x9ab1bb5b…; admin → MINTER2 0xef921378…: level 0, weight 100, nonce 4 (reset)
### Mystery box deploys
- MysteryBox 0xa15a5b96849435b0030f1f6d6e3f886c8c0d55a7 (46630), Sourcify verified, PLAYABLE 4444, owner admin
- PrizeDraw 0x8108ae7e4eb89ccce253b8ad93d7c46250790a05 (421614), Sourcify verified, PLAYABLE 4444; subscription owner/balances printed; same address as the 46630 collection (deployer nonce 0 on both)
- addConsumer 0x246e4d0f…; worker's own setWorker Unauthorized; setWorker 0xd790fbe0…
### Cycle 1 — start 1792066810 end 1792067710, 2222 prizes, manifest 0x2926b3b70bd7ec68b052878385b40faae548dc71847f4c5b2b377342d3f7729c
- box.scheduleCycle 0x118f08c0…, draw.scheduleCycle 0x1ce9a714…; CycleScheduled terms identical on both chains
- open before start: CycleNotOpen; admin / MINTER1 on bear 1: NotBearOwner; second open of bear 1: AlreadyOpened
- opens (gas 62,112 each): #1 bear 1 MINTER2 0x952ad280…; #2 bear 3 MINTER1 0xfce6e650…; #3 bear 2 MINTER2 0x8b5cdbe6…
- relays: openIndex 2 first OutOfOrder; admin NotWorker; token 9999 InvalidTokenId; replay of #1 OutOfOrder
- resolve #1 0x32a1c43d… gas 155,322; #2 0xe1935755… gas 135,422; #3 0x3dd9f965… gas 137,422
- real VRF words applied (callbacks 0x256ba6fb…, 0x83d4d89c…): all three lost; word mod idsLeft = 3828/4444, 3471/4443, 2687/4442 vs 2222 — matches the rule
- recordPayout on a loss: NotAWin
### Cycle 2 — start 1792067879 end 1792068779, 4000 prizes, manifest 0x8944f4472c1078956407c56cb1313fef392ed4073481b2046235a480ec2e8398
- open after cycle 1's end: CycleNotOpen; box.scheduleCycle 0x443e3058…; draw: rescheduling started cycle 1 CycleStarted; draw.scheduleCycle(2) 0x49c21bff…
- the same bears opened again: #4 bear 1 0xc02c8841…; #5 bear 3 0x3ada36c1…; #6 bear 2 0x6dc0452d… (gas 62,112 each)
- #4 under cycle 1 AlreadyResolved; under cycle 3 UnknownCycle
- resolve #4 0xf5e4d674… gas 155,322 (first relay of the cycle); #5 0x27140dbd… 135,422; #6 0x3cd2cd0d… 137,422
- all three won (prize 1, 2, 3): word mod idsLeft 3404/4444 < 4000, 3148/4443 < 3999, 2902/4442 < 3998
- prizes 0.00001 ETH from PRIZE on 46630: #4 0x35966a08…, #5 0xd32cc879…, #6 0x80ffe738…
- recordPayout (gas 75,492 each) #4 0x54cf4402…, #5 0xca3f6faa…, #6 0x66a31e30…; payoutOf reads each hash and chain 46630
- refusals: admin records NotWorker; zero hash InvalidPayout; #4 twice AlreadyPaid
### VRF cost
- 6 requests: subscription 0.5 → 0.49995143 ETH, ≈ 0.0000081 ETH per request (Arbitrum Sepolia prices)
