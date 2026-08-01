import { describe, expect, test } from "bun:test";
import type { ContainerInspect, ImageSummary } from "./docker";

// redeploy.ts pulls in the `config` singleton (env resolved at import time) — see config.test.ts.
process.env.DISCORD_TOKEN ??= "test-token";
process.env.ANNOUNCE_CHANNEL_ID ??= "100";
const {
  buildCreateSpec,
  buildRemote,
  canonicalName,
  imageTags,
  replacementName,
  selectImagesToPrune,
} = await import("./redeploy");

const SELF: ContainerInspect = {
  Id: "a".repeat(64),
  Name: "/warbandeer-discord",
  Image: "sha256:deadbeef",
  State: { Running: true, Status: "running", ExitCode: 0 },
  Config: {
    Image: "warbandeer-discord-debug-bot:latest",
    Env: ["PATH=/usr/bin", "DISCORD_TOKEN=secret", "GIT_SHA=oldoldold", "AUTO_UPDATE=true"],
    Labels: {
      "com.docker.compose.project": "warbandeer-discord-debug",
      "com.docker.compose.service": "bot",
      "com.docker.compose.container-number": "1",
    },
    User: "0:0",
  },
  HostConfig: { RestartPolicy: { Name: "unless-stopped" }, NetworkMode: "wbd_default", Init: true },
  Mounts: [
    { Type: "volume", Name: "wbd_state", Source: "/var/lib/docker/volumes/wbd_state/_data", Destination: "/app/data", RW: true },
    { Type: "bind", Source: "/var/run/docker.sock", Destination: "/var/run/docker.sock", RW: true },
  ],
  NetworkSettings: { Networks: { wbd_default: {} } },
};

describe("naming", () => {
  test("canonicalName strips docker's leading slash", () => {
    expect(canonicalName("/warbandeer-discord")).toBe("warbandeer-discord");
    expect(canonicalName("warbandeer-discord")).toBe("warbandeer-discord");
  });

  // The replacement can't be created under the pinned container_name while the original holds
  // it, so it comes up beside it and takes the name during the retire.
  test("the replacement gets a name that can't collide with the original", () => {
    expect(replacementName("/warbandeer-discord")).toBe("warbandeer-discord-next");
    expect(replacementName("/warbandeer-discord")).not.toBe(canonicalName("/warbandeer-discord"));
  });
});

describe("buildRemote", () => {
  test("points the daemon at the bot's own subdir on the target branch", () => {
    expect(buildRemote("nazumods/wow", "main")).toBe(
      "https://github.com/nazumods/wow.git#main:apps/warbandeer-discord",
    );
  });

  test("carries a branch with slashes through intact", () => {
    expect(buildRemote("nazumods/wow", "feat/x")).toContain("#feat/x:");
  });
});

describe("imageTags", () => {
  test("tags the moving name and a per-sha name off the same repo", () => {
    expect(imageTags("warbandeer-discord-debug-bot:latest", "abcdef1234")).toEqual([
      "warbandeer-discord-debug-bot:latest",
      "warbandeer-discord-debug-bot:abcdef1",
    ]);
  });

  test("an untagged current image still yields both tags", () => {
    expect(imageTags("mybot", "abcdef1234")).toEqual(["mybot:latest", "mybot:abcdef1"]);
  });
});

describe("selectImagesToPrune", () => {
  const img = (tags: string[], created: number): ImageSummary => ({ Id: tags[0]!, RepoTags: tags, Created: created });
  const repo = "warbandeer-discord-debug-bot";

  test("keeps the newest N sha tags and drops the rest, oldest first", () => {
    const pruned = selectImagesToPrune(
      [
        img([`${repo}:1111111`], 100),
        img([`${repo}:2222222`], 300),
        img([`${repo}:3333333`], 200),
        img([`${repo}:4444444`], 400),
      ],
      `${repo}:latest`,
      2,
    );
    expect(pruned).toEqual([`${repo}:3333333`, `${repo}:1111111`]);
  });

  test("nothing to prune while at or under the limit", () => {
    expect(selectImagesToPrune([img([`${repo}:1111111`], 1)], `${repo}:latest`, 3)).toEqual([]);
  });

  // A tag someone parked by hand is a deliberate rollback target; only sha-shaped tags of this
  // image's own repo are ever candidates.
  test("never prunes :latest, a hand-named tag, or another repo's images", () => {
    const pruned = selectImagesToPrune(
      [
        img([`${repo}:latest`], 1),
        img([`${repo}:known-good`], 2),
        img(["other-bot:1111111"], 3),
        img([`${repo}:1111111`], 4),
      ],
      `${repo}:latest`,
      0,
    );
    expect(pruned).toEqual([`${repo}:1111111`]);
  });

  test("an untagged image doesn't blow up the scan", () => {
    expect(selectImagesToPrune([{ Id: "x", RepoTags: null, Created: 1 }], `${repo}:latest`, 0)).toEqual([]);
  });

  // A registry-qualified name's dots must match literally — as a regex they'd match any
  // character, and another repo's sha tags could get swept into the prune.
  test("a dotted registry name never matches another repo loosely", () => {
    const pruned = selectImagesToPrune(
      [
        img(["registryXexample.com/bot:1111111"], 1),
        img(["registry.example.com/bot:2222222"], 2),
      ],
      "registry.example.com/bot:latest",
      0,
    );
    expect(pruned).toEqual(["registry.example.com/bot:2222222"]);
  });
});

describe("buildCreateSpec", () => {
  const spec = buildCreateSpec(SELF, { image: "img:abc1234", handoffFrom: SELF.Id });

  // The crux of "zero config": everything the replacement needs is discovered from the
  // original's own inspect, so there is nothing for an operator to set up first.
  test("replicates the compose labels so compose still owns the container", () => {
    expect(spec.Labels["com.docker.compose.project"]).toBe("warbandeer-discord-debug");
    expect(spec.Labels["com.docker.compose.service"]).toBe("bot");
  });

  test("carries the env over and marks the replacement as a standby", () => {
    expect(spec.Env).toContain("DISCORD_TOKEN=secret");
    expect(spec.Env).toContain("AUTO_UPDATE=true");
    expect(spec.Env).toContain(`HANDOFF_FROM=${SELF.Id}`);
  });

  // Config.Env merges the image's baked ENV with the container's own, so copying it verbatim
  // would pin the OLD sha onto the new container and override the new image's — a bot that
  // updated correctly would then report its own update as a no-op.
  test("drops GIT_SHA so the new image's baked-in sha wins", () => {
    expect(spec.Env.some((e) => e.startsWith("GIT_SHA="))).toBe(false);
  });

  test("never stacks a second HANDOFF_FROM when one is already set", () => {
    const chained = buildCreateSpec(
      { ...SELF, Config: { ...SELF.Config, Env: [...SELF.Config.Env, "HANDOFF_FROM=older"] } },
      { image: "img:abc1234", handoffFrom: "newer" },
    );
    expect(chained.Env.filter((e) => e.startsWith("HANDOFF_FROM="))).toEqual(["HANDOFF_FROM=newer"]);
  });

  test("re-binds the state volume, so the replacement reads the report left for it", () => {
    expect(spec.HostConfig.Binds).toContain("wbd_state:/app/data:rw");
  });

  test("re-binds the daemon socket, so the replacement can retire the original", () => {
    expect(spec.HostConfig.Binds).toContain("/var/run/docker.sock:/var/run/docker.sock:rw");
  });

  // Without this the replacement falls back to the image's `USER bun` and can't open the socket.
  test("carries the user over", () => {
    expect(spec.User).toBe("0:0");
  });

  test("keeps the restart policy, so the replacement survives a host reboot", () => {
    expect(spec.HostConfig.RestartPolicy).toEqual({ Name: "unless-stopped" });
  });

  test("defaults the restart policy when the original somehow has none", () => {
    const bare = buildCreateSpec({ ...SELF, HostConfig: {} }, { image: "i", handoffFrom: "x" });
    expect(bare.HostConfig.RestartPolicy).toEqual({ Name: "unless-stopped" });
  });

  // Found on the debug box: the swapped-in bot ran with bun as PID 1 because compose's
  // `init: true` is container config, not image config, and wasn't carried over.
  test("keeps init, so the replacement still runs under docker-init", () => {
    expect(spec.HostConfig.Init).toBe(true);
    const bare = buildCreateSpec({ ...SELF, HostConfig: {} }, { image: "i", handoffFrom: "x" });
    expect(bare.HostConfig.Init).toBeUndefined();
  });

  test("stays on the original's network", () => {
    expect(spec.HostConfig.NetworkMode).toBe("wbd_default");
  });

  test("runs the freshly built image, not the one we're on", () => {
    expect(spec.Image).toBe("img:abc1234");
  });

  test("a read-only mount stays read-only", () => {
    const ro = buildCreateSpec(
      { ...SELF, Mounts: [{ Type: "bind", Source: "/etc/x", Destination: "/etc/x", RW: false }] },
      { image: "i", handoffFrom: "x" },
    );
    expect(ro.HostConfig.Binds).toEqual(["/etc/x:/etc/x:ro"]);
  });
});
