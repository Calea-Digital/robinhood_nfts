---
name: "MNT: Done"
description: "Finish the claimed requirement: run the gates, tick tasks.md, set In Review, summarise, log time"
allowed-tools: Bash(git:*), Bash(forge:*), Bash(openspec:*), mcp__claude_ai_YouTrack__search_issues, mcp__claude_ai_YouTrack__get_issue, mcp__claude_ai_YouTrack__get_issue_comments, mcp__claude_ai_YouTrack__add_issue_comment, mcp__claude_ai_YouTrack__update_issue, mcp__claude_ai_YouTrack__log_work
---

Close out the requirement this session claimed (`$ARGUMENTS` may name the Spec Ref; else the
one whose claim comment carries this session's nonce, or ask).

1. **Gates, all green or stop** — they are the Task's `Gates` line, read from the spec:
   `forge fmt --check`; `forge build --sizes` with no warning; `forge test`;
   `forge coverage --no-match-coverage 'test/|lib/'` at ≥90% line / ≥80% branch;
   `slither . --exclude-dependencies` with no new High or Critical (a new Medium is an inline
   justification in the code or a Defect issue with a `Reproduce` section — never silence).
   Every Scenario in the Task's `Done when` has a test carrying it in its `/* Scenario: */`
   block and a leaf in the contract's tree. No fuzz or invariant harness was added — those
   are the internal auditor's. If anything fails, fix it or stop and report — never mark done
   around a red gate.
2. **Self-review** when the change moves value, checks ownership or gates a role: run the
   `differential-review:diff-review` skill on `git diff <default branch>...HEAD` and, for
   unit or decimal arithmetic, the `dimensional-analysis` validator read-only. Findings, or
   "none", go in the In Review comment; a real finding is fixed before In Review.
3. **Commit** on the `<ns>/<spec-ref>` branch with a message that names the Spec Ref, then
   merge it into the integration branch with `git switch <change> && git merge --no-ff
   <ns>/<spec-ref>` so the next Task builds on it (the merge commit is the Task boundary the
   reviewer reads). Never merge into the default branch and never push unless asked.
4. **Tick** the requirement's line in the active change's `tasks.md` (`- [ ]` → `- [x]`) and
   commit that too.
5. **Board:** `update_issue` State → **In Review**. Post a summary comment: files changed,
   tests added (names), Scenario ids covered, the commit hash, anything left for the reviewer.
   `log_work` the time spent (type Development or Testing, whole minutes, honest).
6. **Never set Done.** The human reviews and sets Done or Canceled. Never edit the bridge's
   fields (summary, body, Spec Ref, Work Kind, parent, tranche tags, decision State, Due Date).
7. Report: the Spec Ref, the branch, the gates' results, the comment's gist, and the next
   unticked id in `tasks.md`.
