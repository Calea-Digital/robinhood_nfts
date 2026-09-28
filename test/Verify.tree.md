# Verify (script/verify.sh) — branching tree

Scope note: a shell script, tested without a network. `test/verify.test.sh` (run in CI) reads the
recorded broadcasts under `test/fixtures/` and Sourcify's answers from `test/fixtures/sourcify/`
through a `file://` `SOURCIFY_URL`; the dry run is diffed against
`test/fixtures/verify-dry-run.expected`. Leaves that serve a requirement cite it (`OPS-n`,
`openspec/specs/operations/spec.md`). Being a shell suite, its cases carry no `/* Scenario: */`
block for `check_scenario_quotes.py`; OPS-3's own Scenario is proven live (below).

```
verify.sh <chainId>
├── with no Deploy.s.sol broadcast for the chain: exits 2
├── with broadcasts that created no contract: exits 2, "no contract created"
├── with a contract name it does not know: exits 2
├── --dry-run: prints, for every created contract in broadcast order, the forge verify-contract
│   call and the Sourcify read — WhitelistClaim, MintABear, Activation (OPS-3)
│   └── from a runWhitelistImport broadcast: WhitelistImport, with its own source path (WL-7)
└── --check (and verify, after submitting)
    ├── every contract reads exact_match or match: exits 0 (OPS-3)
    ├── one contract reads anything else: exits 1, naming it MISSING (OPS-3)
    └── Sourcify has no answer: exits 1, MISSING
```

## Rehearsal obligations (OPS-4, not unit leaves)

- OPS-3's Scenario on 46630: each contract a `Deploy.s.sol` broadcast created is verified through
  Sourcify and readable there, and `verify.sh 46630 --check` exits 0 (Subtask MNT-95). On 4663 at
  deployment the same check closes OPS-3.
