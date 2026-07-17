import { config } from "./config";
import { state, saveState } from "./state";
import { requestRestart } from "./restart";

// Self-update detection. The bot has no releases of its own (apps/ is excluded from
// the release pipeline), so "am I stale?" is answered by comparing the commit this
// build was made from (GIT_SHA, baked in at image build) against the newest commit
// on the default branch that touched the bot's own directory.

const BOT_PATH = "apps/warbandeer-discord";

export type UpdateDecision =
  /** No GIT_SHA baked in — we can't tell what we're running. */
  | "disabled"
  /** Running the newest bot commit. */
  | "current"
  /** Stale: exit and let the orchestrator bring up the new code. */
  | "restart"
  /** Stale, but we already exited for this sha and came back unchanged. */
  | "suppressed";

/** Tolerant of short vs full shas, so GIT_SHA can be either. */
export function sameSha(a: string, b: string): boolean {
  const len = Math.min(a.length, b.length);
  if (len === 0) return false;
  return a.slice(0, len).toLowerCase() === b.slice(0, len).toLowerCase();
}

/**
 * Whether a stale build should exit to be replaced.
 *
 * `attemptedSha` is the sha we last exited for. If we're back and still stale for
 * that same sha, the orchestrator isn't supplying new code — exiting again would
 * just loop, so suppress it. `force` (an admin's /update) overrides that.
 */
export function decideUpdate(o: {
  runningSha?: string;
  latestSha: string;
  attemptedSha?: string;
  force?: boolean;
}): UpdateDecision {
  if (!o.runningSha) return "disabled";
  if (sameSha(o.runningSha, o.latestSha)) return "current";
  if (!o.force && o.attemptedSha && sameSha(o.attemptedSha, o.latestSha)) return "suppressed";
  return "restart";
}

/** Newest commit touching the bot's directory on `config.botBranch`. */
export async function fetchLatestBotSha(): Promise<string> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "warbandeer-discord",
  };
  if (config.githubToken) headers.Authorization = `Bearer ${config.githubToken}`;
  const res = await fetch(
    `https://api.github.com/repos/${config.githubRepo}/commits` +
      `?sha=${encodeURIComponent(config.botBranch)}&path=${encodeURIComponent(BOT_PATH)}&per_page=1`,
    { headers },
  );
  // 404 here is usually BOT_BRANCH naming a branch that doesn't exist on the remote.
  if (!res.ok) {
    throw new Error(
      `GitHub commits query failed: ${res.status} (repo ${config.githubRepo}, branch ${config.botBranch})`,
    );
  }
  const data = (await res.json()) as { sha: string }[];
  const sha = data[0]?.sha;
  if (!sha) throw new Error(`No commits found for ${BOT_PATH} on ${config.botBranch}`);
  return sha;
}

export interface UpdateCheck {
  decision: UpdateDecision;
  latestSha: string;
}

/**
 * Compare this build against the newest bot commit and, when stale, ask for a
 * restart so the orchestrator can bring up the new code. `force` is an admin's
 * explicit /update: it overrides the anti-loop suppression.
 *
 * The restart is only *requested* — `restart.ts` holds it until any in-flight
 * announcement and state write have finished.
 */
export async function checkForUpdate(force = false): Promise<UpdateCheck> {
  if (!config.gitSha) return { decision: "disabled", latestSha: "" };

  const latestSha = await fetchLatestBotSha();
  const decision = decideUpdate({
    runningSha: config.gitSha,
    latestSha,
    attemptedSha: state.attemptedUpdateToSha,
    force,
  });

  if (decision === "current" && state.attemptedUpdateToSha) {
    // The update landed — clear the marker so a later one isn't wrongly suppressed.
    state.attemptedUpdateToSha = undefined;
    await saveState();
  }

  if (decision === "suppressed") {
    console.warn(
      `[update] ${latestSha.slice(0, 7)} still pending after a restart — the orchestrator ` +
        `is not supplying new code. Rebuild the image (see README); not exiting again.`,
    );
  }

  if (decision === "restart") {
    state.attemptedUpdateToSha = latestSha;
    await saveState();
    requestRestart(`update ${config.gitSha.slice(0, 7)} -> ${latestSha.slice(0, 7)}`);
  }

  return { decision, latestSha };
}
