# Design

## Context

This change corrects text only. The vault's behaviour is set by RAF-35 to RAF-37 and is
unchanged. One choice goes beyond rewording: how OPS-3 verifies on Arbitrum.

## Goals / Non-Goals

**Goals:**
- Make every active requirement and resolved register entry agree with CQ-22 option B before
  `tasks.md` 5.1 begins.
- Make OPS-3 describe what `verify.sh` and the runbook already do.

**Non-Goals:**
- **RAF-27's Scenario title (R-2).** A MODIFIED block must keep every Scenario the main spec has
  by name, so a rename fails `openspec validate`. Renaming it takes a REMOVED plus ADDED Scenario
  or a hand edit after archive, plus the quote in `MysteryBox.t.sol:224`. Left for the person to
  choose; the title is wrong but harmless.
- RAF-32's and RAF-33's vault clauses, and RAF-16's vault events, are left unassigned in
  `tranche-2/tasks.md` (IC-8). That is a pick-order edit to the tranche's `tasks.md`, made beside
  this change and not through it.
- The `docs/SPECIFICATION.md` narrative outside the generated markers (IC-15), and NFT's README,
  DESIGN, RUNBOOK and NatSpec (IC-10). Those go with the next client document and with 5.x.
- The scenario-quote check reporting requirements with no quoting test (IC-8). That is tooling.

## Decisions

**OPS-3 uses Sourcify on Arbitrum, with no Arbiscan route** (the person, 16 October 2026).
`verify.sh` takes a chain id and already verifies through Sourcify. The rehearsal's `PrizeDraw`
on 421614 is `exact_match`, and Arbiscan displays Sourcify-verified sources.
- The alternative was an Etherscan-API route in `verify.sh` for 42161 and 421614. It needs an API
  key in the deploy environment, a second verdict path, and new fixtures for
  `test/verify.test.sh`, and it buys nothing a reader of Arbiscan would see.
- OPS-3's Scenario names only 4663 and 46630, so no test changes.

## Risks / Trade-offs

- **CQ-8, CQ-11 and CQ-20 are in MINT's register history.** The superseding paragraphs add to the
  record and rewrite none of it, so the answers MINT gave stay as given.
