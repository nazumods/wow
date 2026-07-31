import { describe, expect, test } from "bun:test";
import {
  bootMode,
  decideHandoffOutcome,
  handoffFailureMessage,
  HANDOFF_DEADLINE_MS,
  HANDOFF_FROM_ENV,
  type HandoffMarker,
  type ReplacementState,
} from "./handoff";

const marker = (status: "ready" | "failed", error?: string): HandoffMarker => ({
  status,
  error,
  at: 0,
});
const running: ReplacementState = { running: true, status: "running", exitCode: 0 };
const exited: ReplacementState = { running: false, status: "exited", exitCode: 1 };
const created: ReplacementState = { running: false, status: "created", exitCode: 0 };

describe("bootMode", () => {
  test("HANDOFF_FROM is the whole instruction to boot in standby", () => {
    expect(bootMode({ [HANDOFF_FROM_ENV]: "abc123" })).toBe("standby");
  });

  test("a normal boot has no handoff env at all", () => {
    expect(bootMode({})).toBe("normal");
  });

  // An empty value is what an unset compose variable interpolates to; it must not arm standby,
  // or an ordinary `docker compose up` would come up refusing to answer anything.
  test("an empty HANDOFF_FROM is a normal boot, not a standby", () => {
    expect(bootMode({ [HANDOFF_FROM_ENV]: "" })).toBe("normal");
  });
});

describe("decideHandoffOutcome", () => {
  test("waits while the replacement is running and nothing has been signalled", () => {
    expect(decideHandoffOutcome({ replacement: running, elapsedMs: 0 })).toBe("waiting");
  });

  test("a just-created container is still starting, not a failure", () => {
    expect(decideHandoffOutcome({ replacement: created, elapsedMs: 0 })).toBe("waiting");
  });

  test("a ready marker is the handoff", () => {
    expect(decideHandoffOutcome({ marker: marker("ready"), replacement: running, elapsedMs: 0 })).toBe(
      "ready",
    );
  });

  test("a failed marker ends it", () => {
    expect(decideHandoffOutcome({ marker: marker("failed"), replacement: running, elapsedMs: 0 })).toBe(
      "failed",
    );
  });

  test("a replacement that exited without signalling has failed", () => {
    expect(decideHandoffOutcome({ replacement: exited, elapsedMs: 0 })).toBe("failed");
  });

  test("a replacement that vanished has failed", () => {
    expect(decideHandoffOutcome({ replacement: undefined, elapsedMs: 0 })).toBe("failed");
  });

  test("running out of time is a timeout, distinct from a failure", () => {
    expect(decideHandoffOutcome({ replacement: running, elapsedMs: HANDOFF_DEADLINE_MS })).toBe(
      "timeout",
    );
  });

  // The race the marker exists to close: a verified replacement is already stopping us, so it
  // may be mid-stop when we look at it. What it *said* has to outrank how it currently looks,
  // or a successful handoff gets torn down one poll before it completes.
  test("a ready marker wins over a container caught mid-stop", () => {
    expect(decideHandoffOutcome({ marker: marker("ready"), replacement: exited, elapsedMs: 0 })).toBe(
      "ready",
    );
  });

  test("a ready marker wins over a container already gone", () => {
    expect(
      decideHandoffOutcome({ marker: marker("ready"), replacement: undefined, elapsedMs: 0 }),
    ).toBe("ready");
  });

  test("a ready marker wins over an expired deadline", () => {
    expect(
      decideHandoffOutcome({
        marker: marker("ready"),
        replacement: running,
        elapsedMs: HANDOFF_DEADLINE_MS * 2,
      }),
    ).toBe("ready");
  });
});

describe("handoffFailureMessage", () => {
  const sha = "abcdef1234567890";

  test("a timeout says how long it waited", () => {
    const msg = handoffFailureMessage("timeout", { targetSha: sha });
    expect(msg).toContain("abcdef1");
    expect(msg).toContain(`${HANDOFF_DEADLINE_MS / 1000}s`);
  });

  test("a failure carries the reason when there is one", () => {
    expect(handoffFailureMessage("failed", { targetSha: sha, error: "build failed: no such ref" })).toContain(
      "build failed: no such ref",
    );
  });

  test("a failure without a reason still reads as a sentence", () => {
    expect(handoffFailureMessage("failed", { targetSha: sha })).not.toContain("undefined");
  });

  // Distinct from `failed` on purpose: the new build verified fine — what broke is the
  // retiring, which points at the daemon, not the code being deployed.
  test("a stall blames the socket, not the build", () => {
    const msg = handoffFailureMessage("stalled", { targetSha: sha });
    expect(msg).toContain("verified");
    expect(msg).toContain("socket");
  });

  // The headline of #879: whatever went wrong, the original is still serving.
  test("every failure says the current build is still running", () => {
    for (const outcome of ["failed", "timeout", "stalled"] as const) {
      expect(handoffFailureMessage(outcome, { targetSha: sha })).toContain("current build");
    }
  });
});
