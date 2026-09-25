# contracts-client (packages/contracts-client) — branching tree

Scope note: the typed TypeScript client of DEL-6, tested with vitest against anvil. The contracts
are deployed from the Forge build in `out/`: a real SeaDrop at an ordinary address, the V3
stand-in, `MockMNTD` or the OpenZeppelin `MockOzMNTD`, `MintABear`, `WhitelistClaim` and
`Activation`. The allowlist tree and the voucher typed data are pinned against answers computed
outside viem: merkletreejs 0.2.32 and Foundry's `cast`. Deterministic tests only. That Studio
builds its root the same way is rehearsal item 3, not a leaf here; the real V3's operator error
belongs to Fork-2.

## Call surface (`surface.test.ts`)

```
surface
├── DEL-6: every function the page, the voucher backend and the split call is in the generated ABI
│   and is made by a library export
├── every state-changing function of WhitelistClaim and Activation is the app's or owner-only
└── the README's revert tables name every revert the library lists
```

## Allowlist tree (`allowlist.test.ts`)

```
buildAllowList / allowListRoot / allowListProof
├── the vector rows give AllowListTreeTest's root, leaf and proofs
├── equal merkletreejs 0.2.32 built from the raw rows (hashLeaves, sortLeaves, sortPairs)
├── equal merkletreejs for 1, 2, 3, 7, 8, 9, 64, 100 and 1,000 rows
├── the root is independent of row order
├── a row's leaf commits to its allocations as the per-wallet limit
└── one leaf is its own root with an empty proof; no leaves: EmptyTree; absent leaf: LeafNotFound
```

## Mint (`mint.test.ts`)

```
public stage
├── mints to the sender at the stage price; readPublicDrop and readMintStats read it back
├── another minter only for an allowed payer: PayerNotAllowed, then minted
├── toTransaction sends the same mint as a raw transaction
├── NotActive, IncorrectPayment, FeeRecipientNotAllowed, MintQuantityExceedsMaxMintedPerWallet
├── at maxSupply 4,444: MintQuantityExceedsMaxSupply before ExceedsMaxBears
└── maxSupply raised to 5,000: ExceedsMaxBears
whitelist stage
├── each row mints its allocations with its proof, one more refused; remaining mints read 2 → 0
├── a public mint counts against the allocations (allocations − numberMinted)
└── another wallet's proof: InvalidProof; a list Studio did not set does not match the chain
```

## Whitelist claim (`whitelist.test.ts`)

```
typed data
├── the type string hashes to the contract's CLAIM_TYPEHASH
├── digest and signature equal cast's for a fixed key, domain and voucher
└── the chain id or the registry changes the digest
accountHash (backend rule 1)
├── HMAC-SHA256 under the server key over the canonical id (node:crypto agrees)
├── an email's case and spacing make one account
├── a user id is compared exactly, and never collides with an email spelled the same
├── not the unsalted hash; changes with the key
└── a key under 32 bytes is refused
on chain
├── CLAIM_TYPEHASH and eip712Domain match claimDomain
├── planVoucher → signVoucher → claim; WhitelistClaimed, spotsLeft, claimsOf, accountClaims, claimants follow
├── the index is the account's, whichever wallet claims (backend rule 2)
├── planVoucher refuses NotYetEligible, WalletLimit, AccountLimit (rules 2, 3), CampaignClosed, SoldOut
├── reverts in check order: NotClaimant; BadSigner (wrong key; a contract signer; after rotation,
│   and revived by rotating the key back: rule 4); Expired; CampaignClosed; SoldOut; WalletLimit;
│   AccountLimit; WrongAllocation (index ahead, and index repeated)
└── a smart-wallet address claims for itself
```

## Burn, link, reads (`activation.test.ts`)

```
reads
├── thresholds 0 and 1,666 … 41,666 whole $MNTD in base units, weights 100 … 200, not paused
└── an unminted id: exists false, weightOf 100, snapshot zeroes, readBear absent
burn
├── planBurn: exactly costToReach, approve then burn; BearActivated 0 → 2; readBear follows
├── planBurn with the allowance covering it: burn alone; sent as a raw transaction
├── warnings: OPEN_LISTINGS with the count, NOT_LINKED
├── a target level outside 1..5: RangeError
├── planBurn refuses NonexistentToken, NotBearOwner, InsufficientBalance, AlreadyAtMaxLevel,
│   TargetReached, ContractPaused
├── ContractPaused before ZeroAmount before NotBearOwner
├── NotBearOwner before AlreadyAtMaxLevel
├── Overshoot one base unit above the level-5 remainder; exactly the remainder reaches level 5
├── unminted id: OwnerQueryForNonexistentToken from burn and linkBear
├── the token's own InsufficientAllowance and InsufficientBalance; level stays 0
└── a smart-wallet owner burns
link
├── linkOf reads the bear and its level; a relink emits BearLinked only
├── unlinkBear clears the link, works while paused, and without a link emits nothing
├── NotBearOwner for another's bear; ContractPaused while paused
├── a sale voids the seller's link (readLinkStatus voided); the buyer is prompted and links
├── never linked, or linked and unlinked: none
└── after a first burn, prompted when the wallet links another bear
```

## Transfers (`transfer.test.ts`)

```
planTransfer
├── from == to: ClientRefusal SELF_TRANSFER, nothing sent
├── sent anyway, a self-transfer advances the counter, resets the level, voids the link
├── the zero address: ClientRefusal ZERO_ADDRESS; raw transferFrom and safeTransferFrom: BurnDisabled
├── an activated, linked bear: RESETS_LEVEL and VOIDS_LINK, and the buyer's bear reads level 0
├── a bear never activated nor linked: no warnings
├── an approved, whitelisted operator's transfer resets too
└── an operator the validator does not allow: the validator's own error
```

## Events (`events.test.ts`)

```
decodeSystemLogs / ReferenceIndexer
├── a transfer: TransferNonceAdvanced(id, 1) then Transfer in one transaction; a mint: Transfer only
├── a burn: $MNTD's Approval and Transfer(holder, 0x0) decoded as $MNTD's, never as a bear
├── an OpenZeppelin v4 token's reverts decode as Error with its strings
├── a relink emits BearLinked only; a voided link's BearUnlinked leaves the buyer's link standing
└── replayed over a long sequence, the indexer's levelOf and linkOf equal the contracts'
```

## Royalty split (`split.test.ts`)

```
computeSplit
├── the fixture: 420,560 / 373,831 / 205,607, 2 carried, dead address excluded, contract kept
├── carried-in added; carried below the number of wallets; allocations + carried = distributable
├── nothing eligible: everything carried
└── duplicate id, id outside 1..4,444, ownerless row: refused
inputs at a closing block
├── events mode: owners from Transfer logs (paged by block range), weights from weightOf
├── events mode missing bears (fromBlock after the first mint): refused against totalSupply
├── snapshot mode over exactly 1..4,444, paged by gas, ownerless ids dropped: the same rows
├── both modes give the same split: 393,939 / 363,636 / 121,212 / 121,212, 825 eligible, 1 carried
├── weightOf answers 100 for an unminted id; events mode never reads one
├── duplicate ids refused for snapshot
├── bin/split.ts prints the same split in both modes
└── one 400-bear batch: a single call exceeds the budget, pages shrink, rows equal events mode's
```
