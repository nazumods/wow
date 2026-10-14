#!/usr/bin/env bash
# Tests for the two bash functions .github/workflows/publish.yml uses to decide which CurseForge
# game versions a release is labelled with (nazumods/wow#954):
#
#   iface_to_version  `## Interface:` value -> X.Y.Z   (16001 -> 1.60.1, NOT 16.0.1)
#   missing_versions  which wanted names CurseForge does not know
#
# The functions live INLINE in publish.yml (between `# BEGIN <name>` / `# END <name>` markers), not
# in a sourced helper: publish.yml checks out the release TAG, so a helper file added later would be
# missing when an older tag is re-published through workflow_dispatch. This test extracts them from
# the YAML, so it exercises the shipped text verbatim.
#
# Usage:
#   bash Tooling/tests/game-versions.test.sh
#   PUBLISH_YML=/path/to/copy.yml bash Tooling/tests/game-versions.test.sh   # run against a scratch
#                                                                             # copy, e.g. a mutation
# Exit 0 = every case passed; 1 = a case failed or a marker block is missing.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PUBLISH_YML="${PUBLISH_YML:-$REPO_ROOT/.github/workflows/publish.yml}"

[[ -f "$PUBLISH_YML" ]] || { echo "FAIL: $PUBLISH_YML does not exist"; exit 1; }

# Print the body of the marker block named $1: CRs dropped (a Windows checkout), YAML indentation
# stripped. Fails loudly unless there is exactly one BEGIN and one END marker and the block defines
# the function -- a silently empty extraction would make every case below fail for the wrong reason.
extract_block() {
  local name="$1" begins ends block
  begins=$(grep -cE "# BEGIN ${name}( |\$)" "$PUBLISH_YML" || true)
  ends=$(grep -cE "# END ${name}( |\$)" "$PUBLISH_YML" || true)
  if [[ "$begins" != 1 || "$ends" != 1 ]]; then
    echo "FAIL: expected exactly one '# BEGIN ${name}' and one '# END ${name}' marker in $PUBLISH_YML (found $begins and $ends)" >&2
    return 1
  fi
  block=$(tr -d '\r' < "$PUBLISH_YML" \
    | sed -nE "/# BEGIN ${name}( |\$)/,/# END ${name}( |\$)/p" \
    | sed 's/^[[:space:]]*//')
  if ! grep -qE "^${name}\(\) \{" <<< "$block"; then
    echo "FAIL: the ${name} marker block in $PUBLISH_YML does not define ${name}()" >&2
    return 1
  fi
  printf '%s\n' "$block"
}

for fn in iface_to_version missing_versions; do
  block=$(extract_block "$fn") || exit 1
  eval "$block"
done

failures=0

check() { # name expected actual
  if [[ "$3" == "$2" ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    failures=$((failures + 1))
  fi
}

# --- iface_to_version: read from the right, so a 5-digit value keeps its one-digit major ---------
check "iface 16001 (Forever)       -> 1.60.1" "1.60.1" "$(iface_to_version 16001)"
check "iface 120105 (Retail)       -> 12.1.5" "12.1.5" "$(iface_to_version 120105)"
check "iface 11509 (Classic Era)   -> 1.15.9" "1.15.9" "$(iface_to_version 11509)"
check "iface ' 16001 ' (spaces)    -> 1.60.1" "1.60.1" "$(iface_to_version ' 16001 ')"
# 09 / 08 are invalid octal; the 10# prefix is what keeps them decimal.
check "iface 110009 (leading zero) -> 11.0.9" "11.0.9" "$(iface_to_version 110009)"

# A value that is not 5-6 digits must fail, and say so on STDERR: the caller captures stdout with
# $(...), so a message written to stdout would be swallowed instead of reaching the workflow log.
check_rejects() { # label value
  local label="$1" value="$2" out err rc=0
  err=$(iface_to_version "$value" 2>&1 >/dev/null) || rc=$?
  out=$(iface_to_version "$value" 2>/dev/null) || true
  if [[ "$rc" != 0 && -z "$out" && "$err" == "::error::Unrecognised Interface value '$value'"* ]]; then
    echo "PASS $label rejected (non-zero, error on stderr only)"
  else
    echo "FAIL $label: rc=$rc stdout='$out' stderr='$err'"
    failures=$((failures + 1))
  fi
}
check_rejects "iface 'abc'" "abc"
check_rejects "iface 1234567 (7 digits)" "1234567"
check_rejects "iface 1600 (4 digits)" "1600"
check_rejects "iface '' (empty)" ""

# --- missing_versions: whole-name, fixed-string matches ------------------------------------------
check "missing: all known              -> (none)" "" "$(missing_versions $'12.1.5\n1.60.1' '12.1.5,1.60.1')"
check "missing: 1.60.1 unknown         -> 1.60.1" "1.60.1" "$(missing_versions $'12.1.5' '12.1.5,1.60.1')"
check "missing: two unknown            -> 'a b'" "a b" "$(missing_versions '' 'a,b')"
check "missing: prefix is not a match  -> 1.60" "1.60" "$(missing_versions $'1.60.1' '1.60')"
check "missing: suffix is not a match  -> 1.60.1" "1.60.1" "$(missing_versions $'11.60.1' '1.60.1')"
check "missing: '.' is not a wildcard  -> 1.60.1" "1.60.1" "$(missing_versions $'1x60x1' '1.60.1')"

if [[ "$failures" != 0 ]]; then
  echo "FAILED: $failures case(s)"
  exit 1
fi
echo "OK: all cases passed"
