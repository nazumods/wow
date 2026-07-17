import { config } from "./config";

export interface Release {
  id: number;
  name: string;
  tag: string;
  url: string;
}

export async function fetchReleases(): Promise<Release[]> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "warbandeer-discord",
  };
  if (config.githubToken) headers.Authorization = `Bearer ${config.githubToken}`;
  const res = await fetch(
    `https://api.github.com/repos/${config.githubRepo}/releases?per_page=15`,
    { headers },
  );
  if (!res.ok) throw new Error(`GitHub releases query failed: ${res.status}`);
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
