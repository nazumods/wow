import { config } from "./config";

export interface Release {
  id: number;
  name: string;
  tag: string;
  url: string;
}

/**
 * A watched repo's releases, or `null` when GitHub answers 404 — the repo doesn't exist, or
 * `GITHUB_TOKEN` can't see it (GitHub deliberately 404s a private repo rather than 403ing it,
 * so the two are indistinguishable from here). That is a standing condition, not a blip, so it
 * returns rather than throws and lets the caller skip the repo quietly; every other failure —
 * 403 rate-limit, 401 bad token, 5xx — still throws, so a real outage stays loud. A repo with
 * no releases answers 200 with `[]`, so it never reaches the 404 path.
 */
export async function fetchReleases(repo: string): Promise<Release[] | null> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "warbandeer-discord",
  };
  if (config.githubToken) headers.Authorization = `Bearer ${config.githubToken}`;
  const res = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=15`, { headers });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`GitHub releases query failed for ${repo}: ${res.status}`);
  const data = (await res.json()) as {
    id: number;
    name: string | null;
    tag_name: string;
    html_url: string;
    draft: boolean;
    prerelease: boolean;
  }[];
  return data
    .filter((r) => !r.draft)
    .map((r) => ({ id: r.id, name: r.name ?? r.tag_name, tag: r.tag_name, url: r.html_url }));
}

export interface ReleaseAnnouncements {
  /** Releases to post now, oldest-first (so a burst reads in publish order). */
  toAnnounce: Release[];
  /** The repo's new seen-id list to persist. */
  nextSeen: number[];
}

/**
 * Decide what to announce for one repo. `seen` is the repo's persisted seen-id list, or
 * `undefined` when it has never been polled — the first poll seeds silently (announce
 * nothing, remember everything) so a freshly watched repo never dumps its backlog. A repo
 * seeded with no releases keeps a defined (empty) list, so its genuine first release later
 * still announces.
 */
export function decideReleaseAnnouncements(
  releases: Release[],
  seen: number[] | undefined,
): ReleaseAnnouncements {
  if (seen === undefined) return { toAnnounce: [], nextSeen: releases.map((r) => r.id) };
  const seenSet = new Set(seen);
  const toAnnounce = releases.filter((r) => !seenSet.has(r.id)).reverse();
  return { toAnnounce, nextSeen: [...seen, ...toAnnounce.map((r) => r.id)] };
}

export type ReachabilityTransition = "lost" | "recovered";

export interface ReachabilityLog {
  /**
   * Record one observation of `repo` and report whether it changed state: `"lost"` on the
   * first failure, `"recovered"` when it answers again, `null` while it stays as it was.
   * Log only on a transition and a repo that is unreachable for good reports itself once
   * instead of once per poll.
   */
  observe(repo: string, reachable: boolean): ReachabilityTransition | null;
}

/** Deliberately in-memory: a restart re-reports a still-unreachable repo exactly once, which
 * is the right amount of noise after a redeploy. */
export function createReachabilityLog(): ReachabilityLog {
  const unreachable = new Set<string>();
  return {
    observe(repo, reachable) {
      if (reachable) return unreachable.delete(repo) ? "recovered" : null;
      if (unreachable.has(repo)) return null;
      unreachable.add(repo);
      return "lost";
    },
  };
}

export interface CreatedIssue {
  number: number;
  url: string;
}

function writeHeaders(): Record<string, string> {
  if (!config.githubToken) throw new Error("GITHUB_TOKEN is not set — cannot write to GitHub");
  return {
    Accept: "application/vnd.github+json",
    "User-Agent": "warbandeer-discord",
    "Content-Type": "application/json",
    Authorization: `Bearer ${config.githubToken}`,
  };
}

/** Create a GitHub issue. Requires GITHUB_TOKEN with issues:write on `repo`. */
export async function createIssue(
  repo: string,
  title: string,
  body: string,
  labels: string[],
): Promise<CreatedIssue> {
  const res = await fetch(`https://api.github.com/repos/${repo}/issues`, {
    method: "POST",
    headers: writeHeaders(),
    body: JSON.stringify({ title, body, labels }),
  });
  if (!res.ok) throw new Error(`GitHub create-issue failed: ${res.status} ${await res.text()}`);
  const data = (await res.json()) as { number: number; html_url: string };
  return { number: data.number, url: data.html_url };
}

/** Idempotently ensure a label exists so create-issue never fails on a missing label:
 * 201 = created, 422 = already exists — both are success. Best-effort; other errors warn. */
export async function ensureLabel(repo: string, name: string): Promise<void> {
  if (!config.githubToken) return;
  const res = await fetch(`https://api.github.com/repos/${repo}/labels`, {
    method: "POST",
    headers: writeHeaders(),
    body: JSON.stringify({ name, color: "ededed" }),
  });
  if (!res.ok && res.status !== 422) console.warn(`ensureLabel "${name}" on ${repo}: ${res.status}`);
}
