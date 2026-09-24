# Decisions Delta

## RESOLVED Decisions

### CQ-3 — Confirm the token-agnostic `credit` design
- **Statement:** Token-agnostic `credit` design
- **State:** resolved
- **Status label:** Closed
- **Status note:** superseded by Calea, 24 September 2026 (tranche-1 review)
- **Rationale:** $MNTD is native to Robinhood Chain (CQ-2), so the indirection that kept `Activation` token-agnostic no longer buys anything, and it let the owner record levels without a burn through `setCrediter`. `Activation` takes $MNTD in its constructor and burns it itself (ACT-1, ACT-4, ACT-7).
- **Blocks:** ACT-1

## Folded by hand into `openspec/decisions.md`

- **CQ-3.** The fields above replace its status note and resolution; its record gains
  "**Superseded (Calea, 24 September 2026).** …" with the rationale, and "In plain words" follows
  ACT-1's new wording (the record first, then the burn, in `Activation`).
- **CQ-2.** Resolution: "burned by `Activation` in the same transaction as the record". Its
  *Remaining* gains: the token's address is final before 20 October — a proxy, or a contract MINT
  will not redeploy — because `Activation` fixes it in its constructor. "Needed by" and the
  *Recorded as* paragraphs name `Activation` in place of `DirectBurnAdapter`.
- **CQ-12.** *Recorded as (call)*: the one setter that is not a constructor argument is
  `WhitelistClaim.setSigner`; `Activation.setCrediter` no longer exists.
