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
├── when $MNTD's decimals differ from the config's: it reverts with DecimalsMismatch
└── otherwise, in this order (OPS-2):
    ├── Activation(bears, thresholds scaled by 10^decimals, weights)
    ├── DirectBurnAdapter(mntd, activation)
    ├── setCrediter(adapter) — the one address set after construction
    ├── setPaused(true) — until the switch-on date
    └── transferOwnership(admin)
```

## Config

```
loadConfig: every field of script/config/example.json reads as written
scaledThresholds: whole $MNTD × 10^decimals; a figure past uint128 reverts, never truncates
runWhitelist / runCollection / runActivation: each broadcasts its deployment from the config
```

## Rehearsal obligations (OPS-4, not unit leaves)

- On 46630: all three entry points against the testnet $MNTD, then OpenSea Studio attaches to the
  collection (rehearsal item 1) and the admin completes `acceptOwnership`.
