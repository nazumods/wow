<script lang="ts">
  // Operator-only panel: drives the Warbandeer debug bot on the box via the Rust ops
  // commands (which shell out to ops/bot-ops.sh over SSH). Shown only when ops mode is
  // configured — App resolves opsConfig() and passes the resulting cfg here.
  import type { OpsTargetInfo, BotStatus, EnvSetResult } from "../types";
  import { botStatus, botLogs, botRestart, botEnvGet, botEnvSet } from "../api";

  interface Props {
    targets: OpsTargetInfo[];
  }
  let { targets }: Props = $props();

  // Which bot the panel is acting on; the selector switches it (debug/prod).
  let selected = $state(0);

  // The non-secret keys the panel edits, in display order. Mirrors the whitelist in
  // ops/bot-ops.sh (the authority) — secrets are intentionally absent and can't be set here.
  const FIELDS: { key: string; label: string; hint: string }[] = [
    { key: "ANNOUNCE_CHANNEL_ID", label: "Announce channel", hint: "Channel ID: server up/down, reset, DMF" },
    { key: "RELEASE_ANNOUNCE_CHANNEL_ID", label: "Release channel", hint: "Channel ID for release posts (blank = same as announce)" },
    { key: "WATCHED_REPOS", label: "Watched repos", hint: "owner/repo,owner/repo — release announcements" },
    { key: "WOW_REALM", label: "Realm slug", hint: "Realm watched for up/down, e.g. eitrigg" },
    { key: "WOW_REGION", label: "Region", hint: "us or eu" },
    { key: "GUILD_ID", label: "Guild ID", hint: "Server for guild-scoped slash commands" },
    { key: "COMMAND_PREFIX", label: "Command prefix", hint: "Slash-command prefix, e.g. r → /rdmf" },
    { key: "ADMIN_USER_IDS", label: "Admin user IDs", hint: "Comma-separated user IDs allowed to /update" },
    { key: "REPORT_ROLE_ID", label: "Report role ID", hint: "Role allowed to use /report" },
    { key: "DMF_TIMEZONE", label: "DMF timezone", hint: "e.g. America/Los_Angeles" },
    { key: "BOT_BRANCH", label: "Bot branch", hint: "Branch self-update measures against" },
    { key: "AUTO_UPDATE", label: "Auto-update", hint: "true or false" },
  ];

  let status = $state<BotStatus | null>(null);
  let env = $state<Record<string, string>>({});
  let draft = $state<Record<string, string>>({});
  let logs = $state("");
  let logLines = $state(200);
  let busy = $state(false);
  let error = $state<string | null>(null);
  let notice = $state<string | null>(null);
  let confirming = $state<null | "restart" | "apply">(null);

  const changed = $derived(FIELDS.filter((f) => (draft[f.key] ?? "") !== (env[f.key] ?? "")));

  async function loadState(t = selected) {
    error = null;
    try {
      const [st, ev] = await Promise.all([botStatus(t), botEnvGet(t)]);
      status = st;
      env = ev;
      draft = { ...ev };
    } catch (e) {
      error = String(e);
    }
  }

  // Runs on mount and whenever the selected target changes: clear transient UI, then reload.
  $effect(() => {
    logs = "";
    notice = null;
    confirming = null;
    loadState(selected);
  });

  async function fetchLogs() {
    busy = true;
    error = null;
    try {
      logs = await botLogs(selected, logLines);
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }

  async function doRestart() {
    confirming = null;
    busy = true;
    error = null;
    notice = null;
    try {
      await botRestart(selected);
      notice = "Bot restarted.";
      await loadState();
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }

  async function doApply() {
    confirming = null;
    busy = true;
    error = null;
    notice = null;
    try {
      const res: EnvSetResult = await botEnvSet(
        selected,
        changed.map((f) => ({ key: f.key, value: draft[f.key] ?? "" })),
      );
      notice = res.recreated
        ? `Applied ${res.changed.join(", ")} — bot recreated. Backup: ${res.backup}`
        : (res.note ?? "No changes.");
      await loadState();
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
</script>

<div class="panel">
  <div class="statusbar">
    {#if targets.length > 1}
      <label class="target">
        Bot
        <select bind:value={selected}>
          {#each targets as t, i (t.name)}
            <option value={i}>{t.name}</option>
          {/each}
        </select>
      </label>
    {/if}
    <span class="dot" class:on={status?.running} class:off={status && !status.running}></span>
    <span class="stxt">{status ? status.status || (status.running ? "running" : "stopped") : "…"}</span>
    {#if status?.realmStatus}
      <span class="realm" class:down={status.realmStatus === "DOWN"}>realm {status.realmStatus}</span>
    {/if}
    <span class="host num">{targets[selected]?.ssh}</span>
    <div class="spacer"></div>
    <button class="btn" onclick={() => loadState()} disabled={busy} title="Reload status + env">⟳</button>
    <button class="btn danger" onclick={() => (confirming = "restart")} disabled={busy}>Restart</button>
  </div>

  {#if error}<div class="banner err">{error}</div>{/if}
  {#if notice}<div class="banner ok">{notice}</div>{/if}

  {#if confirming === "restart"}
    <div class="confirm">
      Restart the bot now? (process restart, no env change)
      <button class="btn danger" onclick={doRestart} disabled={busy}>Restart</button>
      <button class="btn" onclick={() => (confirming = null)}>Cancel</button>
    </div>
  {/if}

  <div class="caps head">Environment</div>
  <div class="fields">
    {#each FIELDS as f (f.key)}
      <label class="field" class:dirty={(draft[f.key] ?? "") !== (env[f.key] ?? "")}>
        <span class="fl">{f.label}</span>
        <input class="num" bind:value={draft[f.key]} placeholder={f.hint} spellcheck="false" />
        <span class="fh">{f.hint}</span>
      </label>
    {/each}
  </div>

  <div class="applybar">
    <span class="cnt">{changed.length} changed</span>
    <button
      class="btn primary"
      onclick={() => (confirming = "apply")}
      disabled={busy || changed.length === 0}
    >
      Apply &amp; recreate
    </button>
  </div>

  {#if confirming === "apply"}
    <div class="confirm">
      Apply {changed.length} change{changed.length === 1 ? "" : "s"} ({changed.map((f) => f.key).join(", ")})
      and recreate the bot to load them?
      <button class="btn primary" onclick={doApply} disabled={busy}>Apply</button>
      <button class="btn" onclick={() => (confirming = null)}>Cancel</button>
    </div>
  {/if}

  <div class="caps head logs-head">
    Logs
    <input class="lines num" type="number" min="1" max="5000" bind:value={logLines} />
    <button class="btn" onclick={fetchLogs} disabled={busy}>Fetch</button>
  </div>
  {#if logs}<pre class="logs num">{logs}</pre>{/if}
</div>

<style>
  .panel {
    padding: 0 12px 16px;
  }
  .statusbar {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 0;
  }
  .target {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--muted);
  }
  .target select {
    background: var(--window);
    border: 1px solid var(--border);
    border-radius: 5px;
    color: var(--text);
    padding: 2px 6px;
    font-size: 12px;
  }
  .dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: var(--track);
    flex: none;
  }
  .dot.on {
    background: var(--green);
  }
  .dot.off {
    background: var(--red);
  }
  .stxt {
    font-size: 13px;
  }
  .realm {
    font-size: 10px;
    font-family: var(--font-mono);
    color: var(--green);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 1px 6px;
  }
  .realm.down {
    color: var(--red);
  }
  .host {
    font-size: 11px;
    color: var(--faded);
  }
  .spacer {
    margin-left: auto;
  }
  .btn {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    padding: 4px 12px;
    cursor: pointer;
    font-size: 12px;
  }
  .btn:hover:not(:disabled) {
    background: var(--hover);
  }
  .btn:disabled {
    opacity: 0.5;
    cursor: default;
  }
  .btn.primary {
    background: var(--selected);
    border-color: var(--gold);
    color: var(--text);
  }
  .btn.danger {
    color: var(--red);
  }
  .banner {
    border-radius: 6px;
    padding: 8px 10px;
    font-size: 12px;
    margin: 6px 0;
  }
  .banner.err {
    color: var(--red);
    border: 1px solid var(--red);
  }
  .banner.ok {
    color: var(--green);
    border: 1px solid var(--border);
  }
  .confirm {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    background: var(--surface);
    border: 1px solid var(--gold);
    border-radius: 6px;
    padding: 8px 10px;
    font-size: 12px;
    margin: 6px 0;
  }
  .head {
    margin: 14px 0 8px;
  }
  .fields {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px 16px;
  }
  .field {
    display: grid;
    grid-template-columns: 130px 1fr;
    grid-template-rows: auto auto;
    align-items: center;
    column-gap: 8px;
    border-left: 2px solid transparent;
    padding-left: 8px;
  }
  .field.dirty {
    border-left-color: var(--gold);
  }
  .fl {
    font-size: 12px;
    color: var(--muted);
  }
  .field input {
    background: var(--window);
    border: 1px solid var(--border);
    border-radius: 5px;
    color: var(--text);
    padding: 4px 8px;
    font-size: 12px;
    width: 100%;
  }
  .field input:focus {
    outline: none;
    border-color: var(--gold);
  }
  .fh {
    grid-column: 2;
    font-size: 10px;
    color: var(--faded);
    margin-top: 2px;
  }
  .applybar {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 12px;
  }
  .cnt {
    font-size: 11px;
    color: var(--faded);
  }
  .logs-head {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .lines {
    width: 70px;
    background: var(--window);
    border: 1px solid var(--border);
    border-radius: 5px;
    color: var(--text);
    padding: 3px 6px;
    font-size: 12px;
  }
  .logs {
    background: var(--window);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 10px;
    font-size: 11px;
    line-height: 1.5;
    color: var(--muted);
    max-height: 340px;
    overflow: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }
</style>
