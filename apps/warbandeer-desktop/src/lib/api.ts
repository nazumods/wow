import { invoke } from "@tauri-apps/api/core";
import type {
  Overview,
  CombatLogFile,
  CombatLogSummary,
  CharacterOrderPayload,
  OrderLine,
  CurrencyMeta,
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

// ── Static game data (offline lookup layer) ────────────────────────────────
// Constant client data baked into the exe at build time from wago.tools, so the
// app can render currency names/icons that SavedVariables only store ids for.

/** Metadata for a currency id, or null if the bundle doesn't know it. */
export function getCurrencyMeta(id: number): Promise<CurrencyMeta | null> {
  return invoke("get_currency_meta", { id });
}

/** The client build the embedded bundle was generated from (diagnostics). */
export function staticDataBuild(): Promise<string> {
  return invoke("static_data_build");
}

// ── Bot ops (operator-only) ────────────────────────────────────────────────
// These shell out to the box's ops/bot-ops.sh over SSH. They live in the shared `@bot-ops`
// module (apps/bot-ops), which is maintained once and vendored into roshne/wow-companion —
// re-exported here so callers keep a single api.ts import. `opsConfig` returns null when ops
// mode isn't configured (the panel stays hidden then); otherwise it lists the managed bots, and
// every command takes the selected target's index so the panel can switch bots (debug/prod).

export {
  opsConfig,
  botStatus,
  botLogs,
  botRestart,
  botEnvGet,
  botEnvSet,
  changedFields,
  OPS_FIELDS,
} from "@bot-ops";
