#!/usr/bin/env bash
# Spec edit → board current, one command. Installed as docs/tools/board.sh.
#
#   docs/tools/board.sh            validate, lint, render --check, bridge --check-existing, --write, validate --check-issues
#   docs/tools/board.sh --dry      stop after --check-existing (no writes)
#   docs/tools/board.sh --render   rewrite the generated prose blocks first (then commit before writing to the board)
#   docs/tools/board.sh --client-doc   also rebuild the client document afterwards
#   docs/tools/board.sh --allow-dirty  let uncommitted spec text reach the board (local trials only)
#
# Needs: the openspec CLI, /usr/bin/python3 (the interpreter with `requests`),
# the ai-stack checkout (AI_STACK, default ~/trees/ai-stack) and its bridge .env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AI_STACK="${AI_STACK:-$HOME/trees/ai-stack}"
BRIDGE="$AI_STACK/scripts/youtrack-bridge"
PY="${BOARD_PYTHON:-/usr/bin/python3}"
PROJECT="${BOARD_PROJECT:-MNT}"
OVERRIDES="${BOARD_OVERRIDES:-$BRIDGE/overrides/$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]').json}"
TOOLS="$ROOT/docs/tools/spec_tools"

DRY=0; RENDER=0; CLIENT_DOC=0; ALLOW_DIRTY=""
for arg in "$@"; do
  case "$arg" in
    --dry) DRY=1 ;;
    --render) RENDER=1 ;;
    --client-doc) CLIENT_DOC=1 ;;
    --allow-dirty) ALLOW_DIRTY="--allow-dirty" ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

if [ "$PROJECT" = "MNT" ]; then echo "board.sh: set BOARD_PROJECT (install.sh normally substitutes it)" >&2; exit 2; fi
if [ ! -d "$BRIDGE" ]; then echo "board.sh: ai-stack bridge not found at $BRIDGE (set AI_STACK)" >&2; exit 2; fi

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "1/6 openspec validate --specs (non-strict: Calea prose is declarative, the SHALL/MUST warning is style)"
(cd "$ROOT" && openspec validate --specs)

step "2/6 lint (Kind and Scenario in change deltas, open items vs register, ids)"
"$PY" "$TOOLS/lint_spec.py" --root "$ROOT"

if [ "$RENDER" = 1 ]; then
  step "3/6 render generated prose blocks"
  "$PY" "$TOOLS/render_calea_prose.py" --root "$ROOT" --write
else
  step "3/6 render --check (generated prose blocks are current)"
  "$PY" "$TOOLS/render_calea_prose.py" --root "$ROOT" --check
fi

if [ -z "$ALLOW_DIRTY" ] && [ -n "$(git -C "$ROOT" status --porcelain -- openspec docs)" ]; then
  echo; echo "REFUSED: openspec/ or docs/ has uncommitted changes. Commit them, then re-run — the board only carries text that is in git. (--allow-dirty for a local trial.)" >&2
  exit 2
fi

if [ -f "$BRIDGE/.env" ]; then set -a; . "$BRIDGE/.env"; set +a; fi
COMMON=(--openspec-root "$ROOT/openspec" --project "$PROJECT")
[ -f "$OVERRIDES" ] && COMMON+=(--overrides "$OVERRIDES")

step "4/6 bridge --check-existing (what would change)"
"$PY" "$BRIDGE/bridge.py" "${COMMON[@]}" --check-existing | grep -vE '^\s+\[' || true

if [ "$DRY" = 1 ]; then echo; echo "--dry: stopping before any write."; exit 0; fi

step "5/6 bridge --write"
"$PY" "$BRIDGE/bridge.py" "${COMMON[@]}" --write $ALLOW_DIRTY | grep -vE '^\s+\[' || true

step "6/6 validate --check-issues (reads the board back: checks 1–10)"
"$PY" "$BRIDGE/validate.py" "${COMMON[@]}" --check-issues

if [ "$CLIENT_DOC" = 1 ]; then
  step "client document"
  (cd "$ROOT" && python3 docs/tools/build_client_doc.py)
fi
