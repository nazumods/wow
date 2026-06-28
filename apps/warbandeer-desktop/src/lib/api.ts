import { invoke } from "@tauri-apps/api/core";
import type { Overview, CombatLogFile, CombatLogSummary } from "./types";

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
