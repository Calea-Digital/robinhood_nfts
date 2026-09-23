# Enforcement (script/Enforcement.s.sol) — branching tree

Scope note: the script runs against a local collection owned by the broadcast signer, with
`MockTransferValidator` at the V3 address modelling the zero-state policy. Leaves that satisfy a
requirement's Scenario cite it (`OPS-n`, `openspec/specs/operations/spec.md`). The real V3 on 4663
is the auditor's Fork-2 (`test/MintABear.tree.md`).

```
disable / enable
├── with enforcement on: a foreign venue's transfer is refused; disable emits
│   TransferValidatorUpdated(V3, 0) and the same venue settles; enable emits
│   TransferValidatorUpdated(0, V3) and it is refused again (OPS-6)
├── when the collection is already in the requested state: AlreadyInState, nothing broadcast
└── when the broadcast signer is not the owner: the owner-only call reverts, the validator unchanged

status: (true, V3) while on; (false, 0) while off

safeTransaction(bears, enable): to = the collection, value = 0, data = setTransferValidator(V3 or 0)
```
