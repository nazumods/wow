<script lang="ts">
  // Lists the WoW combat logs the addon writes (Warbandeer_Characters' opt-in
  // Logging toggle → Logs/WoWCombatLog.txt) and, on click, shows a lightweight
  // CLEU summary: line count, encounters seen, and top damage sources.
  import type { CombatLogFile, CombatLogSummary } from "../types";
  import { bytesText } from "../format";
  import { summarizeCombatLog } from "../api";

  interface Props {
    logs: CombatLogFile[];
  }
  let { logs }: Props = $props();

  let selected = $state<string | null>(null);
  let summary = $state<CombatLogSummary | null>(null);
  let loading = $state(false);
  let error = $state<string | null>(null);

  function fmtDate(secs: number): string {
    if (!secs) return "";
    return new Date(secs * 1000).toLocaleString();
  }

  async function open(path: string) {
    selected = path;
    summary = null;
    error = null;
    loading = true;
    try {
      summary = await summarizeCombatLog(path);
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }
</script>

<div class="panel">
  <div class="caps head">Combat Logs</div>
  {#if logs.length === 0}
    <div class="empty">
      No combat logs found. Enable logging in-game (Warbandeer → Logging) to start
      writing <code>Logs/WoWCombatLog.txt</code>.
    </div>
  {:else}
    <div class="layout">
      <ul class="list">
        {#each logs as log (log.path)}
          <li>
            <button
              class:active={selected === log.path}
              onclick={() => open(log.path)}
            >
              <span class="fname">{log.name}</span>
              <span class="meta num">{bytesText(log.sizeBytes)} · {fmtDate(log.modifiedSecs)}</span>
            </button>
          </li>
        {/each}
      </ul>
      <div class="detail">
        {#if loading}
          <div class="muted">Parsing…</div>
        {:else if error}
          <div class="err">{error}</div>
        {:else if summary}
          <div class="stat-line num">{summary.lines.toLocaleString()} lines</div>
          {#if summary.encounters.length}
            <div class="caps sub">Encounters</div>
            <div class="chips">
              {#each summary.encounters as e (e)}<span class="chip">{e}</span>{/each}
            </div>
          {/if}
          {#if summary.topDamage.length}
            <div class="caps sub">Top damage</div>
            <table class="dmg">
              <tbody>
                {#each summary.topDamage as d (d.name)}
                  <tr>
                    <td class="dname">{d.name}</td>
                    <td class="damt num">{d.amount.toLocaleString()}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {/if}
        {:else}
          <div class="muted">Select a log to summarize.</div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .panel {
    padding: 0 12px 16px;
  }
  .head {
    margin-bottom: 8px;
  }
  .layout {
    display: grid;
    grid-template-columns: minmax(240px, 1fr) 2fr;
    gap: 16px;
    align-items: start;
  }
  .list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .list button {
    width: 100%;
    text-align: left;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    padding: 6px 10px;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .list button:hover {
    background: var(--hover);
  }
  .list button.active {
    background: var(--selected);
    border-color: var(--gold);
  }
  .fname {
    font-size: 12px;
  }
  .meta {
    font-size: 10px;
    color: var(--faded);
  }
  .detail {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 12px;
    min-height: 120px;
  }
  .stat-line {
    font-size: 16px;
    font-weight: 600;
    margin-bottom: 8px;
  }
  .sub {
    font-size: 10px;
    margin: 10px 0 4px;
  }
  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }
  .chip {
    background: var(--surface-hi);
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 11px;
  }
  .dmg {
    width: 100%;
    border-collapse: collapse;
  }
  .dmg td {
    padding: 2px 4px;
    border-bottom: 1px solid var(--divider);
  }
  .dname {
    color: var(--text);
  }
  .damt {
    text-align: right;
    color: var(--orange);
  }
  .muted {
    color: var(--faded);
  }
  .err {
    color: var(--red);
    font-size: 12px;
  }
  .empty {
    color: var(--faded);
    font-size: 12px;
  }
  code {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--muted);
  }
</style>
