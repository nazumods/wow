<script lang="ts">
  import type { Overview, CombatLogFile, OpsTargetInfo } from "./lib/types";
  import { getVersion } from "@tauri-apps/api/app";
  import { getOverview, listCombatLogs, opsConfig } from "./lib/api";
  import OverviewView from "./lib/components/Overview.svelte";
  import Currencies from "./lib/components/Currencies.svelte";
  import CombatLogPanel from "./lib/components/CombatLogPanel.svelte";
  import CharacterSort from "./lib/components/CharacterSort.svelte";
  import BotOps from "./lib/components/BotOps.svelte";

  let overview = $state<Overview | null>(null);
  let logs = $state<CombatLogFile[]>([]);
  let error = $state<string | null>(null);
  let loading = $state(true);
  let tab = $state<"overview" | "currencies" | "logs" | "sort" | "ops">("overview");

  // Operator-only Ops tab: shown only when ops mode is configured (ops.json present).
  // A broken or absent config resolves to null, keeping the tab hidden in normal builds.
  let ops = $state<OpsTargetInfo[] | null>(null);
  opsConfig()
    .then((c) => (ops = c))
    .catch(() => (ops = null));

  // App version, read from tauri.conf.json (the field the release pipeline bumps).
  let version = $state("");
  getVersion().then((v) => (version = v));

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
    {#if version}<span class="version">v{version}</span>{/if}
    {#if overview?.account}<span class="account">{overview.account}</span>{/if}
  </div>
  <nav class="tabs">
    <button class:active={tab === "overview"} onclick={() => (tab = "overview")}>
      Overview
    </button>
    <button class:active={tab === "currencies"} onclick={() => (tab = "currencies")}>
      Currencies
    </button>
    <button class:active={tab === "logs"} onclick={() => (tab = "logs")}>
      Logs{#if logs.length}<span class="badge">{logs.length}</span>{/if}
    </button>
    <button class:active={tab === "sort"} onclick={() => (tab = "sort")}> Sort </button>
    {#if ops && ops.length}
      <button class:active={tab === "ops"} onclick={() => (tab = "ops")}> Ops </button>
    {/if}
  </nav>
  <button class="refresh" onclick={load} title="Reload saved data">⟳</button>
</header>

<main>
  {#if tab === "ops" && ops && ops.length}
    <!-- Independent of the WoW-data load: ops mode must work even on a box with no install. -->
    <BotOps targets={ops} />
  {:else if loading}
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
    {:else if tab === "currencies"}
      <Currencies data={overview.currencies} />
    {:else if tab === "logs"}
      <CombatLogPanel {logs} />
    {:else if tab === "sort"}
      <CharacterSort />
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
  .version {
    color: var(--faded);
    font-family: var(--font-mono);
    font-size: 11px;
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
