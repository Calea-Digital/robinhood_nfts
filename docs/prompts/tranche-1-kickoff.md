# Tranche 1 — session kickoff prompt

Open a fresh Claude Code session in `~/trees/robinhood_nfts` on **Claude Fable 5.1 (1M context,
effort xhigh)** — the current default in `~/.claude/settings.json`. Paste everything below the
line. The YouTrack connector must be connected (it is account-level; the loop uses it for
every claim and State change). If `/mnt:next` reads as an unknown command, restart the session
once — the commands are new to it.

---

Implement MintABear tranche 1 from the YouTrack MNT board, one requirement Task at a time,
through the project's work loop, until a stop condition below is met. Do not ask me to confirm
each Task; report after each one.

**Read first, in this order:** `CLAUDE.md` — its "Specification and board" section is the
contract for this session, and its architecture sections describe the code on `main` that
tranche 1 rewrites; `docs/HANDOVER.md` — "What is left", "Decisions that should not be
relitigated", "Accepted risks" and "Verified on-chain facts" (never re-research those);
`openspec/changes/tranche-1/proposal.md`, `design.md` and `tasks.md` (the pick order); then,
per Task, the family's spec file under `openspec/specs/`. The web3 workflow is
`~/trees/ai-stack/manual/01-web3.md` W7 (which skill fires at which step) and the process is
`manual/02-spec-driven.md` W5.

**Loop.**
1. `/mnt:resume` — continue a live claim of yours, release a stale one, leave a human's alone.
2. `/mnt:next` — the first unticked id in `tasks.md` that is Open and not hard-gated (a
   `depends on` link to a decision in State Open). CQ-2 is a soft gate: `decimals` is a
   constructor value, so `Activation` is written in base units and the deploy value waits.
   Claim comment first, then State In Progress and the `MNT Claude` tag; branch
   `mnt/<spec-ref>` off `tranche-1` (create `tranche-1` from `main` once).
3. Implement against the Task body. Cite the skill: `[SKILL: openzeppelin-skills:develop-secure-contracts]`
   for OpenZeppelin patterns (EIP-712, ECDSA, ERC-20 interfaces) — SeaDrop's base and
   Solady's utilities win where they differ; `[SKILL: evm-internals]` for storage layout and
   gas; `/solidity` for style. `solc 0.8.17`, evm `london`, no PUSH0, no transient storage.
4. Tests: deterministic unit tests only, one BTT tree leaf per Scenario in `test/<Contract>.tree.md`,
   a `/* Scenario: Given / When / Then */` block quoting the spec's Scenario above each test,
   coverage ≥90% line / ≥80% branch. Fuzz, invariant, mutation, Halmos/Certora and fork tests
   are the internal auditor's — a property that wants one becomes an INV-N line in the tree.
   `test/poc/` regressions stay; a fixed PoC is inverted, never deleted.
5. `/mnt:done` — `forge fmt --check`, warning-free `forge build --sizes`, `forge test`,
   coverage, `slither . --exclude-dependencies` with no new High or Critical (a new Medium is
   an inline justification or a Defect issue); `differential-review:diff-review` on the branch
   diff when the change moves value or gates a role, `dimensional-analysis` read-only on
   base-unit or basis-100 arithmetic (`Activation`, `DirectBurnAdapter`); merge `--no-ff` into
   `tranche-1`; tick `tasks.md`; In Review; summary comment with files, tests, Scenario ids
   and commit hash; `log_work`.
6. Repeat from 2. The order in `tasks.md` is deliberate: the `MintABear` cleanup first
   (ERC-6551 and the renderer out, the reset event and `exists()` in), then `WhitelistClaim`
   (live before the campaign), then `Activation` and `DirectBurnAdapter`, then scripts.

**Board.** Open → In Progress → In Review is yours; Done and Canceled are mine. Never write
summary, description, Spec Ref, Work Kind, parent, tranche tags, decision State or Due Date —
the bridge owns them from `openspec/`; if the spec must change, `/opsx:propose` a change,
lint, and stop for me. Never delete. Never touch project KNI. A defect in existing code
becomes a Defect issue with `Reproduce` / `Expected` / `Observed`; `tasks.md` §5 items become
`NONE` Tasks under the Milestone they serve.

**Stop and report when:** a Task needs the spec to say something it does not; a gate stays
red for a reason outside the Task; every remaining Task is hard-gated; a board write fails;
or the COL family (tasks 1.1–1.12) is In Review — that is this session's budget; say so and
stop.

**Never:** push, merge into `main`, set Done, silence a Slither finding, add a fuzz or
invariant harness, re-research a verified on-chain fact, or relitigate a settled decision
(the transfer counter, `solc 0.8.17`, validator at deploy, no burn, `MAX_BEARS` in code,
`Activation` never touching the token, credit requires `ownerOf == burner` and an unchanged
counter).

**End of session:** one message — Tasks moved with issue ids and commit hashes, the state of
`tranche-1`, the next unticked id, anything that needs me.
