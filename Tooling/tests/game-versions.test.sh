#!/usr/bin/env bash
# Tests for how .github/workflows/publish.yml decides which CurseForge game versions a release is
# labelled with (nazumods/wow#954). Three layers, all reading the SHIPPED text of publish.yml:
#
#   1. the two inline bash functions, extracted between `# BEGIN <name>` / `# END <name>` markers:
#        iface_to_version  `## Interface:` value -> X.Y.Z   (16001 -> 1.60.1, NOT 16.0.1)
#        missing_versions  which wanted names CurseForge does not know
#   2. the two steps that CALL them, extracted by step name and run under `bash -e` (GitHub's default
#      shell: no pipefail) in a sandbox: "Read .toc metadata" against fake .toc files, and "Verify game
#      versions exist on CurseForge" against a stub `curl`. The original bug lived in this glue, not
#      in a function, so a function-only test would not have caught it coming back.
#   3. the YAML wiring the glue cannot see: the skip guards, the secret, the SHA-pinned upload action,
#      and the verify step running before the upload.
#
# The functions live inline in publish.yml, next to their only caller; this test reads that text.
#
# Usage:
#   bash Tooling/tests/game-versions.test.sh
#   PUBLISH_YML=/path/to/copy.yml bash Tooling/tests/game-versions.test.sh   # run against a scratch
#                                                                             # copy, e.g. a mutation
# Needs bash, awk, sed, grep and jq (all preinstalled on GitHub's ubuntu runners).
# Exit 0 = every case passed; 1 = a case failed or the YAML no longer has the expected shape.
# shellcheck disable=SC2016  # the single-quoted '${{ ... }}' strings are literal GitHub expressions on purpose
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PUBLISH_YML="${PUBLISH_YML:-$REPO_ROOT/.github/workflows/publish.yml}"

[[ -f "$PUBLISH_YML" ]] || { echo "FAIL: $PUBLISH_YML does not exist"; exit 1; }
command -v jq > /dev/null || { echo "FAIL: jq is required (the verify step pipes through it)"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- extraction ---------------------------------------------------------------------------------

# The body of the marker block named $1: CRs dropped (a Windows checkout), YAML indentation stripped.
# Fails loudly unless there is exactly one BEGIN and one END marker and the block defines the
# function -- a silently empty extraction would make every case below fail for the wrong reason.
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

# publish.yml's layout, which these two helpers rely on: steps are `      - name: ...` (6 spaces), their
# keys sit at 8, and a `run: |` body at 10.

# The whole step named $1 (name line through the line before the next step).
step_block() {
  # awk reads to EOF (no early `exit`): under `pipefail` an awk that quit while `tr` still had bytes to
  # write would turn into a SIGPIPE failure of the whole pipeline.
  tr -d '\r' < "$PUBLISH_YML" | awk -v want="      - name: $1" '
    $0 == want { instep = 1; print; next }
    instep && /^      - / { instep = 0; next }
    instep { print }'
}

# The `run:` script of the step named $1, with the YAML indentation removed (as GitHub does).
step_script() {
  local out
  out=$(step_block "$1" | awk '
    !done && !inrun && /^        run: \|[[:space:]]*$/ { inrun = 1; next }
    inrun {
      if ($0 ~ /^[[:space:]]*$/) { print ""; next }
      if (substr($0, 1, 10) != "          ") { inrun = 0; done = 1; next }
      print substr($0, 11)
    }')
  if [[ -z "$out" ]]; then
    echo "FAIL: no step named '$1' with a 'run: |' body in $PUBLISH_YML" >&2
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

# --- 1. the functions ---------------------------------------------------------------------------

for fn in iface_to_version missing_versions; do
  block=$(extract_block "$fn") || exit 1
  eval "$block"
done

# Read from the right, so a 5-digit value keeps its one-digit major.
check "iface 16001 (Forever)       -> 1.60.1" "1.60.1" "$(iface_to_version 16001)"
check "iface 120105 (Retail)       -> 12.1.5" "12.1.5" "$(iface_to_version 120105)"
check "iface 11509 (Classic Era)   -> 1.15.9" "1.15.9" "$(iface_to_version 11509)"
check "iface 11520 (patch 20)      -> 1.15.20" "1.15.20" "$(iface_to_version 11520)"
check "iface ' 16001 ' (spaces)    -> 1.60.1" "1.60.1" "$(iface_to_version ' 16001 ')"
check "iface tab-prefixed          -> 1.60.1" "1.60.1" "$(iface_to_version $'\t16001')"
# 08 / 09 are invalid octal; the 10# prefixes are what keep the minor and the patch decimal.
check "iface 110009 (patch 09)     -> 11.0.9" "11.0.9" "$(iface_to_version 110009)"
check "iface 110809 (minor 08)     -> 11.8.9" "11.8.9" "$(iface_to_version 110809)"
check "iface 080123 (major 08)     -> 8.1.23" "8.1.23" "$(iface_to_version 080123)"

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

# Whole-name, fixed-string matches.
check "missing: all known              -> (none)" "" "$(missing_versions $'12.1.5\n1.60.1' '12.1.5,1.60.1')"
check "missing: 1.60.1 unknown         -> 1.60.1" "1.60.1" "$(missing_versions $'12.1.5' '12.1.5,1.60.1')"
check "missing: two unknown            -> 'a b'" "a b" "$(missing_versions '' 'a,b')"
check "missing: prefix is not a match  -> 1.60" "1.60" "$(missing_versions $'1.60.1' '1.60')"
check "missing: suffix is not a match  -> 1.60.1" "1.60.1" "$(missing_versions $'11.60.1' '1.60.1')"
check "missing: '.' is not a wildcard  -> 1.60.1" "1.60.1" "$(missing_versions $'1x60x1' '1.60.1')"

# --- 2a. the "Read .toc metadata" step, run against fake .toc files ------------------------------

TOC_SCRIPT="$WORK/toc-step.sh"
# The only GitHub expression in that script is the addon folder name.
step_script "Read .toc metadata" | sed 's/\${{ steps.info.outputs.addon }}/Foo/g' > "$TOC_SCRIPT"
grep -q '\${{' "$TOC_SCRIPT" && { echo "FAIL: 'Read .toc metadata' has a GitHub expression this test does not substitute"; exit 1; }

# run_toc <interface-line-or-empty> <project-id-or-empty> [second-interface-line] -> TOC_RC, TOC_OUT
# (GITHUB_OUTPUT), TOC_LOG. TOC_SHELL_FLAGS is the shell's option: -e (GitHub's default for `run:`).
TOC_SHELL_FLAGS=-e
run_toc() {
  rm -rf "$WORK/addon"; mkdir -p "$WORK/addon/Foo"
  {
    if [[ -n "$1" ]]; then printf '## Interface: %s\r\n' "$1"; fi   # CRLF, as a Windows-authored .toc
    printf '## Version: 12.1.5-r0\n'
    if [[ -n "${3:-}" ]]; then printf '## Interface: %s\r\n' "$3"; fi
    if [[ -n "$2" ]]; then printf '## X-Curse-Project-ID: %s\n' "$2"; fi
  } > "$WORK/addon/Foo/Foo.toc"
  : > "$WORK/gh-output"
  TOC_RC=0
  TOC_LOG=$(cd "$WORK/addon" && GITHUB_OUTPUT="$WORK/gh-output" bash "$TOC_SHELL_FLAGS" "$TOC_SCRIPT" 2>&1) || TOC_RC=$?
  TOC_OUT=$(cat "$WORK/gh-output")
}

run_toc "120105, 16001" 1234
check "toc: dual client             rc" "0" "$TOC_RC"
assert_has "toc: dual client             versions (both, in order)" "$TOC_OUT" "game_versions=12.1.5,1.60.1"
assert_has "toc: dual client             project id" "$TOC_OUT" "project_id=1234"
assert_has "toc: dual client             not skipped" "$TOC_OUT" "skip=false"
run_toc "120105" 1234
assert_has "toc: Retail only             versions" "$TOC_OUT" "game_versions=12.1.5"
run_toc "16001" 1234
assert_has "toc: Forever only            versions" "$TOC_OUT" "game_versions=1.60.1"
run_toc "11509,110002, 110005" 1234
assert_has "toc: three, mixed spacing    versions" "$TOC_OUT" "game_versions=1.15.9,11.0.2,11.0.5"
run_toc "abc" 1234
check "toc: bad Interface          rc" "1" "$TOC_RC"
assert_has "toc: bad Interface          annotation" "$TOC_LOG" "::error::Unrecognised Interface value 'abc'"
assert_lacks "toc: bad Interface          writes no versions" "$TOC_OUT" "game_versions="
# The failure must be an explicit `exit 1`, not an accident of the shell's -e: a later `shell:` key on
# the step would change the options, and a swallowed failure would write an empty version list.
TOC_SHELL_FLAGS=+e
run_toc "abc" 1234
check "toc: bad Interface, no -e  rc (explicit exit)" "1" "$TOC_RC"
assert_lacks "toc: bad Interface, no -e  writes no versions" "$TOC_OUT" "game_versions="
TOC_SHELL_FLAGS=-e
# The version read takes the first `## Interface:` line only; a second line would be dropped silently
# and Forever would ship unlabelled, so a second line fails the step.
run_toc "120105" 1234 "16001"
check "toc: two Interface lines   rc" "1" "$TOC_RC"
assert_has "toc: two Interface lines   annotation" "$TOC_LOG" "::error::Foo/Foo.toc has 2 '## Interface:' lines"
assert_lacks "toc: two Interface lines   writes no versions" "$TOC_OUT" "game_versions="
run_toc "120105" ""
check "toc: no project id          rc" "0" "$TOC_RC"
assert_has "toc: no project id          is skipped" "$TOC_OUT" "skip=true"
assert_lacks "toc: no project id          reads no Interface" "$TOC_OUT" "game_versions="
run_toc "" 1234
check "toc: no Interface line      rc (the verify step rejects it)" "0" "$TOC_RC"
check "toc: no Interface line      versions are empty" "game_versions=" "$(grep '^game_versions=' <<< "$TOC_OUT" || true)"

# --- 2b. the "Verify game versions exist on CurseForge" step, run against a stub curl ------------

VERIFY_SCRIPT="$WORK/verify-step.sh"
step_script "Verify game versions exist on CurseForge" > "$VERIFY_SCRIPT"
mkdir -p "$WORK/bin"
# Records its arguments. STUB_MODE=ok prints STUB_BODY. STUB_MODE=http-error acts like a 5xx: with -f
# (in a flag cluster such as -sf) or --fail among the arguments it fails (exit 22, no body), as the
# real curl does; without either it prints an error body.
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$STUB_ARGS_FILE"
case "${STUB_MODE:-ok}" in
  ok) printf '%s' "$STUB_BODY" ;;
  http-error)
    if [[ " $* " =~ [[:space:]]-[a-zA-Z]*f[a-zA-Z]*[[:space:]] || " $* " == *" --fail "* ]]; then exit 22; fi
    printf '%s' '{"error":"internal"}' ;;
esac
EOF
chmod +x "$WORK/bin/curl"

# run_verify <wanted> <mode> <body> -> V_RC, V_LOG, V_ARGS (curl's arguments, empty if never called)
run_verify() {
  rm -f "$WORK/curl-args"
  V_RC=0
  V_LOG=$(PATH="$WORK/bin:$PATH" STUB_MODE="$2" STUB_BODY="$3" STUB_ARGS_FILE="$WORK/curl-args" \
    CF_TOKEN=tok-954 GAME_VERSIONS="$1" bash -e "$VERIFY_SCRIPT" 2>&1) || V_RC=$?
  V_ARGS=$(cat "$WORK/curl-args" 2>/dev/null || true)
}

# Distinct id / name / slug values, so comparing the wrong JSON field cannot pass.
LIST='[{"id":11,"name":"12.1.5","slug":"zz-1"},{"id":22,"name":"1.60.1","slug":"zz-2"}]'

run_verify "12.1.5,1.60.1" ok "$LIST"
check "verify: all known           rc" "0" "$V_RC"
assert_has "verify: all known           says so" "$V_LOG" "CurseForge knows every game version: 12.1.5,1.60.1"
assert_has "verify: asks the game-versions endpoint" "$V_ARGS" "https://wow.curseforge.com/api/game/versions"
assert_has "verify: sends the API token header" "$V_ARGS" "X-Api-Token: tok-954"
assert_has "verify: bounds the request time" "$V_ARGS" "--max-time"
assert_has "verify: retries a transient failure" "$V_ARGS" "--retry"

run_verify "12.1.5,1.60.1" ok '[{"id":11,"name":"12.1.5","slug":"zz-1"}]'
check "verify: Forever unknown     rc (fails, does not drop silently)" "1" "$V_RC"
assert_has "verify: Forever unknown     names it" "$V_LOG" "::error::CurseForge has no game version named: 1.60.1"
assert_lacks "verify: Forever unknown     is not reported as known" "$V_LOG" "knows every game version"

run_verify "16.0.1" ok "$LIST"
check "verify: wrong 16.0.1        rc" "1" "$V_RC"
run_verify "12.1.5" ok "[]"
check "verify: empty list          rc" "1" "$V_RC"
assert_has "verify: empty list          names it" "$V_LOG" "no game version named: 12.1.5"

run_verify "12.1.5" http-error ""
check "verify: API error (-f)      rc" "1" "$V_RC"
assert_has "verify: API error (-f)      accurate message" "$V_LOG" "::error::Could not list CurseForge game versions"
assert_lacks "verify: API error (-f)      not blamed on a version" "$V_LOG" "no game version named"

run_verify "12.1.5" ok "<html>oops</html>"
check "verify: HTML body           rc" "1" "$V_RC"
assert_has "verify: HTML body           annotated" "$V_LOG" "::error::Unexpected CurseForge game-versions response"

run_verify "12.1.5" ok '{"error":"nope"}'
check "verify: object body         rc" "1" "$V_RC"
assert_has "verify: object body         annotated" "$V_LOG" "::error::Unexpected CurseForge game-versions response"

# jq prints "12.1.5" BEFORE it fails on the string element, so the half-parsed list alone would satisfy
# the wanted version: only the step's own exit on the jq failure stops it.
run_verify "12.1.5" ok '[{"id":11,"name":"12.1.5"},"stray"]'
check "verify: half-valid list     rc (jq fails mid-list)" "1" "$V_RC"
assert_has "verify: half-valid list     annotated" "$V_LOG" "::error::Unexpected CurseForge game-versions response"
assert_lacks "verify: half-valid list     is not reported as known" "$V_LOG" "knows every game version"

run_verify "" ok "$LIST"
check "verify: no game versions    rc" "1" "$V_RC"
assert_has "verify: no game versions    says why" "$V_LOG" "has no '## Interface:' value"
check "verify: no game versions    never calls CurseForge" "" "$V_ARGS"

# --- 3. wiring the step scripts cannot see ----------------------------------------------------------

SKIP_GUARD="if: steps.toc.outputs.skip != 'true'"
for s in "Verify game versions exist on CurseForge" "Package addon zip" "Upload to CurseForge"; do
  assert_has "wiring: '$s' only runs when not skipped" "$(step_block "$s" | awk 'NR <= 4')" "$SKIP_GUARD"
done
verify_block=$(step_block "Verify game versions exist on CurseForge")
assert_has "wiring: verify gets the CurseForge secret" "$verify_block" 'CF_TOKEN: ${{ secrets.CURSEFORGE_API_TOKEN }}'
assert_has "wiring: verify gets the versions the toc step read" "$verify_block" 'GAME_VERSIONS: ${{ steps.toc.outputs.game_versions }}'
upload_block=$(step_block "Upload to CurseForge")
if grep -qE '^        uses: itsmeow/curseforge-upload@[0-9a-f]{40}( |$)' <<< "$upload_block"; then
  echo "PASS wiring: the upload action is pinned to a commit SHA"
else
  echo "FAIL wiring: the upload action is not pinned to a 40-hex commit SHA: $(grep 'uses:' <<< "$upload_block")"
  failures=$((failures + 1))
fi
assert_has "wiring: the upload uses the versions the toc step read" "$upload_block" 'game_versions: ${{ steps.toc.outputs.game_versions }}'
verify_line=$(grep -nF -- '- name: Verify game versions exist on CurseForge' "$PUBLISH_YML" | head -1 | cut -d: -f1)
upload_line=$(grep -nF -- '- name: Upload to CurseForge' "$PUBLISH_YML" | head -1 | cut -d: -f1)
if [[ -n "$verify_line" && -n "$upload_line" && "$verify_line" -lt "$upload_line" ]]; then
  echo "PASS wiring: verify runs before the upload"
else
  echo "FAIL wiring: verify (line '$verify_line') must come before the upload (line '$upload_line')"
  failures=$((failures + 1))
fi

if [[ "$failures" != 0 ]]; then
  echo "FAILED: $failures case(s)"
  exit 1
fi
echo "OK: all cases passed"
