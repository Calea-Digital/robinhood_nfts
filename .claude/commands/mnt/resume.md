---
name: "MNT: Resume"
description: "Find the requirement this session (or a stale session) claimed and continue it"
allowed-tools: Bash(git:*), Bash(openspec:*), mcp__claude_ai_YouTrack__search_issues, mcp__claude_ai_YouTrack__get_issue, mcp__claude_ai_YouTrack__get_issue_comments, mcp__claude_ai_YouTrack__add_issue_comment, mcp__claude_ai_YouTrack__update_issue, mcp__claude_ai_YouTrack__manage_issue_tags
---

Resume claimed work on the MNT board.

1. `search_issues` for `project: MNT Type: Task Work Kind: Feature State: {In Progress}`.
2. For each, `get_issue_comments`. **No `Claim` comment → a human's; leave it alone.**
3. A claim is **stale** when it is older than 24 hours and its branch `<ns>/<spec-ref>` has no
   commit since the claim (`git log --since`). Release it: comment `Released <nonce> — stale`,
   `update_issue` State → Open, `manage_issue_tags` remove `MNT Claude`. Say so.
4. If exactly one live claim remains, continue it: `git switch <ns>/<spec-ref>`, re-read the
   Task body (the bridge may have refreshed it — the board reports DRIFTED In Progress bodies),
   re-read the plan checklist in the claim comment, pick up at the first unticked step. If
   several remain, list them and ask which.
5. If none remain, say so and offer `/mnt:next`.
