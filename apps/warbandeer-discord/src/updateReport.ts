import { REST, Routes, type Client } from "discord.js";
import { config } from "./config";
import { state, saveState, type PendingUpdateReport } from "./state";
import { sameSha } from "./update";

// The other half of /update: the command says what it's *trying* to become, this says what it
// actually became. Without it the dangerous failure — a container recreated without --build,
// which comes back on the old image and logs a perfectly clean startup — is indistinguishable
// from a successful update.

/** Interaction tokens are valid ~15 min; a restart is normally far inside that. */
const TOKEN_TTL_MS = 15 * 60 * 1000;

/** Past this, the restart is ancient history (a box that was down for days) — log, don't message. */
const MAX_REPORT_AGE_MS = 24 * 60 * 60 * 1000;

/** Ephemeral, matching the /update reply this follows up on. */
const EPHEMERAL = 1 << 6;

export type UpdateOutcome =
  /** Came back on the sha we exited for — the update landed. */
  | "updated"
  /** Came back on the sha we left on — the image was never rebuilt. */
  | "noop"
  /** Came back on some third sha — someone else deployed in between. */
  | "unexpected"
  /** Came back without a GIT_SHA baked in — nothing to compare. */
  | "unknown";

export function decideUpdateOutcome(o: {
  report: PendingUpdateReport;
  runningSha?: string;
}): UpdateOutcome {
  if (!o.runningSha) return "unknown";
  if (sameSha(o.runningSha, o.report.toSha)) return "updated";
  if (sameSha(o.runningSha, o.report.fromSha)) return "noop";
  return "unexpected";
}

const short = (sha: string) => sha.slice(0, 7);

/** Names both shas, so nobody has to compare them by eye to learn which case this is. */
export function updateOutcomeMessage(
  outcome: UpdateOutcome,
  report: PendingUpdateReport,
  runningSha?: string,
): string {
  const now = runningSha ? short(runningSha) : "unknown";
  switch (outcome) {
    case "updated":
      return `✅ Back up on \`${now}\` — updated from \`${short(report.fromSha)}\`.`;
    case "noop":
      return (
        `⚠️ Back up on \`${now}\` — the **same build** I left on. ` +
        `\`${short(report.toSha)}\` was not picked up: the image wasn't rebuilt. ` +
        "Redeploy with `--build` (see the README)."
      );
    case "unexpected":
      return (
        `❓ Back up on \`${now}\`, which is neither the build I left on ` +
        `(\`${short(report.fromSha)}\`) nor the one I was picking up ` +
        `(\`${short(report.toSha)}\`) — something else deployed in between.`
      );
    case "unknown":
      return (
        `❓ Back up, but with no \`GIT_SHA\` baked in — I can't tell whether ` +
        `\`${short(report.toSha)}\` was picked up. Rebuild with \`GIT_SHA\` to restore this check.`
      );
  }
}

/** Whether the stored interaction token is still inside its validity window. */
export function tokenUsable(report: PendingUpdateReport, now: number): boolean {
  if (!report.interactionToken || !report.applicationId) return false;
  return now - report.requestedAt < TOKEN_TTL_MS;
}

export function reportTooOld(report: PendingUpdateReport, now: number): boolean {
  return now - report.requestedAt >= MAX_REPORT_AGE_MS;
}

export type DeliveryRoute = "token" | "dm" | "channel" | "none";

export interface Deliverers {
  viaToken(report: PendingUpdateReport, content: string): Promise<void>;
  viaDm(report: PendingUpdateReport, content: string): Promise<void>;
  viaChannel(report: PendingUpdateReport, content: string): Promise<void>;
}

/**
 * Interaction follow-up first (it lands where the command was run), then a DM, then the
 * channel. Every route may legitimately be gone — an expired token, closed DMs, a deleted
 * channel — so each failure is logged and falls through rather than propagating.
 */
export async function deliverUpdateReport(
  report: PendingUpdateReport,
  content: string,
  deliverers: Deliverers,
  now: number,
): Promise<DeliveryRoute> {
  const routes: [DeliveryRoute, () => Promise<void>][] = [];
  if (tokenUsable(report, now)) routes.push(["token", () => deliverers.viaToken(report, content)]);
  routes.push(["dm", () => deliverers.viaDm(report, content)]);
  if (report.channelId) routes.push(["channel", () => deliverers.viaChannel(report, content)]);

  for (const [route, send] of routes) {
    try {
      await send();
      return route;
    } catch (err) {
      console.warn(`[updateReport] ${route} delivery failed`, err);
    }
  }
  return "none";
}

function liveDeliverers(client: Client): Deliverers {
  return {
    // The follow-up webhook route is authenticated by the interaction token itself, so this
    // posts unauthenticated. discord.js's WebhookClient can't set the ephemeral flag.
    async viaToken(report, content) {
      await new REST().post(
        Routes.webhook(report.applicationId!, report.interactionToken!) as `/${string}`,
        { body: { content, flags: EPHEMERAL }, auth: false },
      );
    },
    async viaDm(report, content) {
      const user = await client.users.fetch(report.userId);
      await user.send(content);
    },
    async viaChannel(report, content) {
      const channel = await client.channels.fetch(report.channelId!);
      if (!channel?.isSendable()) throw new Error(`Channel ${report.channelId} is not sendable`);
      await channel.send(`<@${report.userId}> ${content}`);
    },
  };
}

/**
 * Deliver the follow-up owed from a `/update`-initiated restart, if any.
 *
 * The marker is cleared and persisted *before* delivery is attempted: a delivery that fails
 * must not leave a report that re-fires on every subsequent boot. Nothing here throws — a
 * follow-up is never worth wedging startup over.
 */
export async function reportUpdateOutcome(client: Client): Promise<void> {
  const report = state.pendingUpdateReport;
  if (!report) return;

  state.pendingUpdateReport = undefined;
  await saveState();

  const now = Date.now();
  if (reportTooOld(report, now)) {
    console.log(
      `[updateReport] dropping a stale report for ${short(report.toSha)} ` +
        `(requested ${Math.round((now - report.requestedAt) / 3_600_000)}h ago)`,
    );
    return;
  }

  const outcome = decideUpdateOutcome({ report, runningSha: config.gitSha });
  const content = updateOutcomeMessage(outcome, report, config.gitSha);
  const route = await deliverUpdateReport(report, content, liveDeliverers(client), now);
  console.log(`[updateReport] ${outcome} (delivered via ${route}): ${content}`);
}
