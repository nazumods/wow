#!/usr/bin/env bash
# .github/scripts/release.sh
#
# For every addon directory tracked in this monorepo:
#   1. Detect commits since its last release tag that touch that directory.
#   2. Bump the last numeric segment of its ## Version: field in the .toc.
#   3. Generate a changelog grouped by conventional-commit type.
#   4. Commit all .toc bumps, tag each addon, and create GitHub releases.

set -euo pipefail

# ── Commit-type display config ────────────────────────────────────────────────

# Ordered list controls section order in the changelog.
COMMIT_TYPES_ORDER=(feat fix perf refactor chore doc style test build ci)

declare -A COMMIT_TYPE_NAMES=(
  [feat]="Features"
  [fix]="Bug Fixes"
  [perf]="Performance"
  [refactor]="Refactoring"
  [chore]="Maintenance"
  [doc]="Documentation"
  [style]="Style"
  [test]="Tests"
  [build]="Build"
  [ci]="CI"
)

# ── Discover owned addons ─────────────────────────────────────────────────────
# An "owned" addon is a top-level directory that has both git-tracked files
# and at least one .toc file. Third-party addons sitting in the same WoW
# AddOns folder but never committed to this repo are automatically excluded.
#
# Some tracked top-level directories are deliberately NOT addons and must never
# be released or published: `apps/` (the Tauri desktop companion — its own
# Rust/JS build & versioning, not a WoW addon), `.github/` (CI), and `Tooling/`
# (development scripts, e.g. the logo generator). They have no top-level .toc
# so the filter below already skips them, but list them explicitly so the
# intent is documented and a stray .toc can't sneak one in.
NON_ADDON_DIRS=(apps .github Tooling)

ADDONS=()
while IFS= read -r dir; do
  is_non_addon=false
  for nd in "${NON_ADDON_DIRS[@]}"; do
    [[ "$dir" == "$nd" ]] && { is_non_addon=true; break; }
  done
  [[ "$is_non_addon" == true ]] && continue
  if ls "${dir}"/*.toc &>/dev/null 2>&1; then
    ADDONS+=("$dir")
  fi
done < <(git ls-files | grep '/' | cut -d'/' -f1 | sort -u)

echo "Owned addons: ${ADDONS[*]:-<none>}"

# ── Version bump helper ───────────────────────────────────────────────────────
# Increments the last contiguous run of digits in a version string.
#   12.0.0-1   →  12.0.0-2
#   11.0.002-0.1  →  11.0.002-0.2
bump_version() {
  local ver="$1"
  if [[ "$ver" =~ ^(.*[^0-9])([0-9]+)([^0-9]*)$ ]]; then
    echo "${BASH_REMATCH[1]}$(( BASH_REMATCH[2] + 1 ))${BASH_REMATCH[3]}"
  else
    # Purely numeric version — shouldn't happen but handle gracefully.
    echo "$(( ver + 1 ))"
  fi
}

# ── In-game changelog helper ──────────────────────────────────────────────────
# Prepend a release entry (newest first) to an addon's in-game changelog data file.
# Only touches it when the addon opted in by shipping a changelog.lua + toc entry
# (see LibNAddOn's changelog viewer) — this script never creates the file, so an
# addon that hasn't wired up the viewer is left untouched. The notes body is the
# same markdown grouping written to the GitHub release, wrapped in a Lua long string.
prepend_changelog() {
  local changelog="$1" version="$2" notes_file="$3"
  [[ -f "$changelog" ]] || return 0
  local entry_file
  entry_file=$(mktemp)
  {
    printf '  { version = "%s", notes = [==[\n' "$version"
    sed -e 's/[[:space:]]*$//' "$notes_file"
    printf ']==] },\n'
  } > "$entry_file"
  # Insert the new entry immediately after the `ns.changelog = {` opening line.
  awk -v ef="$entry_file" '
    { print }
    /^ns\.changelog = \{/ && !inserted {
      while ((getline line < ef) > 0) print line
      close(ef); inserted = 1
    }
  ' "$changelog" > "${changelog}.tmp" && mv "${changelog}.tmp" "$changelog"
  rm -f "$entry_file"
}

# ── Detect changes and prepare releases ──────────────────────────────────────

CHANGED_ADDONS=()
declare -A ADDON_VERSIONS
declare -A ADDON_NOTES_FILES

for addon in "${ADDONS[@]}"; do

  # Resolve the primary .toc (prefer <AddonName>.toc, fall back to any .toc).
  toc="${addon}/${addon}.toc"
  if [[ ! -f "$toc" ]]; then
    toc=$(ls "${addon}"/*.toc 2>/dev/null | head -1 || true)
  fi
  [[ -z "$toc" || ! -f "$toc" ]] && continue

  # Find the most recent release tag for this addon.
  last_tag=$(git tag -l "${addon}-v*" | sort -V | tail -1 || true)

  # Commits since the last tag that touched this addon's directory, excluding
  # pure-documentation (.md) files, unit tests (spec/), and maintainer tooling
  # (tools/) — doc-only, test-only, or tooling-only commits should not trigger a
  # release or version bump. The :(exclude,glob) pathspec's /**/ spans subdirs
  # and also matches top-level .md files (e.g. CONTEXT.md). spec/ and tools/ are
  # also excluded from the published zip in publish.yml.
  pathspec=("${addon}/" ":(exclude,glob)${addon}/**/*.md" ":(exclude,glob)${addon}/spec/**" ":(exclude,glob)${addon}/tools/**" ":(exclude)${addon}/changelog.lua")
  if [[ -n "$last_tag" ]]; then
    commit_log=$(git log "${last_tag}..HEAD" --pretty=format:"%s" -- "${pathspec[@]}" || true)
  else
    commit_log=$(git log --pretty=format:"%s" -- "${pathspec[@]}" || true)
  fi

  [[ -z "$commit_log" ]] && continue

  # ── Bump version ────────────────────────────────────────────────────────────
  current_version=$(grep -E "^## Version:" "$toc" \
    | sed 's/## Version:[[:space:]]*//' | tr -d '\r' || true)
  [[ -z "$current_version" ]] && continue
  new_version=$(bump_version "$current_version")

  sed -i "s|^## Version:.*|## Version: ${new_version}|" "$toc"
  echo "  ${addon}: ${current_version} → ${new_version}"

  # ── Build changelog ─────────────────────────────────────────────────────────
  declare -A type_entries
  for t in "${COMMIT_TYPES_ORDER[@]}"; do type_entries[$t]=""; done
  other_entries=""

  while IFS= read -r msg; do
    [[ -z "$msg" ]] && continue
    matched=false
    for t in "${COMMIT_TYPES_ORDER[@]}"; do
      # Matches: type(optional-scope): description
      pattern="^${t}(\([^)]*\))?:[[:space:]]+(.+)$"
      if [[ "$msg" =~ $pattern ]]; then
        type_entries[$t]+="- ${BASH_REMATCH[2]}"$'\n'
        matched=true
        break
      fi
    done
    if [[ "$matched" == false ]]; then
      other_entries+="- ${msg}"$'\n'
    fi
  done <<< "$commit_log"

  notes=""
  for t in "${COMMIT_TYPES_ORDER[@]}"; do
    if [[ -n "${type_entries[$t]}" ]]; then
      notes+="### ${COMMIT_TYPE_NAMES[$t]}"$'\n'
      notes+="${type_entries[$t]}"$'\n'
    fi
  done
  if [[ -n "$other_entries" ]]; then
    notes+="### Other Changes"$'\n'
    notes+="${other_entries}"$'\n'
  fi

  notes_file=$(mktemp)
  printf '%s' "$notes" > "$notes_file"

  # Append this release to the addon's in-game changelog (opt-in; no-op if absent).
  prepend_changelog "${addon}/changelog.lua" "$new_version" "$notes_file"

  CHANGED_ADDONS+=("$addon")
  ADDON_VERSIONS[$addon]="$new_version"
  ADDON_NOTES_FILES[$addon]="$notes_file"

  unset type_entries
done

# ── Bail out early if nothing changed ────────────────────────────────────────

if [[ ${#CHANGED_ADDONS[@]} -eq 0 ]]; then
  echo "No addon changes to release."
  exit 0
fi

echo "Releasing: ${CHANGED_ADDONS[*]}"

# ── Commit version bumps ──────────────────────────────────────────────────────

git add -A
git commit -m "chore(release): bump versions"
git push

# ── Tag and publish each release ─────────────────────────────────────────────

for addon in "${CHANGED_ADDONS[@]}"; do
  new_version="${ADDON_VERSIONS[$addon]}"
  notes_file="${ADDON_NOTES_FILES[$addon]}"
  tag="${addon}-v${new_version}"

  echo "Publishing ${tag}"
  git tag "$tag"
  git push origin "$tag"

  gh release create "$tag" \
    --title "${addon} v${new_version}" \
    --notes-file "$notes_file" \
    --latest=false

  rm -f "$notes_file"
done

echo "Done."
