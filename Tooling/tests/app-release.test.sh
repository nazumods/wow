#!/usr/bin/env bash
# Tests for which commits make .github/scripts/app-release.sh cut a desktop release (nazumods/wow#1024).
# The exe compiles apps/bot-ops (cargo path dep + the @bot-ops vite alias), so a bot-ops change must count
# as an app change; a doc-only change in either tree must not. Runs the SHIPPED script in a throwaway git
# repo (a bare repo as `origin`, so its `git push` works) with the minimal fixture files it edits.
#
# Usage: bash Tooling/tests/app-release.test.sh
# Needs bash, git and node. Exit 0 = every case passed; 1 = a case failed.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$REPO_ROOT/.github/scripts/app-release.sh"
[[ -f "$SCRIPT" ]] || { echo "FAIL: $SCRIPT does not exist"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failures=0
check() { # name expected actual
  if [[ "$3" == "$2" ]]; then
    echo "PASS $1"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    failures=$((failures + 1))
  fi
}

APP=apps/warbandeer-desktop
TAG=app-warbandeer-desktop-v0.1.0

git init -q --bare "$WORK/origin.git"
git init -q -b main "$WORK/repo"
cd "$WORK/repo"
git config user.email test@example.invalid
git config user.name test
git remote add origin "$WORK/origin.git"

mkdir -p "$APP/src-tauri" apps/bot-ops/src
echo '{"version": "0.1.0"}' > "$APP/src-tauri/tauri.conf.json"
echo '{"version": "0.1.0"}' > "$APP/package.json"
printf '[package]\nname = "warbandeer-desktop"\nversion = "0.1.0"\n' > "$APP/src-tauri/Cargo.toml"
printf '[[package]]\nname = "warbandeer-desktop"\nversion = "0.1.0"\n' > "$APP/src-tauri/Cargo.lock"
echo 'export {}' > apps/bot-ops/src/index.ts
git add -A
git commit -q -m "chore: seed"
git tag "$TAG"
git push -q -u origin main

commit_file() { # path content subject
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >> "$1"
  git add "$1"
  git commit -q -m "$3"
}

# run -> prints the changed= line the script wrote to GITHUB_OUTPUT
run() {
  : > "$WORK/gh-output"
  GITHUB_OUTPUT="$WORK/gh-output" bash "$SCRIPT" > "$WORK/log" 2>&1 || { cat "$WORK/log"; echo "changed=error"; return; }
  grep '^changed=' "$WORK/gh-output"
}

check "nothing since the last app tag" "changed=false" "$(run)"

commit_file apps/bot-ops/README.md "docs" "doc(bot-ops): readme"
commit_file "$APP/README.md" "docs" "doc(desktop): readme"
check "doc-only changes in app and bot-ops" "changed=false" "$(run)"

commit_file apps/bot-ops/src/index.ts "export const x = 1" "fix(bot-ops): behaviour change"
check "bot-ops code change after the tag (#1024)" "changed=true" "$(run)"
check "release bumped the app version" "0.1.1" "$(node -p "require('./$APP/src-tauri/tauri.conf.json').version")"

git tag "app-warbandeer-desktop-v0.1.1"
check "bot-ops change already released" "changed=false" "$(run)"

commit_file "$APP/src/main.ts" "x" "feat(desktop): code change"
check "desktop code change after the tag" "changed=true" "$(run)"

if [[ "$failures" != 0 ]]; then
  echo "FAILED: $failures case(s)"
  exit 1
fi
echo "OK: all cases passed"
