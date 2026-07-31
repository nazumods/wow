// Self-contained redeploy (#879): the bot builds its own replacement through the Docker
// daemon, starts it alongside, and lets it retire the original once it has verified itself.
//
// Everything here that talks to the daemon about the swap lives in this file; the protocol
// itself (marker, deadlines, outcome decision) is in `handoff.ts`, kept free of I/O so it
// can be tested as pure logic.

import { config } from "./config";
import {
  buildImage,
  createContainer,
  daemonReachable,
  inspectSelf,
  listImages,
  removeContainer,
  removeImage,
  renameContainer,
  startContainer,
  stopContainer,
  tryInspectContainer,
  type ContainerInspect,
  type CreateContainerSpec,
  type ImageSummary,
} from "./docker";
import {
  clearMarker,
  decideHandoffOutcome,
  HANDOFF_DEADLINE_MS,
  HANDOFF_FROM_ENV,
  readMarker,
  type HandoffOutcome,
} from "./handoff";
import { beginHandoff, endHandoff } from "./restart";

const BOT_PATH = "apps/warbandeer-discord";
const POLL_MS = 2_000;
/** Per-sha image tags kept around. More than one is what makes rolling back to a *previous*
 *  build possible at all; a small number is what stops that filling the box's disk. */
const KEEP_SHA_TAGS = 3;

/** Docker reports names with a leading slash. */
export function canonicalName(inspectedName: string): string {
  return inspectedName.replace(/^\//, "");
}

/**
 * The replacement can't be created under the canonical name — `container_name` in the compose
 * file pins it and the original still holds it — so it comes up beside it and takes the name
 * as it retires the original. Keeping the canonical name is what lets `bot-ops.sh` and the
 * desktop Ops panels, which filter on it, keep working across a swap with no change.
 */
export function replacementName(inspectedName: string): string {
  return `${canonicalName(inspectedName)}-next`;
}

/** A git URL the daemon can fetch a build context from, with the bot's own subdir as root. */
export function buildRemote(repo: string, branch: string): string {
  return `https://github.com/${repo}.git#${branch}:${BOT_PATH}`;
}

/** The compose-built image tag, plus a per-sha tag that keeps an older build addressable. */
export function imageTags(currentImage: string, sha: string): string[] {
  const repo = currentImage.split(":")[0] ?? currentImage;
  return [`${repo}:latest`, `${repo}:${sha.slice(0, 7)}`];
}

/**
 * Per-sha tags to drop, oldest first, once more than `keep` exist. Only ever selects tags of
 * this image's own repo that look like a short sha — `:latest` and anything hand-tagged are
 * never candidates, so a rollback target someone parked by name survives pruning.
 */
export function selectImagesToPrune(
  images: ImageSummary[],
  currentImage: string,
  keep = KEEP_SHA_TAGS,
): string[] {
  const repo = currentImage.split(":")[0] ?? currentImage;
  const tagged = images
    .flatMap((img) => (img.RepoTags ?? []).map((tag) => ({ tag, created: img.Created })))
    .filter(({ tag }) => new RegExp(`^${repo}:[0-9a-f]{7}$`).test(tag))
    .sort((a, b) => b.created - a.created);
  return tagged.slice(keep).map((t) => t.tag);
}

/**
 * The replacement's container spec, derived entirely from the original's own inspect — which
 * is what keeps this zero-config: the compose project, volumes, network and restart policy are
 * discovered, never configured.
 *
 * `GIT_SHA` is dropped from the copied env on purpose. `Config.Env` merges the image's baked-in
 * ENV with the container's own, so copying it verbatim would pin the *old* build's sha onto the
 * new container and override the new image's — leaving a correctly-updated bot convinced it was
 * still the old build, and reporting the update as a no-op.
 */
export function buildCreateSpec(
  self: ContainerInspect,
  o: { image: string; handoffFrom: string },
): CreateContainerSpec {
  const env = self.Config.Env.filter(
    (e) => !e.startsWith("GIT_SHA=") && !e.startsWith(`${HANDOFF_FROM_ENV}=`),
  );
  env.push(`${HANDOFF_FROM_ENV}=${o.handoffFrom}`);
  return {
    Image: o.image,
    Env: env,
    // Replicated verbatim so compose still recognises the container as its own service.
    Labels: { ...self.Config.Labels },
    // Without this the replacement falls back to the image's `USER bun` and cannot open the
    // daemon socket — so it would come up unable to retire anyone.
    User: self.Config.User,
    HostConfig: {
      // Derived from Mounts rather than HostConfig.Binds: compose may express a named volume
      // as either, and Mounts is the one that is always populated.
      Binds: self.Mounts.map(
        (m) => `${m.Name ?? m.Source}:${m.Destination}:${m.RW ? "rw" : "ro"}`,
      ),
      RestartPolicy: { Name: self.HostConfig.RestartPolicy?.Name || "unless-stopped" },
      NetworkMode: self.HostConfig.NetworkMode,
    },
  };
}

export interface RedeployResult {
  ok: boolean;
  outcome?: HandoffOutcome;
  error?: string;
}

/**
 * Build the target sha, start it alongside, and wait for it to verify.
 *
 * Returns only when the swap has *failed* — on success the replacement retires this process
 * partway through the wait, so the successful path never returns at all.
 */
export async function redeploy(latestSha: string): Promise<RedeployResult> {
  beginHandoff(`redeploy -> ${latestSha.slice(0, 7)}`);
  await clearMarker();

  let self: ContainerInspect;
  try {
    self = await inspectSelf();
  } catch (err) {
    endHandoff();
    return { ok: false, error: `could not inspect own container: ${(err as Error).message}` };
  }

  const tags = imageTags(self.Config.Image, latestSha);
  console.log(`[redeploy] building ${tags.join(", ")} from ${config.botBranch}`);
  const built = await buildImage({
    remote: buildRemote(config.githubRepo, config.botBranch),
    tags,
    buildArgs: { GIT_SHA: latestSha },
  }).catch((err) => ({ ok: false, error: (err as Error).message }));

  if (!built.ok) {
    // A failed build is inert: nothing has been created, so there is nothing to unwind.
    endHandoff();
    return { ok: false, error: `build failed: ${built.error ?? "unknown error"}` };
  }
  await pruneOldImages(self.Config.Image);

  const name = replacementName(self.Name);
  let replacementId: string;
  try {
    await removeContainer(name, true); // a leftover from an earlier failed attempt
    replacementId = await createContainer(name, buildCreateSpec(self, { image: tags[0]!, handoffFrom: self.Id }));
    await startContainer(replacementId);
  } catch (err) {
    endHandoff();
    return { ok: false, error: `could not start the replacement: ${(err as Error).message}` };
  }
  console.log(`[redeploy] replacement ${name} started — waiting for it to verify`);

  const outcome = await awaitHandoff(replacementId);
  if (outcome === "ready") {
    // It has verified and is retiring us; this process is about to be stopped mid-sentence.
    console.log("[redeploy] replacement verified — handing over");
    return { ok: true, outcome };
  }

  const marker = await readMarker();
  await removeContainer(replacementId, true);
  await clearMarker();
  endHandoff();
  console.warn(`[redeploy] handoff ${outcome} — staying on the current build`);
  return { ok: false, outcome, error: marker?.error };
}

/** Poll the marker and the replacement's own state until one of them decides it. */
async function awaitHandoff(replacementId: string): Promise<HandoffOutcome> {
  const startedAt = Date.now();
  for (;;) {
    const [marker, container] = await Promise.all([
      readMarker(),
      tryInspectContainer(replacementId),
    ]);
    const outcome = decideHandoffOutcome({
      marker,
      replacement: container && {
        running: container.State.Running,
        status: container.State.Status,
        exitCode: container.State.ExitCode,
      },
      elapsedMs: Date.now() - startedAt,
    });
    if (outcome !== "waiting") return outcome;
    await Bun.sleep(POLL_MS);
  }
}

async function pruneOldImages(currentImage: string): Promise<void> {
  try {
    for (const tag of selectImagesToPrune(await listImages(), currentImage)) {
      console.log(`[redeploy] pruning old image ${tag}`);
      await removeImage(tag);
    }
  } catch (err) {
    // Disk housekeeping is never worth failing a good deploy over.
    console.warn("[redeploy] image prune skipped:", (err as Error).message);
  }
}

/**
 * The replacement's side of the swap, run once it has verified itself: stop and remove the
 * original, then take its name.
 *
 * Removal, not just a stop — under `restart: unless-stopped` an exited container is brought
 * back on its old image, which is the original #868 failure and would now leave two bots
 * running. An explicit `docker stop` is exempt from that policy, and the `rm` makes it moot.
 */
export async function retireOriginal(originalId: string): Promise<void> {
  const original = await tryInspectContainer(originalId);
  await stopContainer(originalId);
  await removeContainer(originalId, true);
  console.log(`[handoff] retired the previous container ${originalId.slice(0, 12)}`);
  if (!original) return;

  const name = canonicalName(original.Name);
  const self = await inspectSelf();
  try {
    await renameContainer(self.Id, name);
    console.log(`[handoff] took the name ${name}`);
  } catch (err) {
    // Not fatal — the bot is up and serving. It just isn't where `bot-ops.sh` looks for it.
    console.warn(`[handoff] could not take the name ${name}: ${(err as Error).message}`);
  }
}

/** Whether a self-contained redeploy is possible at all: the daemon socket has to be mounted. */
export async function redeployAvailable(): Promise<boolean> {
  return daemonReachable();
}
