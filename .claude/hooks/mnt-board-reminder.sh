#!/usr/bin/env bash
# PostToolUse hook (matcher: Bash): after a `git commit` or `git merge` that leaves openspec/ different
# from the tree docs/tools/board.sh last wrote to the board (.git/board-synced-tree),
# tell the session that the spec and the board differ.
# Installed by templates/work-loop/install.sh as .claude/hooks/mnt-board-reminder.sh.
# Silent on anything else; never blocks (exit 0 always).
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
case "$CMD" in *"git commit"*|*"git merge"*) ;; *) exit 0 ;; esac
# The project, not wherever the command cd'd to: a commit in another repository says nothing
# about this board.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$ROOT" ] && [ -d "$ROOT/openspec" ] || exit 0
TREE="$(git -C "$ROOT" rev-parse HEAD:openspec 2>/dev/null)" || exit 0
# board.sh records the openspec/ tree it last wrote from; while HEAD still has that tree,
# the board is current and there is nothing to remind.
SYNCED="$(cat "$(git -C "$ROOT" rev-parse --absolute-git-dir)/board-synced-tree" 2>/dev/null)"
[ "$TREE" = "$SYNCED" ] && exit 0
# No record yet (board.sh never ran here): fall back to "the last commit touched openspec/".
[ -n "$SYNCED" ] || git -C "$ROOT" diff-tree --root --no-commit-id --name-only -r -m HEAD 2>/dev/null | grep -q '^openspec/' || exit 0
MSG="openspec/ differs from the tree the MNT board was last written from. If this branch carries spec work the board lacks, run /mnt:board (docs/tools/board.sh) — after an archive, run docs/tools/spec_tools/fold_archive.py and commit first. On a branch older than the board, there is nothing to do."
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$MSG"
exit 0
