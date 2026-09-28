# Deploy (script/Deploy.s.sol) — branching tree

Scope note: the script is exercised against a fresh local chain with the deployer's own calls
recorded. Leaves that satisfy a requirement's Scenario cite it (`OPS-n`,
`openspec/specs/operations/spec.md`). Running it on 46630 and 4663 is OPS-4 (rehearsal).

## deployWhitelist

```
deployWhitelist
├── when the admin or the signer is zero: it reverts with MissingAddress naming the field
├── when closeAt + 48 hours > whitelistStageAt: it reverts with CloseTooLate; exactly 48 hours passes
└── otherwise: WhitelistClaim(admin, signer, openAt, closeAt) — construction only, no later call (OPS-2)
```

## deployWhitelistImport (WL-7, the alternative to deployWhitelist)

```
deployWhitelistImport
├── when the admin is zero: it reverts with MissingAddress; the signer is not read
├── when closeAt + 48 hours > whitelistStageAt: it reverts with CloseTooLate
└── otherwise: WhitelistImport(admin, closeAt) — construction only, no later call
```

## deployCollection

```
deployCollection
├── when the admin is zero: it reverts with MissingAddress
└── otherwise, in this order (OPS-2):
    ├── MintABear(name, symbol, [canonical SeaDrop])
    ├── setMaxSupply(4444)
    ├── setTransferValidator(Limit Break V3)
    ├── transferOwnership(admin) — the admin's acceptOwnership completes it
    ├── canonical SeaDrop mints and any other address reverts with OnlyAllowedSeaDrop (COL-1)
    └── it never calls SeaDrop, so no SeaDrop state is set before the admin takes over (COL-10)
```

## deployActivation

```
deployActivation
├── when the admin, $MNTD or the collection is zero: it reverts with MissingAddress
├── when the collection is a wallet, another contract, or answers MAX_BEARS with anything but
│   4,444: it reverts with NotTheCollection before anything is created
├── otherwise, in this order (OPS-2), with no address set after construction:
│   ├── Activation(bears, mntd, thresholdsWhole, weights)
│   ├── setPaused(true) — until the switch-on date
│   └── transferOwnership(admin)
├── with a 6-decimal $MNTD, Activation reads the decimals itself and scales the thresholds by 10^6
└── it prints DECIMALS, thresholdFor(1..5) and weightFor(0..5) for the runbook's read-back
```

## Config

```
loadConfig: every field of script/config/example.json reads as written
loadConfig: thresholdsWhole other than 5 entries, or weights other than 6: ConfigLength naming the field
runWhitelist / runWhitelistImport / runCollection / runActivation: each broadcasts its deployment from the config
```

## Rehearsal obligations (OPS-4, not unit leaves)

- On 46630: all three entry points against the testnet $MNTD, then OpenSea Studio attaches to the
  collection (rehearsal item 1) and the admin completes `acceptOwnership`.
