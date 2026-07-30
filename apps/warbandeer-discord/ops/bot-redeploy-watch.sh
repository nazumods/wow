#!/usr/bin/env bash
#
# bot-redeploy-watch.sh — the host half of `/update` (#868).
#
# The bot cannot redeploy itself. Inside the container it has no host access, mounting
# /var/run/docker.sock in would hand it root-equivalent control of the box, and even then it would
# be tearing itself down partway through its own build. So it signals instead: a stale build exits
# **76** ("rebuild me"), and this watcher is what turns that into an actual rebuild.
#
# Why a watcher and not a supervisor wrapper: the container runs under `restart: unless-stopped`,
# which respawns it on ANY exit code without ever showing that code to a parent process. The only
# place the code is observable from the host is the Docker event stream, so that is what we read.
#
# **The respawn races us, by design.** On exit 76 Docker immediately brings the old image back up;
# a few seconds later this rebuild recreates the container on the new one. The bot therefore bounces
# twice on an update. That is the price of keeping `unless-stopped`, and it is the right trade: if
# this watcher is dead or was never installed, the bot still comes back — just on the old image,
# which is exactly today's behaviour, and its own follow-up reports the no-op honestly.
#
# Install: see ops/README.md. Runs as the same user that runs the bot (in the `docker` group, no
# sudo), usually via the bot-redeploy-watch.service unit beside this file.
set -euo pipefail

REDEPLOY_EXIT_CODE=76

# Same knobs as bot-ops.sh, so one target's watcher is configured exactly like its panel.
PROJECT="${BOT_OPS_PROJECT:-warbandeer-discord-debug}"
CONTAINER="${BOT_OPS_CONTAINER:-warbandeer-discord}"

OPS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/bot-ops.sh"
[ -x "$OPS" ] || [ -f "$OPS" ] || { echo "watch: bot-ops.sh not found beside this script" >&2; exit 1; }

log() { echo "[redeploy-watch] $*"; }

log "watching $CONTAINER (project $PROJECT) for exit $REDEPLOY_EXIT_CODE"

# --filter event=die gives one line per container exit; the exit code rides along as an actor
# attribute. `docker events` blocks forever, so the unit's Restart=always is what covers a daemon
# restart or a dropped connection.
docker events \
  --filter "container=$CONTAINER" \
  --filter "event=die" \
  --format '{{.Actor.Attributes.exitCode}}' |
while read -r code; do
  # Every OTHER exit is ignored on purpose — including the ones this script causes. `up -d --build`
  # stops the running container first, which emits its own die (0, or 137/143 on a signal), and
  # acting on those would be an immediate rebuild loop.
  if [ "$code" != "$REDEPLOY_EXIT_CODE" ]; then
    log "ignoring exit $code"
    continue
  fi

  log "exit $REDEPLOY_EXIT_CODE — rebuilding"
  # Never fatal: a failed rebuild must not take the watcher down with it, or one bad build would
  # silently disable every future /update. The bot is already back up on the old image by now
  # (unless-stopped), so a failure here degrades to today's behaviour rather than an outage.
  if out="$(BOT_OPS_PROJECT="$PROJECT" BOT_OPS_CONTAINER="$CONTAINER" bash "$OPS" rebuild 2>&1)"; then
    log "rebuild ok: $out"
  else
    log "rebuild FAILED: $out"
  fi
done
