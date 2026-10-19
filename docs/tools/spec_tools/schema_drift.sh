#!/usr/bin/env bash
# Is a project's openspec/schemas/calea-house/ still the master schema?
#   schema_drift.sh <project root> [<master>]     (master default: ~/trees/calea-openspec-schema)
# Exit 0 identical, 1 drifted (the differing files listed), 2 nothing to compare.
# The schema is installed as a plain copy, not a submodule, so nothing else notices
# when the master moves on (MintABear's copy missed the Summary field, b9df6ad).
set -uo pipefail
ROOT="${1:?project root}"; MASTER="${2:-${CALEA_SCHEMA:-$HOME/trees/calea-openspec-schema}}"
COPY="$ROOT/openspec/schemas/calea-house"
[ -d "$COPY" ] || { echo "schema_drift: no schema copy at $COPY"; exit 2; }
[ -d "$MASTER" ] || { echo "schema_drift: master not found at $MASTER (set CALEA_SCHEMA)"; exit 2; }
REV="$(git -C "$MASTER" describe --tags --always 2>/dev/null || echo unknown)"
OUT="$(diff -rq --exclude=.git "$MASTER" "$COPY" 2>&1)"
if [ -z "$OUT" ]; then echo "schema_drift: $COPY matches the master ($REV)"; exit 0; fi
echo "schema_drift: $COPY differs from the master ($REV):"; echo "$OUT" | sed "s#$MASTER#<master>#g; s#$COPY#<copy>#g; s/^/  /"; exit 1
