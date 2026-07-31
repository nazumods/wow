import { afterEach, describe, expect, test } from "bun:test";
import { parseBuildOutput, parseContainerId } from "./docker";

// The socket-facing calls are exercised through a stubbed `globalThis.fetch`, in the style of
// update.test.ts — the parsing they depend on is pure and tested directly.
const { buildImage, daemonReachable, stopContainer, removeContainer } = await import("./docker");

describe("parseContainerId", () => {
  const ID = "f".repeat(64);

  test("reads the id out of a docker mountinfo line", () => {
    expect(
      parseContainerId(
        `1234 1023 0:59 /containers/${ID}/hostname /etc/hostname rw,relatime - ext4 /dev/sda1 rw`,
      ),
    ).toBe(ID);
  });

  test("handles the /docker/containers/ layout too", () => {
    expect(parseContainerId(`654 321 0:59 /var/lib/docker/containers/${ID}/resolv.conf /etc/resolv.conf rw`)).toBe(
      ID,
    );
  });

  test("undefined when nothing in the file names a container", () => {
    expect(parseContainerId("22 1 0:21 / /proc rw,nosuid - proc proc rw")).toBeUndefined();
  });

  // Short ids appear all over docker output; only the full 64-hex one identifies a container.
  test("ignores a short id", () => {
    expect(parseContainerId("1 1 0:1 /containers/abc123/hostname /etc/hostname rw")).toBeUndefined();
  });
});

describe("parseBuildOutput", () => {
  test("a clean build is ok", () => {
    expect(
      parseBuildOutput('{"stream":"Step 1/9"}\n{"stream":"Successfully built abc"}\n'),
    ).toEqual({ ok: true });
  });

  // The whole reason this exists: /build answers 200 even when the build failed, with the
  // failure buried in the stream. Trusting the status code alone would ship every broken build.
  test("an error line fails the build despite a 200", () => {
    const { ok, error } = parseBuildOutput(
      '{"stream":"Step 1/9"}\n{"error":"pull access denied","errorDetail":{"message":"pull access denied"}}\n',
    );
    expect(ok).toBe(false);
    expect(error).toBe("pull access denied");
  });

  test("prefers errorDetail.message, which carries the fuller text", () => {
    expect(
      parseBuildOutput('{"error":"failed","errorDetail":{"message":"no such ref: main"}}').error,
    ).toBe("no such ref: main");
  });

  test("non-JSON noise in the stream is skipped, not treated as a verdict", () => {
    expect(parseBuildOutput('not json\n{"stream":"ok"}\n\n')).toEqual({ ok: true });
  });

  test("empty output is ok — nothing reported a problem", () => {
    expect(parseBuildOutput("")).toEqual({ ok: true });
  });
});

describe("daemon calls", () => {
  const realFetch = globalThis.fetch;
  let calls: { url: string; method: string }[] = [];

  const stub = (impl: (url: string, init?: RequestInit) => Response) => {
    calls = [];
    globalThis.fetch = ((url: string, init?: RequestInit & { unix?: string }) => {
      calls.push({ url: String(url), method: init?.method ?? "GET" });
      return Promise.resolve(impl(String(url), init));
    }) as unknown as typeof fetch;
  };
  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  test("daemonReachable is false when the socket isn't there, not a throw", async () => {
    stub(() => {
      throw new Error("ENOENT /var/run/docker.sock");
    });
    expect(await daemonReachable()).toBe(false);
  });

  test("daemonReachable is true on a ping", async () => {
    stub(() => new Response("OK", { status: 200 }));
    expect(await daemonReachable()).toBe(true);
    expect(calls[0]?.url).toContain("/_ping");
  });

  test("a build passes the remote context, both tags and the sha build-arg", async () => {
    stub(() => new Response('{"stream":"done"}', { status: 200 }));
    await buildImage({
      remote: "https://github.com/o/r.git#main:apps/warbandeer-discord",
      tags: ["img:latest", "img:abc1234"],
      buildArgs: { GIT_SHA: "abc1234" },
    });
    const url = calls[0]!.url;
    expect(calls[0]!.method).toBe("POST");
    expect(decodeURIComponent(url)).toContain("remote=https://github.com/o/r.git#main:apps/warbandeer-discord");
    expect(decodeURIComponent(url)).toContain("t=img:latest");
    expect(decodeURIComponent(url)).toContain("t=img:abc1234");
    expect(decodeURIComponent(url)).toContain('buildargs={"GIT_SHA":"abc1234"}');
  });

  // Both are "the state we wanted" — treating them as errors would abort a handoff over a
  // container that had already done what we were asking for.
  test("stopping an already-stopped or already-gone container is not an error", async () => {
    for (const status of [304, 404]) {
      stub(() => new Response("", { status }));
      await stopContainer("abc");
    }
  });

  test("removing an already-gone container is not an error", async () => {
    stub(() => new Response("", { status: 404 }));
    await removeContainer("abc");
  });

  test("a real stop failure still throws", async () => {
    stub(() => new Response("boom", { status: 500 }));
    await expect(stopContainer("abc")).rejects.toThrow("docker stop abc failed: 500");
  });
});
