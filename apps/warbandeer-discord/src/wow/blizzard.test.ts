import { afterEach, beforeEach, describe, expect, test } from "bun:test";

// blizzard.ts imports the `config` singleton, so prime the required vars before pulling it in.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
process.env.BLIZZARD_CLIENT_ID ??= "id";
process.env.BLIZZARD_CLIENT_SECRET ??= "secret";
const { blizzardFetch, _resetBlizzardToken } = await import("./blizzard");

const realFetch = globalThis.fetch;
let tokenCount: number;
let apiAuth: string[];
let apiStatuses: number[];

beforeEach(() => {
  _resetBlizzardToken();
  tokenCount = 0;
  apiAuth = [];
  apiStatuses = [];
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    if (String(input).startsWith("https://oauth.battle.net/token")) {
      tokenCount++;
      return Response.json({ access_token: `tok${tokenCount}`, expires_in: 86400 });
    }
    apiAuth.push(new Headers(init?.headers).get("Authorization") ?? "");
    return new Response("{}", { status: apiStatuses.shift() ?? 200 });
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

describe("blizzardFetch", () => {
  test("reuses the cached token across calls", async () => {
    await blizzardFetch("https://api.test/a");
    await blizzardFetch("https://api.test/b");
    expect(tokenCount).toBe(1);
    expect(apiAuth).toEqual(["Bearer tok1", "Bearer tok1"]);
  });

  test("on a 401, drops the token and retries once with a fresh one", async () => {
    apiStatuses = [401, 200];
    const res = await blizzardFetch("https://api.test/a");
    expect(res.status).toBe(200);
    expect(tokenCount).toBe(2);
    expect(apiAuth).toEqual(["Bearer tok1", "Bearer tok2"]);
  });

  test("a second 401 is returned, not retried again", async () => {
    apiStatuses = [401, 401, 200];
    const res = await blizzardFetch("https://api.test/a");
    expect(res.status).toBe(401);
    expect(apiAuth).toHaveLength(2);
  });

  test("other errors are not retried", async () => {
    apiStatuses = [500];
    expect((await blizzardFetch("https://api.test/a")).status).toBe(500);
    expect(apiAuth).toHaveLength(1);
    expect(tokenCount).toBe(1);
  });
});
