# Proposal

## Why

On 15 October MINT chose prize vaults (CQ-22, option B), and change `raf-prize-vault-claims`
added RAF-35 to RAF-37. Some text that change did not reach still describes the earlier model,
where MINT's prize wallet holds and pays every prize: RAF-27, OPS-1, OPS-4 and OPS-5, and the
register entries CQ-8, CQ-11 and CQ-20 (integrity check of 16 October, IC-6 and IC-7). OPS-3
also names Arbiscan for Arbitrum, while every verification so far, the rehearsal's `PrizeDraw`
on 421614 included, has gone through Sourcify. This has to be put right before the vault is
built (tranche 2, `tasks.md` 5.1), because 5.1 is written and reviewed against this text.

## What Changes

- **RAF-27:** the statement says the prizes are held by the vaults, funded from the prize wallet,
  and that each vault accepts a cycle's list only when it matches the fingerprint and is funded
  (RAF-35). The sentence calling the list MINT's commitment goes. The Scenario is unchanged.
  Renaming its title "Opening freezes the odds" (R-2) is not possible in a MODIFIED delta,
  because `openspec validate` treats a renamed Scenario as a dropped one, so R-2 stays open.
- **OPS-1:** the prize wallet funds the vaults and pays nothing itself. The worker also signs
  each winner's claim ticket and is every vault's `signer`.
- **OPS-3:** Sourcify on Arbitrum One and Arbitrum Sepolia too, with no Arbiscan route (the
  person's choice, 16 October). The vault chains keep Sourcify, or the chain's explorer where
  Sourcify does not support the chain.
- **OPS-4:** the note says the cycles it lists are the 15 October rehearsal, with the payout sent
  from the rehearsal wallet, and that the vault's testnet run belongs to RAF-18.
- **OPS-5:** the ownership steps cover `PrizeVault` beside the other four contracts.
- **Register:** CQ-8, CQ-11 and CQ-20 each get a "Superseded (MINT, 15 October 2026, CQ-22)"
  paragraph, and their Resolution and Summary lines are updated to match.

No Scenario changes and no code behaviour changes, so every test's quote stays valid.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mystery-box` (RAF): RAF-27, the statement and technical note.
- `operations` (OPS): OPS-1, OPS-3, OPS-4 and OPS-5, statements and technical notes only.

## Impact

- `openspec/specs/mystery-box/spec.md`, `openspec/specs/operations/spec.md` and
  `openspec/decisions.md` change. The generated blocks in `docs/SPECIFICATION.md` and
  `docs/OPEN-QUESTIONS.md` are re-rendered. The board is refreshed through `/mnt:board`
  (RAF-27, OPS-1, 3, 4, 5, and CQ-8, 11, 20).
- **mintdotio/NFT:** nothing changes. `verify.sh` and the RUNBOOK already use Sourcify on 421614
  and 42161.
- `spec_version` stays 2.6. The change rides with the next client document.
