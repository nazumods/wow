import { config } from "./config";
import { state, saveState, type PendingUpdateReport } from "./state";
import { handoffActive, requestRestart } from "./restart";
import { redeploy, redeployAvailable, type RedeployResult } from "./redeploy";

// Self-update detection. The bot has no releases of its own (apps/ is excluded from
// the release pipeline), so "am I stale?" is answered against the newest commit on the
// default branch that touched the bot's own directory.
//
// The question is ANCESTRY, not equality (#871). GIT_SHA is baked as `git rev-parse HEAD`
// — the tip you built from — which is only occasionally the last bot-touching commit,
// because non-bot commits land on main most days. Asking "is my sha THE newest bot commit"
// therefore called a correct, up-to-date deploy stale as its normal state: one pointless
// exit-75 per deploy under AUTO_UPDATE, and every admin /update forcing another. Asking
// "does my build CONTAIN the newest bot commit" is the question that was always meant.

const BOT_PATH = "apps/warbandeer-discord";

export type UpdateDecision =
  /** Can't tell: no GIT_SHA baked in, or the sha baked in isn't on the remote to compare against. */
  | "disabled"
  /** Running the newest bot commit. */
  | "current"
  /** Stale: exit and let the orchestrator bring up the new code. */
  | "restart"
  /** Stale, but we already exited for this sha and came back unchanged. */
  | "suppressed"
  /** A handoff is already in flight — this call refuses before touching anything. */
  | "busy";

/** Tolerant of short vs full shas, so GIT_SHA can be either. */
export function sameSha(a: string, b: string): boolean {
  const len = Math.min(a.length, b.length);
  if (len === 0) return false;
  return a.slice(0, len).toLowerCase() === b.slice(0, len).toLowerCase();
}

/**
 * How the running build relates to the newest bot commit, as GitHub's compare endpoint
 * answers it — plus two of our own for the cases it can't.
 */
export type ShaRelation =
  /** Built exactly that commit. */
  | "identical"
  /** The build contains it (the normal case: built from a main tip newer than it). */
  | "ahead"
  /** Genuinely missing bot code. */
  | "behind"
  /** Built off a side branch that doesn't contain it. */
  | "diverged"
  /** The running sha isn't on the remote at all — nothing to compare against. */
  | "unpublished"
  /** The compare call failed; fall back to treating a sha mismatch as stale. */
  | "unknown";

/**
 * Whether a stale build should exit to be replaced.
 *
 * `relation` is the ancestry answer; it decides everything the bare sha comparison used to
 * get wrong. `ahead` is the ordinary state of a correct deploy, so it must read as `current`.
 * `unpublished` disables rather than restarts: a build whose sha the remote has never seen
 * (an unpushed branch) can never be matched, so offering an update would be offering one that
 * can never be delivered. `unknown` — an API failure — deliberately falls through to the old
 * behaviour rather than inventing a verdict.
 *
 * `attemptedSha` is the sha we last exited for. If we're back and still stale for
 * that same sha, the orchestrator isn't supplying new code — exiting again would
 * just loop, so suppress it. `force` (an admin's /update) overrides that.
 */
export function decideUpdate(o: {
  runningSha?: string;
  latestSha: string;
  relation?: ShaRelation;
  attemptedSha?: string;
  force?: boolean;
}): UpdateDecision {
  if (!o.runningSha) return "disabled";
  // Equality shortcut: no relation needed, so the common path spends no extra API request.
  if (sameSha(o.runningSha, o.latestSha)) return "current";
  if (o.relation === "unpublished") return "disabled";
  if (o.relation === "identical" || o.relation === "ahead") return "current";
  // behind | diverged | unknown | absent. `diverged` restarts with `behind`: both answer the
  // question actually being asked — does this build contain the newest bot commit — with no.
  // A deliberate side-branch deploy points BOT_BRANCH at that branch and goes identical/ahead.
  if (!o.force && o.attemptedSha && sameSha(o.attemptedSha, o.latestSha)) return "suppressed";
  return "restart";
}

/** Who asked for the update, and where to reach them once the bot is back. */
export interface UpdateRequester {
  userId: string;
  channelId?: string;
  applicationId?: string;
  interactionToken?: string;
}

/**
 * The follow-up record to persist across a restart, or `undefined` when nobody asked —
 * an `AUTO_UPDATE` exit has no requester, so it leaves no report and stays silent.
 */
export function buildUpdateReport(o: {
  runningSha: string;
  latestSha: string;
  requester?: UpdateRequester;
  now: number;
}): PendingUpdateReport | undefined {
  if (!o.requester) return undefined;
  return { ...o.requester, fromSha: o.runningSha, toSha: o.latestSha, requestedAt: o.now };
}

function apiHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "warbandeer-discord",
  };
  if (config.githubToken) headers.Authorization = `Bearer ${config.githubToken}`;
  return headers;
}

/** Newest commit touching the bot's directory on `config.botBranch`. */
export async function fetchLatestBotSha(): Promise<string> {
  const headers = apiHeaders();
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

/**
 * Ask GitHub how `runningSha` relates to `latestSha`.
 *
 * `compare/{base}...{head}` reports `head`'s position relative to `base`, so with the newest
 * bot commit as base the answer is read directly: `ahead` means the running build contains it.
 *
 * Never throws. A 404 is the meaningful case — the running sha isn't on the remote, which is a
 * real answer (`unpublished`) rather than an error. Anything else that goes wrong is `unknown`,
 * so a GitHub outage degrades the check instead of taking startup down with it.
 */
export async function fetchShaRelation(
  latestSha: string,
  runningSha: string,
): Promise<ShaRelation> {
  try {
    const res = await fetch(
      `https://api.github.com/repos/${config.githubRepo}/compare/` +
        `${encodeURIComponent(latestSha)}...${encodeURIComponent(runningSha)}`,
      { headers: apiHeaders() },
    );
    if (res.status === 404) return "unpublished";
    if (!res.ok) {
      console.warn(`[update] compare failed: ${res.status} — treating a sha mismatch as stale`);
      return "unknown";
    }
    const { status } = (await res.json()) as { status?: string };
    if (
      status === "identical" ||
      status === "ahead" ||
      status === "behind" ||
      status === "diverged"
    ) {
      return status;
    }
    console.warn(`[update] compare returned an unrecognised status: ${status}`);
    return "unknown";
  } catch (err) {
    console.warn(`[update] compare errored: ${(err as Error).message}`);
    return "unknown";
  }
}

/** Why self-update is off, when the decision is `disabled`. */
export type DisabledReason =
  /** No GIT_SHA baked in at image build. */
  | "no-sha"
  /** GIT_SHA is set but the remote has never seen it (an unpushed branch). */
  | "unpublished-sha";

export interface UpdateCheck {
  decision: UpdateDecision;
  latestSha: string;
  /** Set only when `decision` is `disabled`. */
  reason?: DisabledReason;
  /** Set when `decision` is `restart` and the swap was attempted in-process (#879). Present
   *  only on failure — a successful handoff never returns, since the replacement retires us. */
  redeploy?: RedeployResult;
}

/**
 * Compare this build against the newest bot commit and, when stale, ask for a
 * restart so the orchestrator can bring up the new code. `force` is an admin's
 * explicit /update: it overrides the anti-loop suppression. `requester` is that
 * admin, recorded so the next boot can report back what build it landed on.
 *
 * The restart is only *requested* — `restart.ts` holds it until any in-flight
 * announcement and state write have finished.
 */
export async function checkForUpdate(
  o: { force?: boolean; requester?: UpdateRequester } = {},
): Promise<UpdateCheck> {
  // Refused before anything else — even reading the shas. A second /update mid-swap would
  // otherwise overwrite the in-flight attempt's pendingUpdateReport, then force-remove its
  // replacement (`force: true` bypasses the anti-loop suppression, and interaction handling
  // does not quiesce during a handoff — only the scheduler does).
  if (handoffActive()) return { decision: "busy", latestSha: "" };
  if (!config.gitSha) return { decision: "disabled", latestSha: "", reason: "no-sha" };

  const latestSha = await fetchLatestBotSha();
  // Only when the shas differ — the equality shortcut in `decideUpdate` covers the rest, so the
  // ordinary "built exactly the newest bot commit" path still costs a single request.
  const relation = sameSha(config.gitSha, latestSha)
    ? undefined
    : await fetchShaRelation(latestSha, config.gitSha);
  const decision = decideUpdate({
    runningSha: config.gitSha,
    latestSha,
    relation,
    attemptedSha: state.attemptedUpdateToSha,
    force: o.force,
  });

  if (decision === "disabled") {
    // Reachable only via `unpublished` here — the no-sha case returned above.
    console.warn(
      `[update] self-update is off: ${config.gitSha.slice(0, 7)} is not on ` +
        `${config.githubRepo}, so there is nothing to compare it against.`,
    );
    return { decision, latestSha, reason: "unpublished-sha" };
  }

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
    // Written before the replacement starts and read by it after — never by both at once,
    // which is what keeps two containers off the same state file (#879).
    state.pendingUpdateReport = buildUpdateReport({
      runningSha: config.gitSha,
      latestSha,
      requester: o.requester,
      now: Date.now(),
    });
    await saveState();
    return { decision, latestSha, redeploy: await applyUpdate(latestSha) };
  }

  return { decision, latestSha };
}

/**
 * Become the new build.
 *
 * With the daemon socket mounted the bot does the whole thing itself: build, start the
 * replacement, hand over. Without it there is nothing to build with, so it falls back to the
 * original behaviour — exit and let whatever supervises the container supply a new image. That
 * fallback is why an existing deployment on an older compose file keeps working unchanged.
 */
async function applyUpdate(latestSha: string): Promise<RedeployResult | undefined> {
  const shortRun = config.gitSha!.slice(0, 7);
  const shortNew = latestSha.slice(0, 7);

  if (!(await redeployAvailable())) {
    console.log("[update] no docker socket — falling back to exit-and-be-respawned");
    requestRestart(`update ${shortRun} -> ${shortNew}`);
    return undefined;
  }

  // `redeploy` resolving at all means the swap failed — success kills this process mid-await.
  const result = await redeploy(latestSha);

  // We're still the live bot, so the update is un-owed: drop the markers, or the next boot
  // would deliver a follow-up for a restart that never occurred and the anti-loop guard would
  // suppress a later, genuine attempt.
  state.attemptedUpdateToSha = undefined;
  state.pendingUpdateReport = undefined;
  await saveState();
  console.warn(`[update] redeploy to ${shortNew} failed: ${result.error ?? result.outcome}`);
  return result;
}
