FROM oven/bun:1-slim
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY src ./src
COPY entrypoint.sh ./

# Commit this image was built from — self-update compares it against the newest bot
# commit on main. Unset (the default) simply disables self-update.
ARG GIT_SHA=""
ENV GIT_SHA=$GIT_SHA

# Pre-create the state dir so the non-root user can write data/state.json
RUN mkdir -p data && chown -R bun:bun /app
USER bun
VOLUME /app/data

# When compose starts the container as root (for the daemon socket — see docker-compose.yml),
# the entrypoint drops to `bun` after joining the socket's group. Under the image's own
# `USER bun` it execs the CMD untouched.
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["bun", "run", "src/index.ts"]
