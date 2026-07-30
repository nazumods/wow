#!/usr/bin/env bash
#
# bot-ops.sh — the ONLY privileged surface for the Warbandeer bot admin panels (debug or prod).
#
# The desktop Ops panels (apps/warbandeer-desktop, and roshne's wow-companion) never run docker or
# edit the bot's .env themselves: they invoke this script over SSH, one subcommand at a time, and
# pass BOT_OPS_PROJECT / BOT_OPS_CONTAINER to pick which bot. Keeping the whitelist and the apply
# logic here — versioned and reviewable — means bot secrets never leave the box, and the panels can
# only do the fixed set of operations below.
#
# Subcommands:
#   status        Print JSON: container running?, status line, image, realm status.
#   logs [N]      Print the last N (default 200, max 5000) container log lines, raw.
#   restart       Restart the bot process in place (docker compose restart). No env reload.
#   env-get       Print JSON of the NON-SECRET whitelisted env keys and their current values.
#   env-set       Read KEY=VALUE lines from stdin, validate against the whitelist, back up
#                 .env, apply only real changes, then `up -d --force-recreate` to load them.
#
# Design notes:
#   - The compose project + container come from BOT_OPS_PROJECT / BOT_OPS_CONTAINER (the caller
#     passes them per selected bot), defaulting to the debug bot. The project MUST be passed with
#     `-p` because it is NOT set in a non-interactive SSH shell's environment — a bare `docker
#     compose` would default to the directory name and miss the running container. (Learned the hard
#     way.) Both are validated to a safe charset since they're interpolated into docker commands.
#   - Secrets (DISCORD_TOKEN, BLIZZARD_CLIENT_SECRET, GITHUB_TOKEN, ...) are deliberately absent
#     from ALLOWED. env-get never reads them out; env-set never writes them. Edit those by hand
#     with nano on the box.
#   - env-set rebuilds .env line-by-line (no sed) so a value can never inject into the file, and
#     comment/blank/secret lines are preserved verbatim.
set -euo pipefail

# Target bot: defaults to the debug bot; a panel passes these per selected target (debug/prod).
PROJECT="${BOT_OPS_PROJECT:-warbandeer-discord-debug}"
CONTAINER="${BOT_OPS_CONTAINER:-warbandeer-discord}"
LOGS_MAX=5000

[[ "$PROJECT" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  echo "bot-ops: invalid BOT_OPS_PROJECT" >&2
  exit 1
}
[[ "$CONTAINER" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  echo "bot-ops: invalid BOT_OPS_CONTAINER" >&2
  exit 1
}

# Project dir = this script's parent's parent (ops/ lives inside the bot dir, beside .env).
BOT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
ENV_FILE="$BOT_DIR/.env"

# Non-secret keys the panel may read and write. Anything not here is rejected by env-set and
# omitted by env-get. Each key pairs with a validation regex (empty string is always allowed —
# it clears the key back to its documented default).
declare -A ALLOWED=(
  [ANNOUNCE_CHANNEL_ID]='^[0-9]{5,25}$'
  [RELEASE_ANNOUNCE_CHANNEL_ID]='^[0-9]{5,25}$'
  [GUILD_ID]='^[0-9]{5,25}$'
  [REPORT_ROLE_ID]='^[0-9]{5,25}$'
  [ADMIN_USER_IDS]='^[0-9]{5,25}(,[0-9]{5,25})*$'
  [WOW_REALM]='^[a-z0-9-]{1,40}$'
  [WOW_REGION]='^(us|eu)$'
  [WATCHED_REPOS]='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(,[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)*$'
  [DMF_TIMEZONE]='^[A-Za-z_]+/[A-Za-z_]+$'
  [AUTO_UPDATE]='^(true|false)$'
  [BOT_BRANCH]='^[A-Za-z0-9._/-]{1,100}$'
  [COMMAND_PREFIX]='^[a-z0-9_-]{1,20}$'
)

die() { echo "bot-ops: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found on the box"; }

# Current value of a key from .env (empty if unset/absent). Strips the leading `KEY=`.
env_value() {
  local key="$1"
  [ -f "$ENV_FILE" ] || return 0
  local line
  line="$(grep -m1 -E "^${key}=" "$ENV_FILE" || true)"
  printf '%s' "${line#*=}"
}

cmd_status() {
  need docker; need jq
  local running status image realm
  running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo false)"
  status="$(docker ps -a --filter "name=^/${CONTAINER}$" --format '{{.Status}}' 2>/dev/null || true)"
  image="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || true)"
  # Best-effort: the persisted last-observed realm status (may be absent on a fresh install).
  realm="$(docker exec "$CONTAINER" cat /app/data/state.json 2>/dev/null \
            | jq -r '.realmStatus // ""' 2>/dev/null || true)"
  jq -n --argjson running "${running:-false}" \
        --arg status "$status" --arg image "$image" --arg realm "$realm" \
        '{running: $running, status: $status, image: $image, realmStatus: $realm}'
}

cmd_logs() {
  need docker
  local n="${1:-200}"
  [[ "$n" =~ ^[0-9]+$ ]] || die "logs: N must be a number"
  (( n > LOGS_MAX )) && n="$LOGS_MAX"
  docker logs "$CONTAINER" --tail "$n" 2>&1
}

cmd_restart() {
  need docker
  cd "$BOT_DIR"
  docker compose -p "$PROJECT" restart 2>&1
  echo "restarted $CONTAINER"
}

cmd_env_get() {
  need jq
  [ -f "$ENV_FILE" ] || die "env-get: $ENV_FILE not found"
  local args=() key
  for key in "${!ALLOWED[@]}"; do
    args+=(--arg "$key" "$(env_value "$key")")
  done
  # Build a {KEY: value, ...} object over exactly the allowlisted keys.
  jq -n "${args[@]}" '$ARGS.named'
}

cmd_env_set() {
  need docker; need jq
  [ -f "$ENV_FILE" ] || die "env-set: $ENV_FILE not found"

  # Counters track sizes explicitly: `${#assoc[@]}` on a still-empty associative array trips
  # "unbound variable" under `set -u`, so we never expand a possibly-empty array for its length.
  declare -A CHANGES=()
  local line key val n_changes=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    [[ "$line" == *=* ]] || die "env-set: malformed input line (need KEY=VALUE)"
    key="${line%%=*}"
    val="${line#*=}"
    [[ -n "${ALLOWED[$key]+x}" ]] || die "env-set: '$key' is not an editable key"
    if [ -n "$val" ] && [[ ! "$val" =~ ${ALLOWED[$key]} ]]; then
      die "env-set: value for '$key' is invalid"
    fi
    CHANGES["$key"]="$val"
    n_changes=$((n_changes + 1))
  done

  # Reduce to real changes (new value differs from current) — a no-op must not restart the bot.
  declare -A DIFF=()
  local n_diff=0
  if [ "$n_changes" -gt 0 ]; then
    for key in "${!CHANGES[@]}"; do
      if [ "${CHANGES[$key]}" != "$(env_value "$key")" ]; then
        DIFF["$key"]="${CHANGES[$key]}"
        n_diff=$((n_diff + 1))
      fi
    done
  fi
  if [ "$n_diff" -eq 0 ]; then
    jq -n '{ok: true, changed: [], recreated: false, note: "no changes"}'
    return 0
  fi

  local backup="$ENV_FILE.bak.$(date +%Y%m%d-%H%M%S)"
  # Pin the backup to 0600 rather than inheriting .env's mode. `cp` would copy that mode, which is
  # only safe while .env is itself owner-only — and a .env recreated by hand or by a fresh deploy
  # picks up the umask (0664 under the usual 002) instead. This file holds DISCORD_TOKEN and
  # BLIZZARD_CLIENT_SECRET, so its exposure shouldn't depend on the source being right.
  install -m 600 "$ENV_FILE" "$backup"

  # Rewrite .env: replace matching KEY= lines in place, preserve everything else verbatim,
  # append any changed key that wasn't already present.
  declare -A APPLIED
  local tmp k
  tmp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
      k="${BASH_REMATCH[1]}"
      if [[ -n "${DIFF[$k]+x}" ]]; then
        printf '%s=%s\n' "$k" "${DIFF[$k]}" >> "$tmp"
        APPLIED["$k"]=1
        continue
      fi
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$ENV_FILE"
  for k in "${!DIFF[@]}"; do
    [[ -z "${APPLIED[$k]+x}" ]] && printf '%s=%s\n' "$k" "${DIFF[$k]}" >> "$tmp"
  done
  mv "$tmp" "$ENV_FILE"
  # State the mode instead of inheriting whatever mktemp happened to create. `mv` carries the temp
  # file's mode onto .env, so today .env ends up 0600 purely as a side effect of mktemp's default —
  # correct by accident, and silently narrowing for anyone who set .env to 0640 on purpose. Saying
  # 0600 outright makes the intent the contract.
  chmod 600 "$ENV_FILE"

  # Apply: recreate the container so the new env is loaded (a plain restart would not reload it).
  cd "$BOT_DIR"
  local recreate_log rc=0
  recreate_log="$(docker compose -p "$PROJECT" up -d --force-recreate 2>&1)" || rc=$?

  local changed_json
  changed_json="$(printf '%s\n' "${!DIFF[@]}" | jq -R . | jq -s .)"
  jq -n --argjson changed "$changed_json" --arg backup "$backup" \
        --argjson ok "$([ "$rc" -eq 0 ] && echo true || echo false)" \
        --arg log "$recreate_log" \
        '{ok: $ok, changed: $changed, recreated: true, backup: $backup, log: $log}'
  return "$rc"
}

main() {
  [ -f "$ENV_FILE" ] || die ".env not found at $ENV_FILE (is remoteDir correct?)"
  local sub="${1:-}"
  shift || true
  case "$sub" in
    status)  cmd_status ;;
    logs)    cmd_logs "$@" ;;
    restart) cmd_restart ;;
    env-get) cmd_env_get ;;
    env-set) cmd_env_set ;;
    *) die "usage: bot-ops.sh {status|logs [N]|restart|env-get|env-set}" ;;
  esac
}

main "$@"
