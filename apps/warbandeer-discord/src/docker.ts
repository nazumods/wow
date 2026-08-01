// Minimal Docker Engine API client over the daemon socket.
//
// Bun's fetch speaks unix sockets natively (`fetch(url, { unix })`), so this needs no
// dependency — the host in the URL is ignored, the socket decides where it goes.
//
// Paths are deliberately unversioned (`/containers/…`, not `/v1.43/containers/…`): the daemon
// then answers with its own current version, so this doesn't break against an older or newer
// Docker than whichever one it was written on.

const SOCKET = "/var/run/docker.sock";
const BASE = "http://docker";

export interface ContainerInspect {
  Id: string;
  Name: string;
  Image: string;
  State: { Running: boolean; Status: string; ExitCode: number };
  Config: { Image: string; Env: string[]; Labels: Record<string, string>; User?: string };
  HostConfig: {
    Binds?: string[] | null;
    RestartPolicy?: { Name: string; MaximumRetryCount?: number };
    NetworkMode?: string;
    Init?: boolean | null;
  };
  Mounts: { Type: string; Name?: string; Source: string; Destination: string; RW: boolean }[];
  NetworkSettings: { Networks: Record<string, unknown> };
}

/** Body for `POST /containers/create` — only the fields this bot actually sets. */
export interface CreateContainerSpec {
  Image: string;
  Env: string[];
  Labels: Record<string, string>;
  /** Carried over from the original, so the replacement can still reach the daemon socket. */
  User?: string;
  HostConfig: {
    Binds: string[];
    RestartPolicy: { Name: string };
    NetworkMode?: string;
    Init?: boolean;
  };
}

async function api(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${BASE}${path}`, { ...init, unix: SOCKET });
}

async function ok(path: string, init: RequestInit = {}): Promise<Response> {
  const res = await api(path, init);
  if (!res.ok) {
    throw new Error(`docker ${init.method ?? "GET"} ${path} failed: ${res.status} ${await res.text()}`);
  }
  return res;
}

const json = (body: unknown): RequestInit => ({
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

/** Whether the daemon socket is actually reachable — the one precondition for self-update. */
export async function daemonReachable(): Promise<boolean> {
  try {
    return (await api("/_ping")).ok;
  } catch {
    return false;
  }
}

/**
 * This container's id, read out of its own mountinfo. Docker bind-mounts `/etc/hostname`,
 * `/etc/resolv.conf` and friends from `…/containers/<id>/…` on the host, so the id is spelled
 * out in the mount source even under cgroup v2 — where `/proc/self/cgroup` is just `0::/` and
 * tells you nothing.
 */
export function parseContainerId(mountinfo: string): string | undefined {
  const m = mountinfo.match(/\/(?:docker\/)?containers\/([0-9a-f]{64})\//);
  return m?.[1];
}

/**
 * Inspect the container this process is running in.
 *
 * Hostname first: Docker sets it to the short container id, and the daemon resolves a short id
 * fine — one request, no parsing. Mountinfo is the fallback for the case that breaks it, a
 * `hostname:` pinned in the compose file, where the name would resolve to nothing (or worse,
 * to some other container that happens to be called that).
 */
export async function inspectSelf(): Promise<ContainerInspect> {
  const host = process.env.HOSTNAME;
  if (host) {
    const res = await api(`/containers/${encodeURIComponent(host)}/json`);
    if (res.ok) return (await res.json()) as ContainerInspect;
  }
  const id = parseContainerId(await Bun.file("/proc/self/mountinfo").text());
  if (!id) throw new Error("cannot determine own container id (not running under Docker?)");
  return inspectContainer(id);
}

export async function inspectContainer(id: string): Promise<ContainerInspect> {
  return (await (await ok(`/containers/${encodeURIComponent(id)}/json`)).json()) as ContainerInspect;
}

/** `undefined` when the container is gone — a removal that already happened is not an error. */
export async function tryInspectContainer(id: string): Promise<ContainerInspect | undefined> {
  const res = await api(`/containers/${encodeURIComponent(id)}/json`);
  if (res.status === 404) return undefined;
  if (!res.ok) throw new Error(`docker inspect ${id} failed: ${res.status}`);
  return (await res.json()) as ContainerInspect;
}

/**
 * A build is a stream of JSONL progress objects that ends 200 whether or not it worked —
 * the failure is *inside* the body, as an `{"error": …}` line. Reading the status alone
 * would call every broken build a success.
 */
export function parseBuildOutput(body: string): { ok: boolean; error?: string } {
  for (const line of body.split("\n")) {
    if (!line.trim()) continue;
    let parsed: { error?: string; errorDetail?: { message?: string } };
    try {
      parsed = JSON.parse(line);
    } catch {
      continue; // a partial/non-JSON line is progress noise, not a verdict
    }
    const error = parsed.errorDetail?.message ?? parsed.error;
    if (error) return { ok: false, error };
  }
  return { ok: true };
}

/**
 * Build an image from a **remote** context: the daemon fetches the source itself, so the bot
 * image needs no git binary, no tar handling, and no scratch space of its own.
 * `remote` is a git URL of the form `https://host/owner/repo.git#ref:subdir`.
 */
export async function buildImage(o: {
  remote: string;
  tags: string[];
  buildArgs: Record<string, string>;
}): Promise<{ ok: boolean; error?: string }> {
  const params = new URLSearchParams({
    remote: o.remote,
    buildargs: JSON.stringify(o.buildArgs),
    // `remote` with a `#ref:subdir` fragment makes that subdir the context root, so the
    // Dockerfile path is relative to it — not to the repo root.
    dockerfile: "Dockerfile",
    forcerm: "1",
  });
  for (const t of o.tags) params.append("t", t);
  const res = await ok(`/build?${params}`, { method: "POST" });
  return parseBuildOutput(await res.text());
}

export async function createContainer(name: string, spec: CreateContainerSpec): Promise<string> {
  const params = new URLSearchParams({ name });
  const res = await ok(`/containers/create?${params}`, json(spec));
  return ((await res.json()) as { Id: string }).Id;
}

export async function startContainer(id: string): Promise<void> {
  await ok(`/containers/${encodeURIComponent(id)}/start`, { method: "POST" });
}

export async function stopContainer(id: string, timeoutSec = 10): Promise<void> {
  const params = new URLSearchParams({ t: String(timeoutSec) });
  const res = await api(`/containers/${encodeURIComponent(id)}/stop?${params}`, { method: "POST" });
  // 304 = already stopped, 404 = already gone. Both are the state we wanted.
  if (!res.ok && res.status !== 304 && res.status !== 404) {
    throw new Error(`docker stop ${id} failed: ${res.status} ${await res.text()}`);
  }
}

export async function removeContainer(id: string, force = false): Promise<void> {
  const params = new URLSearchParams(force ? { force: "1" } : {});
  const res = await api(`/containers/${encodeURIComponent(id)}?${params}`, { method: "DELETE" });
  if (!res.ok && res.status !== 404) {
    throw new Error(`docker rm ${id} failed: ${res.status} ${await res.text()}`);
  }
}

export async function renameContainer(id: string, name: string): Promise<void> {
  const params = new URLSearchParams({ name });
  await ok(`/containers/${encodeURIComponent(id)}/rename?${params}`, { method: "POST" });
}

export interface ImageSummary {
  Id: string;
  RepoTags: string[] | null;
  Created: number;
}

export async function listImages(): Promise<ImageSummary[]> {
  return (await (await ok("/images/json")).json()) as ImageSummary[];
}

/** Best-effort: an image still referenced by a container refuses to delete, which is correct. */
export async function removeImage(tag: string): Promise<void> {
  const res = await api(`/images/${encodeURIComponent(tag)}`, { method: "DELETE" });
  if (!res.ok) console.warn(`[redeploy] could not remove image ${tag}: ${res.status}`);
}
