#!/usr/bin/env bash
# .github/scripts/app-release.sh
#
# The apps/ analogue of `release.sh` for the `apps/warbandeer-desktop` Tauri
# app: bump its version when there are unreleased commits, so a human no
# longer has to hand-edit tauri.conf.json/package.json/Cargo.toml before
# merging. Runs on a cron (see app-release.yml) rather than on push — the
# version-bump commit below is pushed with an admin token that (unlike the
# default GITHUB_TOKEN) does trigger workflows, so a push-triggered flow would
# re-release itself in a loop. The calling workflow only builds + publishes
# when this script reports changed=true.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

APP_DIR="apps/warbandeer-desktop"
TAG_PREFIX="app-warbandeer-desktop-v"

TAURI_CONF="${APP_DIR}/src-tauri/tauri.conf.json"
PACKAGE_JSON="${APP_DIR}/package.json"
CARGO_TOML="${APP_DIR}/src-tauri/Cargo.toml"
CARGO_LOCK="${APP_DIR}/src-tauri/Cargo.lock"

# ── Detect unreleased commits ─────────────────────────────────────────────────
# Same doc-only exclusion convention as release.sh — a README/CONTEXT-only
# change shouldn't cut a release.
last_tag=$(git tag -l "${TAG_PREFIX}*" | sort -V | tail -1 || true)

pathspec=("${APP_DIR}/" ":(exclude,glob)${APP_DIR}/**/*.md")
if [[ -n "$last_tag" ]]; then
  commit_log=$(git log "${last_tag}..HEAD" --pretty=format:"%s" -- "${pathspec[@]}" || true)
else
  commit_log=$(git log --pretty=format:"%s" -- "${pathspec[@]}" || true)
fi

if [[ -z "$commit_log" ]]; then
  echo "No app changes to release."
  echo "changed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# ── Bump version ───────────────────────────────────────────────────────────────
# Increments the last contiguous run of digits, matching release.sh's scheme:
#   0.2.3 -> 0.2.4
current_version=$(node -p "require('./${TAURI_CONF}').version")

if [[ "$current_version" =~ ^(.*[^0-9])([0-9]+)([^0-9]*)$ ]]; then
  new_version="${BASH_REMATCH[1]}$(( BASH_REMATCH[2] + 1 ))${BASH_REMATCH[3]}"
else
  new_version="$(( current_version + 1 ))"
fi

echo "warbandeer-desktop: ${current_version} -> ${new_version}"

sed -i "s/\"version\": \"${current_version}\"/\"version\": \"${new_version}\"/" "$TAURI_CONF" "$PACKAGE_JSON"
sed -i "s/^version = \"${current_version}\"/version = \"${new_version}\"/" "$CARGO_TOML"

# Cargo.lock lists many packages' `version = "..."` lines — only bump the one
# immediately following this app's own `name = "warbandeer-desktop"` entry.
awk -v new="$new_version" '
  found && /^version = / { sub(/"[^"]*"/, "\"" new "\""); found = 0 }
  /^name = "warbandeer-desktop"$/ { found = 1 }
  { print }
' "$CARGO_LOCK" > "${CARGO_LOCK}.tmp" && mv "${CARGO_LOCK}.tmp" "$CARGO_LOCK"

git add "$TAURI_CONF" "$PACKAGE_JSON" "$CARGO_TOML" "$CARGO_LOCK"
git commit -m "chore(release): bump warbandeer-desktop to ${new_version}"
git push

echo "version=${new_version}" >> "$GITHUB_OUTPUT"
echo "changed=true" >> "$GITHUB_OUTPUT"
