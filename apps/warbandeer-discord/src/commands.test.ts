import { describe, expect, test } from "bun:test";

// `commands.ts` pulls in the `config` singleton, which resolves process.env at import
// time — satisfy the required vars before importing so this file runs standalone.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const { bareName } = await import("./commands");

describe("bareName", () => {
  test("strips the configured prefix", () => {
    expect(bareName("r_dmf", "r_")).toBe("dmf");
    expect(bareName("r_status", "r_")).toBe("status");
  });

  test("is a no-op when no prefix is configured", () => {
    expect(bareName("dmf", "")).toBe("dmf");
    expect(bareName("status", "")).toBe("status");
  });

  // The bug this guards: dispatch used to slice(prefix.length) unconditionally, so a command
  // registered without the prefix became "update" -> "date" and matched no case — it showed up
  // in Discord and silently did nothing.
  test("passes an unprefixed name through instead of mangling it", () => {
    expect(bareName("update", "r_")).toBe("update");
    expect(bareName("report", "r_")).toBe("report");
  });

  test("leaves a name that merely shares a leading letter alone", () => {
    expect(bareName("reset", "r_")).toBe("reset");
  });

  test("strips only the first occurrence", () => {
    expect(bareName("r_r_dmf", "r_")).toBe("r_dmf");
  });
});
