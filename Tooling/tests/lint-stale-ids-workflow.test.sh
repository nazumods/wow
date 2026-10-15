#!/usr/bin/env bash
# Tests for how .github/workflows/lint-stale-ids.yml and the stale-ids job in test.yml pick the wago
# build to lint (nazumods/wow#954). Two layers, both reading the SHIPPED text of the workflows:
#
#   1. the "Resolve wago build" step of lint-stale-ids.yml, extracted by step name and run under
#      `bash -e` (GitHub's default shell: no pipefail) against a stub `curl` that serves a fixture
#      modelled on wago's /api/builds: a shared Classic-beta bucket that lists a 5.5 build first, then
#      Forever's 1.60.1 builds in the OPPOSITE of wago's real order (every live family is listed
#      newest-first; here the older build comes first, so a pick by position cannot pass), with version
#      look-alikes that are NEWER than them.
#   2. text pins for the wiring no script can see: the product/prefix env vars, the product in the
#      cache key and in the lint call, the gate on the notify job, and `--event schedule`.
#
# Usage:
#   bash Tooling/tests/lint-stale-ids-workflow.test.sh
#   LINT_YML=<copy> TEST_YML=<copy> bash Tooling/tests/lint-stale-ids-workflow.test.sh   # a mutation
# Needs bash, awk, sed, grep and jq (all preinstalled on GitHub's ubuntu runners). The helpers mirror
# game-versions.test.sh, which is the same idea for publish.yml. Exit 0 = every case passed; 1 = a case
# failed or the YAML no longer has the expected shape.
# shellcheck disable=SC2016  # the single-quoted '${{ ... }}' strings are literal GitHub expressions on purpose
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LINT_YML="${LINT_YML:-$REPO_ROOT/.github/workflows/lint-stale-ids.yml}"
TEST_YML="${TEST_YML:-$REPO_ROOT/.github/workflows/test.yml}"

for f in "$LINT_YML" "$TEST_YML"; do
  [[ -f "$f" ]] || { echo "FAIL: $f does not exist"; exit 1; }
done
command -v jq > /dev/null || { echo "FAIL: jq is required (the resolve step pipes through it)"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The workflows' layout, which these helpers rely on: steps are `      - name: ...` (6 spaces), their
# keys sit at 8, and a `run: |` body at 10. Reads to EOF (no early `exit`): under `pipefail` an awk that
# quit while `tr` still had bytes to write would turn into a SIGPIPE failure of the whole pipeline.
step_block() { # file step-name -> the whole step (name line through the line before the next step)
  tr -d '\r' < "$1" | awk -v want="      - name: $2" '
    $0 == want { instep = 1; print; next }
    instep && /^      - / { instep = 0; next }
    instep { print }'
}

step_script() { # file step-name -> the step's `run:` script with the YAML indentation removed
  local out
  out=$(step_block "$1" "$2" | awk '
    !done && !inrun && /^        run: \|[[:space:]]*$/ { inrun = 1; next }
    inrun {
      if ($0 ~ /^[[:space:]]*$/) { print ""; next }
      if (substr($0, 1, 10) != "          ") { inrun = 0; done = 1; next }
      print substr($0, 11)
    }')
  if [[ -z "$out" ]]; then
    echo "FAIL: no step named '$2' with a 'run: |' body in $1" >&2
    return 1
  fi
  printf '%s\n' "$out"
}

failures=0

check() { # name expected actual
  if [[ "$3" == "$2" ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    failures=$((failures + 1))
  fi
}

assert_has() { # name haystack needle (fixed string)
  if grep -qF -- "$3" <<< "$2"; then
    echo "PASS $1"
  else
    echo "FAIL $1: missing '$3' in: $2"
    failures=$((failures + 1))
  fi
}

assert_lacks() { # name haystack needle (fixed string)
  if grep -qF -- "$3" <<< "$2"; then
    echo "FAIL $1: unexpected '$3' in: $2"
    failures=$((failures + 1))
  else
    echo "PASS $1"
  fi
}

# A whole line of $2 equals the text $3.
assert_line() { # name file text
  if grep -qxF -- "$3" <<< "$(tr -d '\r' < "$2")"; then
    echo "PASS $1"
  else
    echo "FAIL $1: no line equal to '$3' in $2"
    failures=$((failures + 1))
  fi
}

# --- 1. the "Resolve wago build" step ---------------------------------------------------------------

RESOLVE_SCRIPT="$WORK/resolve-step.sh"
step_script "$LINT_YML" "Resolve wago build" > "$RESOLVE_SCRIPT"
if grep -q '\${{' "$RESOLVE_SCRIPT"; then
  echo "FAIL: 'Resolve wago build' has a GitHub expression this test does not substitute"
  exit 1
fi

# wago lists wow_classic_beta as whole families one after another (5.5 first); Forever's 1.60.1 builds
# are listed OLDEST first here, to prove the pick is by date and not by position; and two look-alikes
# that are newer than any 1.60.1 build ('11.60.0.9999' contains '1.60.'; '1.600.0.1' starts with '1.60')
# are what a Contains() match or a prefix without its dot would pick.
BUILDS='{
 "wow_classic_beta": [
  {"product":"wow_classic_beta","version":"5.5.0.62071","created_at":"2025-07-18 01:19:04"},
  {"product":"wow_classic_beta","version":"1.60.1.70338","created_at":"2026-10-10 05:05:05"},
  {"product":"wow_classic_beta","version":"1.60.1.70374","created_at":"2026-10-13 23:25:05"},
  {"product":"wow_classic_beta","version":"11.60.0.9999","created_at":"2026-10-14 00:00:00"},
  {"product":"wow_classic_beta","version":"1.600.0.1","created_at":"2026-10-14 01:00:00"},
  {"product":"wow_classic_beta","version":"3.4.0.50000","created_at":"2024-01-01 00:00:00"}
 ],
 "wow": [
  {"product":"wow","version":"12.1.5.70391","created_at":"2026-10-13 21:16:02"}
 ]
}'

mkdir -p "$WORK/bin"
# Records its arguments, one call per line. The URL is always the last argument. STUB_MODE=fail acts like
# a server answering with an HTTP error under -f (curl exits 22 with no body; an unreachable server would
# exit 6, 7 or 28, and takes the same failing path); html acts like a captive page / error page.
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_ARGS_FILE"
case "${STUB_MODE:-ok}" in
  fail) exit 22 ;;
  html) printf '%s' '<html>oops</html>'; exit 0 ;;
esac
url="${*: -1}"
case "$url" in
  https://wago.tools/api/builds) printf '%s' "$STUB_BUILDS" ;;
  https://wago.tools/api/builds/*/latest) printf '{"version":"%s"}' "$STUB_LATEST" ;;
  *) exit 22 ;;
esac
EOF
chmod +x "$WORK/bin/curl"

# run_resolve <product> <prefix-or-empty> <mode> -> R_RC, R_OUT (GITHUB_OUTPUT), R_LOG, R_ARGS (curl calls)
run_resolve() {
  rm -f "$WORK/curl-args"; : > "$WORK/gh-output"
  R_RC=0
  R_LOG=$(PATH="$WORK/bin:$PATH" STUB_MODE="$3" STUB_BUILDS="$BUILDS" STUB_LATEST="9.9.9.1" \
    STUB_ARGS_FILE="$WORK/curl-args" GITHUB_OUTPUT="$WORK/gh-output" \
    WAGO_PRODUCT="$1" WAGO_VERSION_PREFIX="$2" bash -e "$RESOLVE_SCRIPT" 2>&1) || R_RC=$?
  R_OUT=$(cat "$WORK/gh-output")
  R_ARGS=$(cat "$WORK/curl-args" 2>/dev/null || true)
}

run_resolve wow_classic_beta "1.60." ok
check "resolve: Forever family            rc" "0" "$R_RC"
check "resolve: Forever family            newest by date" "version=1.60.1.70374" "$R_OUT"
assert_has "resolve: Forever family            reads the full builds list" "$R_ARGS" "https://wago.tools/api/builds"
assert_lacks "resolve: Forever family            never uses /latest" "$R_ARGS" "/latest"
assert_has "resolve: Forever family            identifies itself" "$R_ARGS" "Warbandeer-suite-ci"

run_resolve wow_classic_beta "5.5." ok
check "resolve: another family            picks it" "version=5.5.0.62071" "$R_OUT"

run_resolve wow_classic_beta "7." ok
check "resolve: empty family              rc" "1" "$R_RC"
assert_has "resolve: empty family              names it" "$R_LOG" "::error::No wago 'wow_classic_beta' build starting '7.'"
assert_lacks "resolve: empty family              writes no version" "$R_OUT" "version="

run_resolve nonesuch "1." ok
check "resolve: unknown product           rc" "1" "$R_RC"
assert_has "resolve: unknown product           names it" "$R_LOG" "::error::No wago 'nonesuch' build starting '1.'"
assert_lacks "resolve: unknown product           writes no version" "$R_OUT" "version="

run_resolve wow_classic_beta "1.60." fail
check "resolve: wago unreachable          rc" "1" "$R_RC"
assert_has "resolve: wago unreachable          annotated" "$R_LOG" "::error::No wago 'wow_classic_beta' build starting '1.60.'"
assert_lacks "resolve: wago unreachable          writes no version" "$R_OUT" "version="

run_resolve wow_classic_beta "1.60." html
check "resolve: non-JSON body             rc" "1" "$R_RC"
assert_lacks "resolve: non-JSON body             writes no version" "$R_OUT" "version="

run_resolve wow "" ok
check "resolve: daily default             rc" "0" "$R_RC"
check "resolve: daily default             takes the product's latest" "version=9.9.9.1" "$R_OUT"
assert_has "resolve: daily default             asks /api/builds/wow/latest" "$R_ARGS" "https://wago.tools/api/builds/wow/latest"
check "resolve: daily default             makes the one call" "1" "$(grep -c . <<< "$R_ARGS")"

run_resolve wow_classic_beta "" ok
assert_has "resolve: bare product              asks that product's latest" "$R_ARGS" "https://wago.tools/api/builds/wow_classic_beta/latest"

# --- 2. wiring the step scripts cannot see ------------------------------------------------------------

assert_line "wiring: lint job product comes from the input, default wow" "$LINT_YML" \
  '      WAGO_PRODUCT: ${{ inputs.product || '"'wow'"' }}'
assert_line "wiring: lint job prefix comes from the input, default empty" "$LINT_YML" \
  '      WAGO_VERSION_PREFIX: ${{ inputs.version_prefix || '"''"' }}'
assert_line "wiring: lint cache key carries the product" "$LINT_YML" \
  '          key: wago-csv-${{ env.WAGO_PRODUCT }}-${{ steps.build.outputs.version }}'
assert_has "wiring: lint call passes the product" "$(step_block "$LINT_YML" "Validate hand-authored ids against live client DB2")" \
  '-Product $env:WAGO_PRODUCT'
# Only the daily default may open, comment on or close the tracking issue ...
assert_line "wiring: notify runs for the daily default only" "$LINT_YML" \
  "    if: always() && (inputs.product || 'wow') == 'wow' && (inputs.version_prefix || '') == ''"
# ... and the run a new failure is compared with is the last SCHEDULED one.
assert_has "wiring: the previous run is the last scheduled one" \
  "$(step_block "$LINT_YML" "Raise issue on a second consecutive failure")" '--event schedule'

assert_line "wiring: test.yml stale-ids job lints the live product" "$TEST_YML" "      WAGO_PRODUCT: wow"
assert_line "wiring: test.yml cache key carries the product" "$TEST_YML" \
  '          key: wago-csv-${{ env.WAGO_PRODUCT }}-${{ steps.build.outputs.version }}'
assert_has "wiring: test.yml resolves that product's latest" "$(step_block "$TEST_YML" "Resolve wago build")" \
  '/api/builds/${WAGO_PRODUCT}/latest'
assert_has "wiring: test.yml lint call passes the product" "$(step_block "$TEST_YML" "Lint hand-authored ids")" \
  '-Product "$WAGO_PRODUCT"'

if [[ "$failures" != 0 ]]; then
  echo "FAILED: $failures case(s)"
  exit 1
fi
echo "OK: all cases passed"
