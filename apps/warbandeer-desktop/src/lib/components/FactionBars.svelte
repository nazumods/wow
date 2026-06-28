<script lang="ts">
  // Mirrors views/overview/FactionBars.lua + controls/LabeledBar.lua: a stack of
  // labeled progress bars. Offline we show the best standing per faction across the
  // whole warband (the closest equivalent to the in-game logged-in-char rep bars).
  import type { FactionStanding } from "../types";

  interface Props {
    factions: FactionStanding[];
  }
  let { factions }: Props = $props();

  function valueColor(f: FactionStanding): string {
    return f.done || f.paragon ? "var(--green)" : "var(--muted)";
  }
  function barColor(f: FactionStanding): string {
    return f.done ? "var(--green)" : f.paragon ? "var(--cyan)" : "var(--gold)";
  }
</script>

<div class="bars">
  {#each factions as f (f.name)}
    <div class="row">
      <div class="line">
        <span class="name">{f.name}</span>
        <span class="value num" style:color={valueColor(f)}>{f.label}</span>
      </div>
      <div class="track">
        <div
          class="fill"
          style:width={`${Math.round(Math.min(1, Math.max(0, f.pct)) * 100)}%`}
          style:background={barColor(f)}
        ></div>
      </div>
    </div>
  {/each}
  {#if factions.length === 0}
    <div class="empty">No reputation data scanned yet.</div>
  {/if}
</div>

<style>
  .bars {
    display: flex;
    flex-direction: column;
    gap: 7px;
  }
  .row {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .line {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
  }
  .name {
    color: var(--text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .value {
    font-size: 11px;
    flex-shrink: 0;
  }
  .track {
    height: 5px;
    border-radius: 3px;
    background: rgba(255, 255, 255, 0.08);
    overflow: hidden;
  }
  .fill {
    height: 100%;
    border-radius: 3px;
    transition: width 0.2s ease;
  }
  .empty {
    color: var(--faded);
    font-size: 12px;
    padding: 8px 0;
  }
</style>
