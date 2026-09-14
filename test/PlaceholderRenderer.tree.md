# PlaceholderRenderer — branching tree

Scope note: invariants (INV-N) are recorded here as obligations for the auditor. They are
deliberately not implemented as developer unit leaves.

This contract holds no user state. It is replaced wholesale at reveal by pointing
`MintABear.setRenderer` at the real renderer, which is why its strings are settable rather
than immutable and why a defect here costs a redeploy of this contract only.

## render

```
render
├── it returns a base64 data URI under data:application/json;base64,
├── it produces the exact document marketplaces expect
├── it carries the token id in the name and is otherwise identical across bears
└── escaping
    ├── when a string contains a double quote
    │   └── it is escaped, so the document stays parseable for all 4,444 tokens
    ├── when a string is shaped to close its field and open another
    │   └── the content stays inside its own field and no second key appears
    ├── when a string contains a backslash
    │   └── it is escaped rather than consuming the character after it
    ├── the external url and the image are escaped as well as the description
    └── when every string is empty
        └── the document is still well formed
```

## setStrings

```
setStrings
├── when the caller is not the owner
│   └── it reverts
└── when the caller is the owner
    ├── it replaces all three strings
    ├── it emits MetadataStringsUpdated
    └── it accepts any content, because render escapes it
```

## Reads

```
description / externalUrl / image
└── each returns what was last written
```

## Auditor obligations (not implemented here)

- INV-11: `render` returns a parseable JSON document for every token id and every possible
  combination of owner-supplied strings.
- INV-12: no owner-supplied string can introduce a key into the document.
- **Known and accepted:** the collection name prefix `MINT Bear #` is hardcoded. The real
  renderer replaces it at reveal, so it is not made settable here.
- **Known and accepted:** if the renderer's owner renounces ownership the strings freeze.
  Recoverable, because `MintABear.setRenderer` can point at a fresh renderer.
- **Open, not answerable here:** whether an on-chain `tokenURI` renders correctly inside an
  OpenSea Studio-managed drop. Listed in `docs/HANDOVER.md` as one of the two testnet
  unknowns; it bears on this contract more than any other.
