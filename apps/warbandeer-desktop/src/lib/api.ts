import { invoke } from "@tauri-apps/api/core";
import type {
  Overview,
  CombatLogFile,
  CombatLogSummary,
  CharacterOrderPayload,
  OrderLine,
  OpsConfig,
  BotStatus,
  EnvChange,
  EnvSetResult,
} from "./types";

// Thin wrappers over the Rust commands. `wowDir` is optional — the backend
// auto-detects the default install when it's null.
export function getOverview(wowDir?: string | null): Promise<Overview> {
  return invoke("get_overview", { wowDir: wowDir ?? null });
}

export function listCombatLogs(wowDir?: string | null): Promise<CombatLogFile[]> {
  return invoke("list_combat_logs", { wowDir: wowDir ?? null });
}

export function summarizeCombatLog(path: string): Promise<CombatLogSummary> {
  return invoke("summarize_combat_log", { path });
}

export function listOrderAccounts(wowDir?: string | null): Promise<string[]> {
  return invoke("list_order_accounts", { wowDir: wowDir ?? null });
}

export function getCharacterOrder(
  account: string,
  wowDir?: string | null,
): Promise<CharacterOrderPayload> {
  return invoke("get_character_order", { account, wowDir: wowDir ?? null });
}

/** Returns the timestamped backup path written before the new order was saved. */
export function saveCharacterOrder(
  account: string,
  ordered: OrderLine[],
  wowDir?: string | null,
): Promise<string> {
  return invoke("save_character_order", { account, ordered, wowDir: wowDir ?? null });
}

/** The user's remembered order for this account, or null if nothing's been remembered. */
export function getRememberedOrder(
  account: string,
  wowDir?: string | null,
): Promise<OrderLine[] | null> {
  return invoke("get_remembered_order", { account, wowDir: wowDir ?? null });
}

/** Persists `ordered` as the remembered order, replacing whatever was remembered before. */
export function rememberCharacterOrder(
  account: string,
  ordered: OrderLine[],
  wowDir?: string | null,
): Promise<void> {
  return invoke("remember_character_order", { account, ordered, wowDir: wowDir ?? null });
}

// ── Bot ops (operator-only) ────────────────────────────────────────────────
// All of these shell out to the box's ops/bot-ops.sh over SSH. `opsConfig`
// returns null when ops mode isn't configured — the panel stays hidden then.

export function opsConfig(): Promise<OpsConfig | null> {
  return invoke("ops_config");
}

export function botStatus(): Promise<BotStatus> {
  return invoke("bot_status");
}

/** Tail the container log (default 200, capped at 5000 by the backend). */
export function botLogs(lines?: number): Promise<string> {
  return invoke("bot_logs", { lines: lines ?? null });
}

/** Restart the bot process in place (no env reload). Returns the compose output. */
export function botRestart(): Promise<string> {
  return invoke("bot_restart");
}

/** Current values of the non-secret, editable env keys. */
export function botEnvGet(): Promise<Record<string, string>> {
  return invoke("bot_env_get");
}

/** Apply env changes and (if anything really changed) recreate the container to load them. */
export function botEnvSet(changes: EnvChange[]): Promise<EnvSetResult> {
  return invoke("bot_env_set", { changes });
}
