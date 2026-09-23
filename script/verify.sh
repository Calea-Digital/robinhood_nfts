#!/usr/bin/env bash
# Verify on Sourcify every contract a script/Deploy.s.sol broadcast created, then check each one
# is verified there (OPS-3). Sourcify is the route on Robinhood Chain: mainnet Blockscout's API sits
# behind a bot challenge.
#
#   script/verify.sh <chainId>                 verify every created contract, then check them all
#   script/verify.sh <chainId> --check         only check (no submission)
#   script/verify.sh <chainId> --dry-run       print what would be sent; touch no network
#   script/verify.sh <chainId> --broadcast-dir <dir>   read broadcasts from <dir> instead of ./broadcast
#
# Exits non-zero unless every contract is verified (exact or partial match). The deploy commands
# already pass `--verify --verifier sourcify`; this is for a retry, a partial failure, or a check.
# SOURCIFY_URL overrides the server (default https://sourcify.dev/server).
set -euo pipefail

CHAIN="${1:?usage: script/verify.sh <chainId> [--check|--dry-run] [--broadcast-dir <dir>]}"
shift
MODE="verify"; DIR="broadcast"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --dry-run) MODE="dry-run" ;;
    --broadcast-dir) DIR="${2:?--broadcast-dir needs a path}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
SOURCIFY_URL="${SOURCIFY_URL:-https://sourcify.dev/server}"

# Source path of each contract the deploy script creates.
source_of() {
  case "$1" in
    MintABear) echo "src/MintABear.sol:MintABear" ;;
    WhitelistClaim) echo "src/WhitelistClaim.sol:WhitelistClaim" ;;
    Activation) echo "src/Activation.sol:Activation" ;;
    DirectBurnAdapter) echo "src/DirectBurnAdapter.sol:DirectBurnAdapter" ;;
    *) echo "" ;;
  esac
}

FILES=()
for entry in runWhitelist runCollection runActivation; do
  f="$DIR/Deploy.s.sol/$CHAIN/$entry-latest.json"
  [ -f "$f" ] && FILES+=("$f")
done
if [ ${#FILES[@]} -eq 0 ]; then
  echo "no Deploy.s.sol broadcast for chain $CHAIN under $DIR" >&2
  exit 2
fi

# name<TAB>address for every CREATE, in broadcast order.
CREATED="$(jq -r '.transactions[] | select(.transactionType == "CREATE") | "\(.contractName)\t\(.contractAddress)"' "${FILES[@]}")"

failed=0
while IFS=$'\t' read -r name address; do
  [ -z "$name" ] && continue
  src="$(source_of "$name")"
  if [ -z "$src" ]; then echo "unknown contract in broadcast: $name" >&2; exit 2; fi

  if [ "$MODE" = "dry-run" ]; then
    echo "forge verify-contract --verifier sourcify --chain $CHAIN $address $src"
    echo "GET $SOURCIFY_URL/v2/contract/$CHAIN/$address"
    continue
  fi
  if [ "$MODE" = "verify" ]; then
    forge verify-contract --verifier sourcify --chain "$CHAIN" "$address" "$src" || true
  fi
  match="$(curl -fsS "$SOURCIFY_URL/v2/contract/$CHAIN/$address" | jq -r '.match // "none"' 2>/dev/null || echo "none")"
  case "$match" in
    exact_match|match) echo "verified  $name $address ($match)" ;;
    *) echo "MISSING   $name $address ($match)"; failed=1 ;;
  esac
done <<< "$CREATED"

exit "$failed"
