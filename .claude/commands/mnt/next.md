---
name: "MNT: Next"
description: "Pick the next requirement Task from the board, claim it, plan it in the claim comment, branch and start"
allowed-tools: Bash(git:*), Bash(openspec:*), Bash(forge:*), mcp__claude_ai_YouTrack__search_issues, mcp__claude_ai_YouTrack__get_issue, mcp__claude_ai_YouTrack__get_issue_comments, mcp__claude_ai_YouTrack__add_issue_comment, mcp__claude_ai_YouTrack__update_issue, mcp__claude_ai_YouTrack__manage_issue_tags, mcp__claude_ai_YouTrack__create_issue, mcp__claude_ai_YouTrack__link_issues
---

Pick up the next requirement from the MNT board and start it. The unit of work is a
requirement Task; the plan lives in the claim comment; Subtasks are the exception.

**Order.** Read the active OpenSpec change's `tasks.md` (`openspec list --json`; if more than
one change is active, ask which). Its unticked lines are the pick order, one requirement id
per line. The first unticked id is the candidate. `$ARGUMENTS` may name an id instead.

**Confirm on the board.** `search_issues` for `project: MNT Type: Task Work Kind: Feature`
and find the Task whose Spec Ref is the candidate (Spec Ref is a text field: match
client-side, never by query). It must be `State: Open`. If it is In Progress with a claim
comment, skip to the next id; if it is In Progress with no claim comment, a human has it —
skip. Then `get_issue`: a `depends on` link to a decision Task in State **Open** is a hard
gate (the shape is undecided) — skip and say why. A decision **In Progress** (follow-up) is a
soft gate — proceed and name the remaining item in the claim.

**Claim, server-ordered.** Generate a nonce (8 hex chars). Post the claim comment FIRST:

```
Claim <nonce> · Claude Code · branch <ns>/<spec-ref> · <UTC ISO time>
Plan:
- [ ] <step>
- [ ] <step>
Soft gate: <decision id and its remaining item, or "none">
```

Then `get_issue_comments` and read every `Claim` comment newer than the last `Released`
comment: the earliest wins. If ours is not the earliest, post `Yielded <nonce>` and pick the
next id. If ours wins, `update_issue` State → **In Progress** and `manage_issue_tags` add
`MNT Claude`. Assignee stays human-owned.

**Branch and work.** `git switch -c <ns>/<spec-ref>` from the current default branch. Read the
Task body: the statement, `Done when` (the spec's Scenario — the definition of done) and
`Gates`. Work per `CLAUDE.md`: a BTT tree leaf per Scenario, a `/* Scenario: */` block above
each test quoting the spec's Scenario, deterministic tests only, never a fuzz or invariant
harness. Tick plan steps in the claim comment as they complete (edit the comment or post a
follow-up).

**Subtask, exception path.** Only when a step has another owner or must be tracked on its own
(a value MINT must supply, a human rehearsal step): `create_issue` with `parentIssue` = the
Task, Type Subtask, Work Kind Feature, Spec Ref = the parent's exactly, summary in the
imperative.

**Non-spec work.** A `tasks.md` line that names no requirement (rewrite `CLAUDE.md`, rewrite
the trees) becomes a Task with Spec Ref `NONE`, Work Kind Feature, `parentIssue` = the
Milestone it serves, claimed the same way.

**Never.** Never edit summary, description, Spec Ref, Work Kind, parent, tranche tags,
decision State or Due Date — those are the bridge's from the spec. Never set Done. Never
delete. Never touch another project.
