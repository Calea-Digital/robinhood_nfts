# MintABear — Runbook

Operating the MintABear contracts on Robinhood Chain (4663). Every change here is an owner call
by MINT's admin, and reversible; the reads and the whitelist export change nothing. Scripts live in `script/`; each prints what it read
and what it did.

## Ownership handover (COL-10)

**Accept, then check what was handed over — before Studio configures anything.** Calea deploys
and offers ownership; MINT's admin completes it and, in the same sitting, resets and reads the
state an owner could have set before the handover. Everything below is expected empty or zero
because the deploy sets none of it; Studio fills it in afterwards.

```shell
# 1. accept (from the admin; a Safe proposes the same call)
cast send $BEARS "acceptOwnership()" --rpc-url $RPC
# 2. reset the minter list to canonical SeaDrop alone (it has no getter; this replaces it whole)
cast send $BEARS "updateAllowedSeaDrop(address[])" "[$SEADROP]" --rpc-url $RPC
# 3. read the collection
cast call $BEARS "owner()(address)" --rpc-url $RPC                  # the admin
cast call $BEARS "maxSupply()(uint256)" --rpc-url $RPC              # 4444
cast call $BEARS "getTransferValidator()(address)" --rpc-url $RPC   # V3, 0x721C…cd1B
# 4. read SeaDrop's state for the collection
cast call $SEADROP "getCreatorPayoutAddress(address)(address)" $BEARS --rpc-url $RPC     # 0x0
cast call $SEADROP "getAllowListMerkleRoot(address)(bytes32)" $BEARS --rpc-url $RPC      # 0x0
cast call $SEADROP "getAllowedFeeRecipients(address)(address[])" $BEARS --rpc-url $RPC   # []
cast call $SEADROP "getSigners(address)(address[])" $BEARS --rpc-url $RPC                # []
cast call $SEADROP "getPayers(address)(address[])" $BEARS --rpc-url $RPC                 # []
cast call $SEADROP "getTokenGatedAllowedTokens(address)(address[])" $BEARS --rpc-url $RPC # []
```

`$SEADROP` is canonical SeaDrop, `0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`. Anything
non-empty at step 4 was set before the handover: clear it through Studio or the matching
`update…` call before the drop is configured. After this the deployer holds no role.

**`maxSupply` stays at 4,444.** Never raise it in Studio: `getMintStats` advertises `maxSupply`,
so Studio would offer bears the token refuses to mint (`ExceedsMaxBears`, COL-2), and buyers past
the cap would pay gas for reverted transactions.

**Ownership is never renounced.** `renounceOwnership` reverts with `RenounceDisabled` for every
caller: the collection always has an owner, because every setting in this runbook is an owner
call. Ownership moves only by `transferOwnership` (the offer) and `acceptOwnership` (from the new
owner); `cancelOwnershipTransfer` withdraws an offer.

## Whitelist export (WL-4)

**After the campaign closes, and after the last `WindowSet`.** The registry is the source; the
Studio allowlist is its copy. Export the claimant rows, load the CSV into Studio's whitelist
stage, then check the root Studio set against the registry:

```shell
forge script script/WhitelistExport.s.sol --rpc-url $RPC --sig "export(address,string)" $REGISTRY exports/whitelist.csv
forge script script/WhitelistExport.s.sol --rpc-url $RPC \
  --sig "compare(address,address,address,(uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool))" \
  $REGISTRY $SEADROP $BEARS "(0,0,$START,$END,1,4444,$FEE_BPS,$RESTRICT)"
```

**The whitelist stage comes first (WL-4).** Each row's allocations become the allowlist entry's
per-wallet limit, and SeaDrop counts every bear minted to the wallet in any stage against it: a
claimant who minted earlier would lose whitelist mints. So in Studio the whitelist stage is the
first stage in which any wallet but the team's can mint, and no other stage overlaps it; a later
stage's per-wallet limit counts the whitelist mints too. If Studio's allowlist root also carries
leaves that are not the registry's (team, partners), `compare` reports the difference — keep the
whitelist stage's allowlist to the registry's rows.

**The close stays at least 48 hours before the whitelist stage (WL-5).** The deploy checks it
once; any later `setWindow` must keep it too, so the export, the Studio import and the published
proofs have their time.

`compare` fails unless the root is the registry's. The owner can move the window with
`setWindow`, so a `WindowSet` after the export means claims the allowlist does not carry: export
and compare again. `setSigner` rotates the eligibility signer; `renounceOwnership` reverts, so
the owner can always do both.

## Transfer enforcement (OPS-6, COL-7)

**The deployed state.** `MintABear` is an ERC-721C collection. The deploy sets its transfer
validator to Limit Break V3, `0x721C002B0059009a671D00aD1700c9748146cd1B`, and leaves the
validator's zero-state policy in place: security level 0, list 0, OpenSea's SignedZone
(`0x000056F7000000EcE9003ca63978907a00FFD100`) as authorizer. A holder's own transfer always
passes; a sale a marketplace operates settles only through OpenSea or a Payment Processor venue,
so creator earnings are collected on it. A sale arranged outside a marketplace — directly, or
through an escrow the holder sends the bear to — pays none; no level that lets holders move their
own bears prevents it (COL-7).

**Read the current state.**

```shell
forge script script/Enforcement.s.sol --rpc-url $RPC --sig "status(address)" $BEARS
# or: cast call $BEARS "getTransferValidator()(address)" --rpc-url $RPC
```

A non-zero validator means enforcement is on; `address(0)` means it is off. `status` also says
whether the validator is V3; `enable` restores V3 over any other.

**Lift enforcement — one call.** For example, if a marketplace MINT needs is being refused, or
OpenSea's handling of the validated collection on 4663 misbehaves.

- Admin is an EOA:
  `forge script script/Enforcement.s.sol --rpc-url $RPC --broadcast --sig "disable(address)" $BEARS`
- Admin is a Safe: print the transaction and propose it in the Safe —
  `forge script script/Enforcement.s.sol --rpc-url $RPC --sig "safeTransaction(address,bool)" $BEARS false`
  (`to` = the collection, `value` = 0, `data` = `setTransferValidator(address(0))`).

Afterwards any venue can settle a sale; whether creator earnings are paid is then the buyer's choice.

**Restore enforcement — one call.** The same, with `enable(address)`, or `safeTransaction(…, true)`
for a Safe (`data` = `setTransferValidator(V3)`). The zero-state policy applies again at once.

The script refuses a call that would change nothing (`AlreadyInState`: V3 already set for
`enable`, none for `disable`) before broadcasting.

**Watch.** Every change emits `TransferValidatorUpdated(oldValidator, newValidator)` from the
collection; an indexer alerting on it sees every lift and restore.

**Optional list steps — on the validator, from the admin.** The zero-state policy needs no list of
MINT's own. If MINT wants one, the admin calls V3 directly: `createList`, then
`addAccountsToWhitelist` / `addAccountsToAuthorizers` on it, then `applyListToCollection` for the
collection, and `setTransferSecurityLevelOfCollection` to tighten the level. **Never security level
5 or above.** Each step is reversible by the admin on the validator. These calls go to Limit Break's
contract, not to `MintABear`, and are made with Limit Break's tooling; this repository does not
encode them.

## Royalties (COL-6)

**Set before the first sale.** Royalty info is a Studio setting, written to the collection by
MINT's admin through `setRoyaltyInfo`: **500 basis points (5%)** to the royalty pot MINT names
(CQ-15). The receiver is never the admin and never a vault — the contract cannot tell them apart,
so this rule is the operator's. It is set and checked before any sale, the team-bear sale that
proves OpenSea's handling of the validated collection included: until it is set, `royaltyInfo`
answers `(address(0), 0)` and the enforced royalty is zero.

**Check it.**

```shell
cast call $BEARS "royaltyInfo(uint256,uint256)(address,uint256)" 1 10000 --rpc-url $RPC
# expect: the pot address, then 500
```

The rate is collection-wide: every id answers the same. SeaDrop refuses a zero receiver
(`RoyaltyAddressCannotBeZeroAddress`) and a rate above 10,000 basis points
(`InvalidRoyaltyBasisPoints`). Every change emits `RoyaltyInfoUpdated(receiver, bps)`.

## Activation (OPS-2, ACT-11)

**Read everything back the day it is deployed.** `Activation`'s collection, token, thresholds and
weights are fixed in its constructor; a wrong one means a new `Activation`, which costs nothing
while it is still paused and before the portal points at it. The deploy script refuses a
collection address that is not `MintABear` and prints the scaled values; check them on-chain:

```shell
cast call $ACTIVATION "owner()(address)" --rpc-url $RPC      # MINT's admin
cast call $ACTIVATION "paused()(bool)" --rpc-url $RPC        # true
cast call $ACTIVATION "BEARS()(address)" --rpc-url $RPC      # the collection
cast call $ACTIVATION "MNTD()(address)" --rpc-url $RPC       # $MNTD as MINT confirmed it (CQ-2)
cast call $ACTIVATION "DECIMALS()(uint8)" --rpc-url $RPC     # $MNTD's decimals
for k in 1 2 3 4 5; do cast call $ACTIVATION "thresholdFor(uint8)(uint128)" $k --rpc-url $RPC; done
# expect 1,666 / 3,333 / 8,333 / 16,666 / 41,666 × 10^DECIMALS
for k in 0 1 2 3 4 5; do cast call $ACTIVATION "weightFor(uint8)(uint16)" $k --rpc-url $RPC; done
# expect 100 / 110 / 125 / 145 / 170 / 200
```

**Prove control once.** Ownership moves to the admin in one step at deployment, so the admin
sends `setPaused(true)` straight away: it changes nothing (the contract is already paused) and its
`PausedSet(true)` shows the admin holds the key. Only then is the address given to the portal.

**Rehearsal windows and switch-on.** `Activation` stays paused until the switch-on date; no
address is exempt. For each rehearsal against real $MNTD the admin sends `setPaused(false)`, the
rehearsal burns, and the admin sends `setPaused(true)` again; reads, `unlinkBear` and transfers
work throughout. On the switch-on date the admin sends `setPaused(false)` and leaves it.
`renounceOwnership` reverts, so the pause can always be set and lifted.

**Team and treasury mints: at most about 200 bears per transaction.** The collection records one
owner per mint batch and reads an owner by walking back to its batch's start, so `snapshot` —
what the royalty split reads — grows with the square of an untransferred batch's length (a single
4,444 batch cannot be read in one call). Batches of about 200 keep every read cheap.
