# Tranche 1 — continuation prompt (WhitelistClaim)

Open a fresh Claude Code session in `~/trees/robinhood_nfts`. The kickoff session of
2026-09-22 (`tranche-1-kickoff.md`) took the COL family to In Review; this prompt picks up at
2.1 WL-3. Pick the model in `/model` — the loop, the commands and the connector do not depend
on it. The YouTrack connector must be connected (the loop uses it for every claim and State
change). If `/mnt:next` reads as an unknown command, restart the session once. Paste
everything below the line.

---

Continue MintABear tranche 1 from the YouTrack MNT board, one requirement Task at a time,
through the project's work loop, until a stop condition below is met. Do not ask me to confirm
each Task; report after each one.

**Where things stand (2026-09-23).** Branch `tranche-1` (off `main` at `746acbe`, never pushed,
never merged into `main`) carries the COL family: twelve requirement Tasks merged `--no-ff`,
`openspec/changes/tranche-1/tasks.md` ticked 1.1–1.12 (12 of 37), MNT-7…16, 18, 19 In Review
with claim and summary comments, plus `NONE` Task MNT-92 for the `CLAUDE.md` / `README.md`
rewrite. On `tranche-1`: `src/MintABear.sol` is final for COL (no ERC-6551, no renderer,
`TransferNonceAdvanced`, `exists`, `transferFrom` refuses the zero address with
`BurnDisabled`); `src/Activation.sol` is still the pre-specification contract (it burns $MNTD
itself) and `test/BaseTest.t.sol` wires it to `test/mocks/MockMNTD.sol`; `WhitelistClaim` and
`DirectBurnAdapter` do not exist yet. Suite 119 tests, 100 % coverage, Slither no High or
Critical (one accepted Medium, `locked-ether` on `Activation`). `main` is untouched. Nothing
is In Progress on the board.

**Read first, in this order:** `CLAUDE.md` — its "Specification and board" section is the
contract for this session and its architecture sections describe `tranche-1`; `docs/HANDOVER.md`
— "What is left", "Decisions that should not be relitigated", "Accepted risks" and "Verified
on-chain facts" (never re-research those; its "Where things stand" table still describes `main`
and is updated at tranche end, task 5.3); `openspec/changes/tranche-1/proposal.md`, `design.md`
and `tasks.md` (the pick order); `openspec/specs/whitelist/spec.md` for the WL family and
`openspec/decisions.md` for CQ-18 and CQ-1; then, per Task, the family's spec file. The web3
workflow is `~/trees/ai-stack/manual/01-web3.md` W7 and the process is `manual/02-spec-driven.md`
W5. The In Review comments on MNT-14 (COL-8) and MNT-15 (COL-9) record two judgment calls the
reviewer has agreed to; do not reopen them.

**Loop.**
1. `/mnt:resume` — continue a live claim of yours, release a stale one, leave a human's alone.
   Expected: none live.
2. `/mnt:next` — the first unticked id in `tasks.md` that is Open and not hard-gated (a
   `depends on` link to a decision in State Open). WL-1, WL-3 and WL-5 depend on CQ-18 and
   CQ-1, both In Progress (follow-up), so they are **soft** gates: name the remaining item in
   the claim — for CQ-18 the export direction and any owner bulk-add (build option (A) as
   specified, `msg.sender == wallet`, no bulk-add); for CQ-1 the campaign dates, which are
   `openAt` / `closeAt` constructor values. Claim comment first, then State In Progress and the
   `MNT Claude` tag (the tag exists, id 10-8); branch `mnt/<spec-ref>` off `tranche-1`.
3. Implement against the Task body. Cite the skill: `[SKILL: openzeppelin-skills:develop-secure-contracts]`
   for OpenZeppelin patterns — for `WhitelistClaim` that is EIP-712 and ECDSA; SeaDrop's base
   and Solady's utilities win where they differ (Solady `Ownable`, `EIP712`, `ECDSA` /
   `SignatureCheckerLib` are in `lib/solady`, already a submodule); `[SKILL: evm-internals]` for
   storage layout and gas; `/solidity` for style. `solc 0.8.17`, evm `london`, no PUSH0, no
   transient storage. Reuse the shape `MintABear` set: custom errors, NatSpec on every public
   function, final-state prose.
4. Tests: deterministic unit tests only, one BTT tree leaf per Scenario in
   `test/<Contract>.tree.md`, a `/* Scenario: WL-n — <title> / Given / When / Then */` block
   quoting the spec's Scenario above each test, coverage ≥90 % line / ≥80 % branch, view-only
   tests declared `view`. Fuzz, invariant, mutation, Halmos/Certora and fork tests are the
   internal auditor's — a property that wants one becomes an INV-N or Fork-N line in the tree.
   `test/poc/` regressions stay; a fixed PoC is inverted, never deleted. Signing in tests:
   `vm.sign` with a `makeAddrAndKey` signer over the contract's EIP-712 digest.
5. `/mnt:done` — `forge fmt --check`; `forge build --sizes` warning-free apart from the one
   accepted forge-lint at `src/Activation.sol:120` (`unsafe-typecast`, removed by ACT-1; do not
   silence it); `forge test`; coverage; `slither . --exclude-dependencies` with no new High or
   Critical (a new Medium is an inline justification or a Defect issue);
   `differential-review:diff-review` on the branch diff when the change moves value or gates a
   role (`WhitelistClaim` does: signer role, claim accounting), findings or "none" in the
   In Review comment; merge `--no-ff` into `tranche-1`; tick `tasks.md`; In Review; summary
   comment with files, tests, Scenario ids and commit hash; `log_work`.
6. Repeat from 2. The order in `tasks.md` is deliberate: `WhitelistClaim` (2.1–2.4, live before
   the campaign), then `Activation` and `DirectBurnAdapter` (3.1–3.14), then scripts (4.x).

**Board.** Open → In Progress → In Review is yours; Done and Canceled are mine. Never write
summary, description, Spec Ref, Work Kind, parent, tranche tags, decision State or Due Date —
the bridge owns them from `openspec/`; if the spec must change, `/opsx:propose` a change,
lint, and stop for me. Never delete. Never touch project KNI. A defect in existing code
becomes a Defect issue with `Reproduce` / `Expected` / `Observed`; `tasks.md` §5 items become
`NONE` Tasks under the Milestone they serve (5.1's `MintABear` half is MNT-92; its
`Activation` / `WhitelistClaim` / adapter half is still open).

**Stop and report when:** a Task needs the spec to say something it does not; a gate stays
red for a reason outside the Task; every remaining Task is hard-gated; a board write fails;
or the WL family (tasks 2.1–2.4) is In Review — that is this session's budget; say so and
stop. (Widen the budget to §3 in this line if you want the session to run on into
`Activation`; the ACT tasks will also have to update the COL-4 and COL-5 tests that raise a
level through the fixture's `activation.burn`, which becomes `credit`.)

**Never:** push, merge into `main`, set Done, silence a Slither finding or the accepted lint,
add a fuzz or invariant harness, re-research a verified on-chain fact, or relitigate a settled
decision (the transfer counter, `solc 0.8.17`, validator at deploy, no burn, `MAX_BEARS` in
code, `Activation` never touching the token, credit requires `ownerOf == burner` and an
unchanged counter, the whitelist as an on-chain registry with the holder paying gas).

**End of session:** one message — Tasks moved with issue ids and commit hashes, the state of
`tranche-1`, the next unticked id, anything that needs me.
