#!/usr/bin/env bash
# Offline checks of script/verify.sh's verdict (OPS-3), run in CI beside the dry run. Sourcify's
# answers come from test/fixtures/sourcify/ through a file:// SOURCIFY_URL; nothing touches the
# network, and --check submits nothing.
set -uo pipefail
cd "$(dirname "$0")/.."
BROADCAST=test/fixtures/broadcast
fail=0

expect() { # <description> <expected exit> <expected output pattern> -- <command...>
  local what="$1" want="$2" pattern="$3"; shift 4
  local out code
  out="$("$@" 2>&1)"; code=$?
  if [ "$code" -ne "$want" ] || ! grep -qE "$pattern" <<< "$out"; then
    echo "FAIL  $what: exit $code (want $want)"; echo "$out" | sed 's/^/      /'; fail=1
  else
    echo "ok    $what"
  fi
}

expect "every contract verified: exit 0" 0 "verified  Activation .*\(match\)" -- \
  env SOURCIFY_URL="file://$PWD/test/fixtures/sourcify/all-verified" \
  bash script/verify.sh 46630 --check --broadcast-dir "$BROADCAST"

expect "one contract unverified: exit 1, named MISSING" 1 "MISSING   Activation" -- \
  env SOURCIFY_URL="file://$PWD/test/fixtures/sourcify/one-missing" \
  bash script/verify.sh 46630 --check --broadcast-dir "$BROADCAST"

expect "no Sourcify answer at all: exit 1" 1 "MISSING   WhitelistClaim" -- \
  env SOURCIFY_URL="file://$PWD/test/fixtures/sourcify/absent" \
  bash script/verify.sh 46630 --check --broadcast-dir "$BROADCAST"

expect "broadcasts that created nothing: exit 2" 2 "no contract created" -- \
  bash script/verify.sh 46630 --check --broadcast-dir test/fixtures/broadcast-no-create

expect "no broadcast for the chain: exit 2" 2 "no Deploy.s.sol broadcast for chain 1" -- \
  bash script/verify.sh 1 --check --broadcast-dir "$BROADCAST"

expect "a contract it does not know: exit 2" 2 "unknown contract in broadcast: Stranger" -- \
  bash script/verify.sh 46630 --check --broadcast-dir test/fixtures/broadcast-unknown

exit "$fail"
