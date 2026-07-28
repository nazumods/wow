<script lang="ts">
  // Mirrors the third Overview column (views/overview/Achievements.lua): the per-expansion
  // checklist, completed rows in green and the rest muted, with the account's point total
  // above them.
  //
  // Rendered from the addon's persisted snapshot (db.achievements) joined against the bundled
  // catalog — the join happens in Rust, so this receives one payload rather than making an IPC
  // call per achievement.
  //
  // TEXT ONLY, deliberately (nazumods/wow#731). The bundle carries a bare icon NAME
  // ("achievement_bg_takexflags_ab"), not a path or a FileDataID, and this app has no icon
  // resolution at all yet — currencies have carried the same unused names since the bundle
  // landed. That is one shared capability rather than an achievements problem, so it is split
  // out; name, points and a completed marker are most of the in-game column's information.
  //
  // `wasEarnedByMe` is NOT shown. The addon documents it as last-captured-character-wins
  // rather than per-alt, so any per-character framing here would be a lie.
  import type { OverviewAchievements } from "../types";

  interface Props {
    achievements: OverviewAchievements;
  }
  let { achievements }: Props = $props();

  // Display labels for the catalog's expansion keys. Order comes from the backend, which
  // mirrors views/Overview.lua's EXPANSIONS; only the wording lives here.
  const LABELS: Record<string, string> = {
    midnight: "Midnight",
    wwi: "The War Within",
    dragonflight: "Dragonflight",
  };

  // The in-game view uses DIM_GREEN/DIM_RED. Muted is used for incomplete instead of red:
  // an unearned achievement is a to-do, not an error, and red reads as failure in this app's
  // palette where it is otherwise reserved for problems.
  const groups = $derived(achievements?.groups ?? []);
  const shown = $derived(groups.filter((g) => g.rows.length > 0));
</script>

<div class="achievements">
  {#if !achievements?.captured}
    <div class="empty">
      No achievement data captured yet — log in with Warbandeer_Characters installed.
    </div>
  {:else}
    <div class="total">
      <span class="caps">Points</span>
      <span class="num">{achievements.totalPoints.toLocaleString()}</span>
    </div>
    {#each shown as g (g.key)}
      <div class="group">
        <div class="grouphead">
          <span class="caps">{LABELS[g.key] ?? g.key}</span>
          <span class="tally num">{g.completedCount}/{g.rows.length}</span>
        </div>
        {#each g.rows as r (r.id)}
          <div class="row" class:done={r.completed}>
            <span class="name">{r.name ?? `#${r.id}`}</span>
            <span class="points num">{r.points}</span>
          </div>
        {/each}
      </div>
    {/each}
    {#if shown.length === 0}
      <div class="empty">The bundled catalog has no checklist for this build.</div>
    {/if}
  {/if}
</div>

<style>
  .achievements {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .total {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border);
  }
  .group {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .grouphead {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
    margin-bottom: 2px;
  }
  .tally {
    font-size: 11px;
    color: var(--faded);
    flex-shrink: 0;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
    color: var(--muted);
  }
  .row.done {
    color: var(--green);
  }
  .name {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .points {
    font-size: 11px;
    color: var(--faded);
    flex-shrink: 0;
  }
  .empty {
    color: var(--faded);
    font-size: 12px;
    padding: 8px 0;
  }
</style>
