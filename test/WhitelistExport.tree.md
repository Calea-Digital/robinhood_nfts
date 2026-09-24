# WhitelistExport (script/WhitelistExport.s.sol, script/lib/AllowListTree.sol) — branching tree

Scope note: the export and compare run against a registry, a SeaDrop and a `MintABear` deployed
locally; the tree library is checked against a vector produced by merkletreejs 0.2.32 with the
options SeaDrop's reference tests use. They serve WL-4 (the export is the allowlist). That OpenSea
Studio builds its root the same way is rehearsal item 3 (MNT-93's note), not a unit leaf.

## AllowListTree

```
root / proof
├── the root over five rows equals merkletreejs's, whatever order the rows come in
├── the proof of a leaf in a full pair and of the odd leaf carried up equal merkletreejs's
├── one leaf: the root is the leaf, the proof is empty
└── no leaves: EmptyTree; a leaf not in the tree: LeafNotFound
```

## export(registry, path)

```
export
├── writes a header and one wallet,allocations row per claimant, in claim order
└── reads every page: 500 claimants over three pages of 200, sold out before the close
```

## compare(registry, seaDrop, collection, stage)

```
compare
├── when SeaDrop's root is the root of the registry's rows under the stage: it passes, and every
│   row's proof mints exactly its allocations on SeaDrop, one more refused
└── when the loaded list misses a row, or the stage parameters differ: RootMismatch(expected, onChain)
```

## checkedRows (the export's own checks)

```
checkedRows
├── while the window is open and spots are left: CampaignStillOpen(closeAt, spotsLeft), for
│   export and compare alike; one second after closeAt, or once sold out, the rows are read
├── a wallet listed twice: DuplicateWallet
├── a row whose count differs from claimsOf: AllocationMismatch
└── rows totalling other than TOTAL_SPOTS - spotsLeft: TotalMismatch
```
