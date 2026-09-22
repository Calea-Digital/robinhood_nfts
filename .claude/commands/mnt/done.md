---
name: "MNT: Done"
description: "Finish the claimed requirement: run the gates, tick tasks.md, set In Review, summarise, log time"
allowed-tools: Bash(git:*), Bash(forge:*), Bash(openspec:*), mcp__claude_ai_YouTrack__search_issues, mcp__claude_ai_YouTrack__get_issue, mcp__claude_ai_YouTrack__get_issue_comments, mcp__claude_ai_YouTrack__add_issue_comment, mcp__claude_ai_YouTrack__update_issue, mcp__claude_ai_YouTrack__log_work
---

Close out the requirement this session claimed (`$ARGUMENTS` may name the Spec Ref; else the
one whose claim comment carries this session's nonce, or ask).

1. **Gates, all green or stop:** `forge fmt --check`, `forge build --sizes`, `forge test`,
   `forge coverage --no-match-coverage 'test/|lib/'` at ≥90% line / ≥80% branch. Every
   Scenario in the Task's `Done when` has a test carrying it in its `/* Scenario: */` block
   and a leaf in the contract's tree. If anything fails, fix it or stop and report — never
   mark done around a red gate.
2. **Commit** on the `<ns>/<spec-ref>` branch with a message that names the Spec Ref. Do not
   push or merge unless asked.
3. **Tick** the requirement's line in the active change's `tasks.md` (`- [ ]` → `- [x]`) and
   commit that too.
4. **Board:** `update_issue` State → **In Review**. Post a summary comment: files changed,
   tests added (names), Scenario ids covered, the commit hash, anything left for the reviewer.
   `log_work` the time spent (type Development or Testing, whole minutes, honest).
5. **Never set Done.** The human reviews and sets Done or Canceled. Never edit the bridge's
   fields (summary, body, Spec Ref, Work Kind, parent, tranche tags, decision State, Due Date).
6. Report: the Spec Ref, the branch, the gates' results, the comment's gist, and the next
   unticked id in `tasks.md`.
