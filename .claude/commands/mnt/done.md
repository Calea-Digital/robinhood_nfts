---
name: "MNT: Done"
description: "Finish the claimed requirement: run the gates, tick tasks.md, set In Review, summarise, log time"
allowed-tools: Bash(git:*), Bash(forge:*), Bash(pnpm:*), Bash(slither:*), Bash(bash ../NFT/packages/contracts/script/verify.sh:*), Bash(bash ../NFT/packages/contracts/test/verify.test.sh:*), Bash(python3 docs/tools/check_scenario_quotes.py:*), Bash(openspec:*), mcp__claude_ai_YouTrack__search_issues, mcp__claude_ai_YouTrack__get_issue, mcp__claude_ai_YouTrack__get_issue_comments, mcp__claude_ai_YouTrack__add_issue_comment, mcp__claude_ai_YouTrack__update_issue, mcp__claude_ai_YouTrack__log_work
---

Close out the requirement this session claimed (`$ARGUMENTS` may name the Spec Ref; else the
one whose claim comment carries this session's nonce, or ask). A claimed Defect (a
`(Defect MNT-n)` line in `tasks.md`) closes the same way: its branch is
`<ns>/<spec-ref>-<n>`, its commit names both the Spec Ref and `MNT-n`, the line ticked is the
Defect line, and the issue moved to In Review is the Defect — never the requirement's Task.

The code is in `../NFT` (MINT's repository); the spec, `tasks.md` and these commands are here.
Read CLAUDE.md "Two repositories" first: never touch `release/1.0` or `main` there, no `MNT-n`
ids in anything committed there, nothing private there.

1. **Gates, all green or stop** — they are the Task's `Gates` line, read from the spec. In
   `../NFT/packages/contracts` (`git -C ../NFT`, `forge … --root ../NFT/packages/contracts`):
   `forge fmt --check`; `forge build --sizes` with no warning; `forge test`;
   `forge coverage --no-match-coverage 'test/|lib/'` at ≥90% line / ≥80% branch;
   `slither . --exclude-dependencies` with no new High or Critical (a new Medium is an inline
   justification in the code or a Defect issue with a `Reproduce` section — never silence);
   `bash script/verify.sh 46630 --dry-run --broadcast-dir test/fixtures/broadcast` diffed
   against `test/fixtures/verify-dry-run.expected`, and `bash test/verify.test.sh`. Then the
   client, after `forge build`: `pnpm run check` in `../NFT/packages/contracts-client`
   (ABI drift, typecheck, build, vitest). A dependency change also re-runs the Dockerfiles'
   frozen installs and MINT's apps' tests (CLAUDE.md, "Two repositories").
   Every Scenario in the Task's `Done when` has a test carrying it in its `/* Scenario: */`
   block and a leaf in the contract's tree: `python3 docs/tools/check_scenario_quotes.py`
   here, with no new failure. No fuzz or invariant harness was added — those
   are the internal auditor's. If anything fails, fix it or stop and report — never mark done
   around a red gate.
2. **Self-review** when the change moves value, checks ownership or gates a role: run the
   `differential-review:diff-review` skill on `git diff <default branch>...HEAD` and, for
   unit or decimal arithmetic, the `dimensional-analysis` validator read-only. Findings, or
   "none", go in the In Review comment; a real finding is fixed before In Review.
3. **Commit** in `../NFT` on the `<ns>/<spec-ref>` branch, in NFT's style (one plain
   imperative sentence; the Spec Ref may appear, an `MNT-n` id never), then merge it into the
   code integration branch named in CLAUDE.md (`feat/contracts`) with
   `git -C ../NFT switch feat/contracts && git -C ../NFT merge --no-ff <ns>/<spec-ref>`, so the
   next Task builds on it (the merge commit is the Task boundary the reviewer reads). Never
   touch `release/1.0` or `main`, never push and never open a PR unless asked.
4. **Tick** the requirement's line in the active change's `tasks.md` here (`- [ ]` → `- [x]`)
   and commit that here, naming the Spec Ref, the `MNT-n` and the NFT merge commit.
5. **Board:** `update_issue` State → **In Review**. Post a summary comment (`In Review <nonce>` first): files changed,
   tests added (names), Scenario ids covered, the NFT merge commit, anything left for the reviewer.
   `log_work` the time spent (type Development or Testing, whole minutes, honest).
6. **Never set Done.** The human reviews and sets Done or Canceled. Never edit the bridge's
   fields (summary, body, Spec Ref, Work Kind, parent, tranche tags, decision State, Due Date).
7. Report: the Spec Ref, the branch, the gates' results, the comment's gist, and the next
   unticked id in `tasks.md`.
