<script lang="ts">
  import type { Overview, CombatLogFile } from "./lib/types";
  import { getOverview, listCombatLogs } from "./lib/api";
  import OverviewView from "./lib/components/Overview.svelte";
  import CombatLogPanel from "./lib/components/CombatLogPanel.svelte";

  let overview = $state<Overview | null>(null);
  let logs = $state<CombatLogFile[]>([]);
  let error = $state<string | null>(null);
  let loading = $state(true);
  let tab = $state<"overview" | "logs">("overview");

  async function load() {
    loading = true;
    error = null;
    try {
      const [ov, lg] = await Promise.all([getOverview(), listCombatLogs()]);
      overview = ov;
      logs = lg;
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }

  $effect(() => {
    load();
  });
</script>

<header class="titlebar">
  <div class="brand">
    <span class="mark">W</span>
    <span class="name">Warbandeer</span>
    {#if overview?.account}<span class="account">{overview.account}</span>{/if}
  </div>
  <nav class="tabs">
    <button class:active={tab === "overview"} onclick={() => (tab = "overview")}>
      Overview
    </button>
    <button class:active={tab === "logs"} onclick={() => (tab = "logs")}>
      Logs{#if logs.length}<span class="badge">{logs.length}</span>{/if}
    </button>
  </nav>
  <button class="refresh" onclick={load} title="Reload saved data">⟳</button>
</header>

<main>
  {#if loading}
    <div class="state">Loading saved data…</div>
  {:else if error}
    <div class="state err">
      <p>Couldn't read the WoW data.</p>
      <pre>{error}</pre>
      <button onclick={load}>Retry</button>
    </div>
  {:else if overview}
    {#if tab === "overview"}
      <OverviewView data={overview} />
    {:else}
      <CombatLogPanel {logs} />
    {/if}
  {/if}
</main>

<style>
  .titlebar {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 14px;
    border-bottom: 1px solid var(--divider);
    background: rgba(255, 255, 255, 0.02);
    position: sticky;
    top: 0;
    z-index: 10;
    backdrop-filter: blur(8px);
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .mark {
    display: inline-grid;
    place-items: center;
    width: 22px;
    height: 22px;
    border-radius: 5px;
    background: var(--gold);
    color: #000;
    font-family: var(--font-display);
    font-weight: 700;
    font-size: 14px;
  }
  .name {
    font-family: var(--font-display);
    font-weight: 600;
    font-size: 16px;
  }
  .account {
    color: var(--faded);
    font-size: 12px;
  }
  .tabs {
    display: flex;
    gap: 4px;
    margin-left: auto;
  }
  .tabs button {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    color: var(--muted);
    padding: 4px 12px;
    cursor: pointer;
    font-size: 13px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .tabs button:hover {
    background: var(--hover);
  }
  .tabs button.active {
    background: var(--surface-hi);
    color: var(--text);
  }
  .badge {
    background: var(--gold);
    color: #000;
    border-radius: 8px;
    font-size: 10px;
    padding: 0 5px;
    font-family: var(--font-mono);
  }
  .refresh {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--muted);
    width: 30px;
    height: 28px;
    cursor: pointer;
    font-size: 15px;
  }
  .refresh:hover {
    background: var(--hover);
    color: var(--text);
  }
  .state {
    padding: 40px;
    color: var(--faded);
    text-align: center;
  }
  .state.err {
    color: var(--red);
  }
  .state pre {
    text-align: left;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 12px;
    overflow: auto;
    white-space: pre-wrap;
    color: var(--muted);
    font-size: 12px;
  }
  .state button {
    margin-top: 12px;
    background: var(--surface-hi);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    padding: 6px 16px;
    cursor: pointer;
  }
</style>
