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
#   migrate       One-time: move .env + docker-compose.yml out of the checkout into the config
#                 dir, repoint the build context, recreate, and delete the checkout's .env.
#   env-set       Read KEY=VALUE lines from stdin, validate against the whitelist, back up
#                 .env beside itself, apply only real changes, then `up -d --force-recreate`
#                 to load them.
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
#   - RUNNING CONFIG LIVES OUTSIDE THE CHECKOUT. `.env` holds the live tokens, and a git checkout
#     of a PUBLIC repo is the wrong home for it — it is one `git add -A` from being published and
#     it survives `git reset --hard`. So .env and docker-compose.yml both live in the config dir
#     (WARBANDEER_DISCORD_CONFIG_DIR, default /opt/warbandeer-discord/<project>) and backups land
#     beside .env there. Relocating one file while leaving the other behind is not the fix: the
#     config LOCATION is what is configurable.
#   - They move TOGETHER because compose resolves `env_file: .env` relative to the compose file,
#     not the cwd (`--env-file` is a different mechanism — it controls interpolation). Splitting
#     them would silently feed the bot the wrong .env, so this script refuses that state.
#   - A checkout that still holds .env keeps working — see resolve_config below. That is a
#     compatibility path for un-migrated hosts and for running from source, not a second mode;
#     `migrate` is how a deployment moves, once, when its operator decides to.
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

# Where running config lives. Absolute only, so a relative path can't quietly resolve back into the
# checkout from whatever cwd a non-interactive SSH call lands in. Namespaced by project so debug and
# prod coexist on one host.
CONFIG_DIR="${WARBANDEER_DISCORD_CONFIG_DIR:-/opt/warbandeer-discord/$PROJECT}"
[[ "$CONFIG_DIR" = /* ]] || {
  echo "bot-ops: WARBANDEER_DISCORD_CONFIG_DIR must be an absolute path" >&2
  exit 1
}

# Bot dir = this script's parent's parent — the checkout. Still where the script itself ships from,
# and (pre-migration, or when running from source) where config may still be.
BOT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

die() { echo "bot-ops: $*" >&2; exit 1; }

# Pick the directory holding this deployment's config, preferring the machine location. CONFIG_HOME
# is the answer, and .env + docker-compose.yml BOTH come from it — never one from each, which would
# hand compose a different .env than the one this script edits.
resolve_config() {
  if [ -f "$CONFIG_DIR/.env" ]; then
    CONFIG_HOME="$CONFIG_DIR"
  elif [ -f "$BOT_DIR/.env" ]; then
    CONFIG_HOME="$BOT_DIR"
    # stderr, never stdout: every subcommand's stdout is a JSON/raw contract the panels parse.
    echo "bot-ops: using config from the checkout ($BOT_DIR) — run 'bot-ops.sh migrate' to move it" >&2
  else
    die "no .env found at $CONFIG_DIR or $BOT_DIR — copy .env.example to $CONFIG_DIR/.env"
  fi
  ENV_FILE="$CONFIG_HOME/.env"
  [ -f "$CONFIG_HOME/docker-compose.yml" ] \
    || die "$CONFIG_HOME holds .env but no docker-compose.yml — compose reads env_file relative to itself, so both must live together"
}

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
        --arg configDir "$CONFIG_HOME" \
        --argjson migrated "$([ "$CONFIG_HOME" != "$BOT_DIR" ] && echo true || echo false)" \
        '{running: $running, status: $status, image: $image, realmStatus: $realm,
          configDir: $configDir, migrated: $migrated}'
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
  cd "$CONFIG_HOME"
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

  # Beside .env, wherever that is. No separate backup location: once the config dir is itself
  # outside the checkout there is nothing to hide the backup from, and carving one file off to its
  # own directory would leave the actual secret file where it started.
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
  cd "$CONFIG_HOME"
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

# One-time move of a deployment's config out of the checkout. Deliberately a subcommand an operator
# runs, never something that happens at startup: silently relocating a file full of live tokens is a
# bad surprise, and it would be flat wrong in a dev checkout where the config legitimately belongs.
cmd_migrate() {
  need docker
  [ "$CONFIG_HOME" = "$BOT_DIR" ] || die "migrate: already migrated — config is at $CONFIG_HOME"
  [ -f "$BOT_DIR/docker-compose.yml" ] || die "migrate: no docker-compose.yml in $BOT_DIR"

  # Creating the directory needs root; everything after this point is unprivileged. Hand over the
  # exact command rather than making the operator work it out.
  [ -d "$CONFIG_DIR" ] || die "migrate: $CONFIG_DIR does not exist. Create it first:
  sudo install -d -o $(id -un) -g $(id -gn) -m 700 $CONFIG_DIR"
  [ -w "$CONFIG_DIR" ] || die "migrate: $CONFIG_DIR is not writable by $(id -un)"

  install -m 600 "$BOT_DIR/.env" "$CONFIG_DIR/.env"
  install -m 644 "$BOT_DIR/docker-compose.yml" "$CONFIG_DIR/docker-compose.yml"

  # `context: .` meant "the checkout" while the compose file lived in it. From the config dir it
  # would mean a directory with no Dockerfile, so repoint it. Fail loudly if the compose file no
  # longer has the shape we expect rather than writing a subtly broken one.
  grep -qE '^[[:space:]]+context: \.[[:space:]]*$' "$CONFIG_DIR/docker-compose.yml" \
    || die "migrate: no 'context: .' line in docker-compose.yml — repoint the build context by hand"
  sed -i -E "s|^([[:space:]]+)context: \.[[:space:]]*$|\1context: $BOT_DIR|" \
    "$CONFIG_DIR/docker-compose.yml"

  # Prove the relocated pair actually resolves before anything is torn down or deleted.
  ( cd "$CONFIG_DIR" && docker compose -p "$PROJECT" config -q ) \
    || die "migrate: $CONFIG_DIR/docker-compose.yml does not validate — nothing was removed"

  local recreate_log rc=0
  recreate_log="$( cd "$CONFIG_DIR" && docker compose -p "$PROJECT" up -d --force-recreate 2>&1 )" || rc=$?
  if [ "$rc" -ne 0 ]; then
    jq -n --arg log "$recreate_log" --arg dir "$CONFIG_DIR" \
      '{ok: false, movedTo: $dir, removedOldEnv: false,
        note: "recreate failed; the checkout .env was left in place", log: $log}'
    return "$rc"
  fi

  # Only now is the checkout copy redundant. Leaving it would defeat the entire point.
  rm -f "$BOT_DIR/.env"

  jq -n --arg dir "$CONFIG_DIR" --arg log "$recreate_log" \
    '{ok: true, movedTo: $dir, removedOldEnv: true, log: $log}'
}

main() {
  resolve_config
  local sub="${1:-}"
  shift || true
  case "$sub" in
    status)  cmd_status ;;
    logs)    cmd_logs "$@" ;;
    restart) cmd_restart ;;
    env-get) cmd_env_get ;;
    env-set) cmd_env_set ;;
    migrate) cmd_migrate ;;
    *) die "usage: bot-ops.sh {status|logs [N]|restart|env-get|env-set|migrate}" ;;
  esac
}

main "$@"
