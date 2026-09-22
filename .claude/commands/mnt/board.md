---
name: "MNT: Board"
description: "Bring the YouTrack board in line with the spec: validate, lint, render, bridge --write, read back"
allowed-tools: Bash(docs/tools/board.sh:*), Bash(git:*)
---

Run the project's board script and report what it did. The script is the mechanism; this
command is the wrapper that reads its output back to the person.

1. `git status --porcelain -- openspec docs` must be empty, or stop and say what is uncommitted.
   The board only ever carries text that is in git. `--allow-dirty` is for a local trial and
   must be asked for explicitly.
2. Run `docs/tools/board.sh` with the flags the request implies: `--dry` to preview only,
   `--render` when the generated prose blocks need regenerating (then stop: the render must
   be committed before the board is written), `--client-doc` to rebuild the client document.
3. Read the six steps' output. Report, in this order: the lint result; how many issues are
   CURRENT / DRIFTED / NEW / TRACKED BUT EXCLUDED and any DRIFTED body whose Task is In
   Progress (the claimant should re-read it); the manifest path and rollback command; the
   validator's verdict (checks 1–10). A NEW issue on a populated board is unexpected — say so
   before anything else.
4. Never edit an issue by hand to make the validator pass. The fix is in `openspec/`, then
   this command again.
