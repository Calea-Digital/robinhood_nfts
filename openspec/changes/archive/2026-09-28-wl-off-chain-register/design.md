# Design

- **Adopting WL-6 gives it a new id, WL-8.** WL-6's text and Scenario described an alternative
  "recorded, not built", so the adopted design is restated rather than given a new meaning.
- **The contracts stay in the repository.** They are complete and tested, and they are the
  fallback if MINT ever wants the list on-chain. They are not delivered or deployed.
- **The root check is the one on-chain guarantee left.** `compare` over the CSV proves that
  Studio's allowlist is exactly MINT's final list. It does not prove how the list was made.
