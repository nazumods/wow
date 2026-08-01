#!/bin/sh
# Root only long enough to match the daemon socket's group, then run as `bun`.
#
# The socket is mode 0660 root:docker and the docker group's GID is host-specific (115 on the
# box, 999 on stock Debian), so naming a GID anywhere would be operator-supplied config — the
# thing #879 rules out. Instead the compose file starts the container as root, this script
# reads the GID off the socket itself, and drops to `bun` carrying that one supplementary
# group. Not a security boundary: anything holding the socket is root-equivalent on the host
# regardless (see the compose file). What it buys is a long-running process on a conventional
# UID, and state files owned by `bun` instead of the root-owned ones a root-run bot leaves.
set -e

SOCK=/var/run/docker.sock

if [ "$(id -u)" = "0" ]; then
  if [ -S "$SOCK" ]; then
    exec setpriv --reuid bun --regid bun --groups "$(stat -c %g "$SOCK")" -- "$@"
  fi
  exec setpriv --reuid bun --regid bun --clear-groups -- "$@"
fi

# Already non-root: an older compose file without `user: "0:0"` — nothing to drop.
exec "$@"
