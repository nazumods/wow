FROM oven/bun:1-slim
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY src ./src

# Commit this image was built from — self-update compares it against the newest bot
# commit on main. Unset (the default) simply disables self-update.
ARG GIT_SHA=""
ENV GIT_SHA=$GIT_SHA

# Pre-create the state dir so the non-root user can write data/state.json
RUN mkdir -p data && chown -R bun:bun /app
USER bun
VOLUME /app/data

CMD ["bun", "run", "src/index.ts"]
