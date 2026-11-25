Hi all,

After the handover we checked MintABear `0x655e88103f77a48E0b7875511318d3c5f79FcB28`, Activation `0xAbd272C95F20B59659E3E21Ed75A58652e93159b` and the drop Studio set up on them. We only read the chain and simulated calls. Nothing was sent or changed.

**What is in order**
- Your admin `0x1530…6141` owns both contracts. SeaDrop is the only minter, and supply is capped at 4,444 in Studio and in the contract itself. Nothing is minted yet.
- The drop on SeaDrop matches the OpenSea page. All stages are free and run on 26 November (UTC):

  | Stage | Time | Limit per wallet |
  |---|---|---|
  | Team | 15:00–16:00 | 444 |
  | GTD | 16:00–17:00 | 5 |
  | FCFS | 17:00–18:00 | 1 |
  | Public | 18:00–20:00 | 1 |

  OpenSea's signer is set for the allowlist stages, and OpenSea's fee recipient is the only one allowed.
- We simulated the public mint at tomorrow's times. One bear at 18:01 goes through. Each of these is refused: a second bear for the same wallet, a mint before 18:00 or after 20:00, and a mint naming another fee recipient.
- On a copy of mainnet we ran one bear end to end:
  - it was minted in the public stage;
  - 1,666 $MNTD was burned for it, so it reached level 1, and the $MNTD was destroyed, not moved;
  - it was transferred and dropped to level 0;
  - it went back to the wallet that burned and stayed at level 0.
- Transfers: a holder can always move their own bear. A sale goes through only on OpenSea (its signed orders) or on a Payment Processor marketplace. A Seaport transfer without OpenSea's signature is refused.
- Activation has been paused since it was deployed. It is bound to MintABear and to $MNTD `0x62Ed…a967`.
  - Levels 1–5 start at 1,666 / 3,333 / 8,333 / 16,666 / 41,666 $MNTD.
  - Weights for levels 0–5 are 100 / 110 / 125 / 145 / 170 / 200.
- The admin wallet holds 0.0018 ETH on Robinhood Chain, enough for every call below.

**Before the Team stage opens (26 November, 15:00 UTC)**
1. **Provenance hash: optional, but only possible now.** It is not set. The contract accepts it only while nothing is minted. If you want a provenance commitment for the reveal (the specification puts it before the mint), set it in Studio before 15:00 UTC.
2. **The site still points at the old collection.**
   - In `apps/webapp/src/features/bears/deployments.ts`, mainnet's `bears` is `0x96ba…4dD1`.
   - The config refuses any other `BEARS_ADDRESS` on mainnet, so an environment variable can't fix it.
   - It needs a code change: `bears: '0x655e88103f77a48E0b7875511318d3c5f79FcB28'`, `activation: '0xAbd272C95F20B59659E3E21Ed75A58652e93159b'`, `deployBlock: 93_422_005n`.
   - Until then `/nft` reads the wrong collection.
3. **Check the Team list.**
   - The Team stage allows up to 444 bears per wallet, and its cap is the full 4,444. A wallet on that list could therefore mint far more than the team's share.
   - Please check that only team wallets are on it, with the amounts you intend.
   - OpenSea's server signs the allowlists, and they aren't stored on-chain, so they can only be checked in Studio.
4. **Pre-reveal image.** The pre-reveal metadata puts an MP4 video in `image`. OpenSea may show it, but wallets and pages that expect a picture often show nothing. It is safer to put a still image in `image` and the MP4 in `animation_url`.

**Before the first resale**

5. **On-chain royalties are not set.**
   - `royaltyInfo` returns no receiver and 0%. The 6.9% on OpenSea is OpenSea's own setting.
   - Marketplaces that read the on-chain royalty, Payment Processor ones included, would pay nothing.
   - Please set 690 basis points and the receiver in Studio (or with `setRoyaltyInfo`).
   - Please also confirm which address OpenSea pays its 6.9% to.
6. **Prove one OpenSea resale.**
   - Transfers are restricted so that royalties are paid. Only a real sale can show how OpenSea's orders behave with that on Robinhood Chain.
   - We suggest listing and selling one team bear after the Team stage and before the public stage at 18:00.
   - If the sale fails, one admin call, `setTransferValidator(0x0000000000000000000000000000000000000000)` on MintABear, lifts the restriction, and royalty enforcement with it.

**The old collection `0x96ba…4dD1`**

7. **Its stages were moved, not removed.**
   - Its public stage now opens on **6 July 2027, 14:00 to 16:00 UTC**, and on that date anyone could mint there directly through SeaDrop.
   - While nothing is minted on it, one admin call closes every way to mint there for good: `setMaxSupply(0)` on `0x96ba…4dD1`.
   - Its OpenSea page should be hidden too.

**Activation: when to unpause**

8. **Activation stays paused until your admin calls `setPaused(false)`.**
   - It can be paused again at any time, and nothing on-chain ties it to the mint.
   - We suggest unpausing once all three of these hold:
     - the site's burn flow points at the two contracts above and works on mainnet;
     - your Status boost reads levels from Activation, so a holder's first burn counts;
     - one small burn with a team bear has gone through, in a short window you open and then close.
   - Before their first burn, holders approve $MNTD to Activation. The site's flow should ask for that approval.

**For the reveal**
- Set the base URI to a folder ending in `/`. Each bear then reads `<folder>/<id>`, for ids 1 to 4,444, with files named without a `.json` extension.

**Still to come**
- The mystery box, the draw and the prize vaults are not on mainnet yet. They are waiting for the worker key's address.
- `contractURI` is empty. OpenSea doesn't need it, but other marketplaces read it.
