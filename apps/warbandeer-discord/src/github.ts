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
