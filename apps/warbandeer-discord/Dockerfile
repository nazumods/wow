FROM oven/bun:1-slim
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY src ./src

# Pre-create the state dir so the non-root user can write data/state.json
RUN mkdir -p data && chown -R bun:bun /app
USER bun
VOLUME /app/data

CMD ["bun", "run", "src/index.ts"]
