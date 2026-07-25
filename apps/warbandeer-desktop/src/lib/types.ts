// Shapes returned by the Rust backend (serde camelCase). Keep in sync with
// src-tauri/src/overview.rs and combatlog.rs.

export interface OverviewStats {
  wealthCopper: number;
  weeklyGoldMadeCopper: number;
  // Week-end wealth for up to the last 11 closed weeks (oldest first) plus the
  // current live wealth as the final point — a ≤12-point trend series.
  wealthHistoryCopper: number[];
  // Logged-in seconds per local calendar day ("YYYY-MM-DD"), summed across all
  // characters. Windowed into the activity grid on the frontend.
  playtimeByDay: Record<string, number>;
  totalPlaytimeSecs: number;
  patchPlaytimeSecs: number;
  charCount: number;
  topIlvl: number;
  currentPatch: string | null;
}

export interface FactionStanding {
  name: string;
  label: string; // exact standing text, e.g. "Renown 12" / "Exalted"
  pct: number; // 0..1 bar fill (1 when capped/paragon)
  done: boolean;
  paragon: boolean;
}

export interface TopCharacter {
  name: string;
  realm: string | null;
  classKey: string;
  classId: number;
  level: number;
  ilvl: number;
  isAlliance: boolean;
}

export interface Overview {
  account: string | null;
  dbVersion: number | null;
  stats: OverviewStats;
  reputations: FactionStanding[];
  topCharacters: TopCharacter[];
}

export interface CombatLogFile {
  name: string;
  path: string;
  sizeBytes: number;
  modifiedSecs: number; // unix seconds, 0 if unknown
}

export interface DamageRow {
  name: string;
  amount: number;
}

export interface CombatLogSummary {
  path: string;
  lines: number;
  encounters: string[];
  topDamage: DamageRow[];
}

export interface ResolvedCharacter {
  name: string;
  realm: string;
  realmGuid: string;
  classId: number;
  classKey: string; // class token as the addon stores it, e.g. "DeathKnight" — empty when unresolved
  className: string;
  level: number;
  spec: string; // current spec display name, e.g. "Frost"; "" when unknown
  itemLevel: number; // 0 when unknown
  profession1: string; // "" when untrained/unknown
  profession2: string;
  position: number;
  flag: string; // opaque, round-tripped verbatim
}

export interface CharacterOrderPayload {
  account: string;
  dbVersion: number | null;
  characters: ResolvedCharacter[];
  unresolvedCount: number;
}

/** What gets sent back to `saveCharacterOrder` (and read back from a remembered order) —
 * the exact fields the file format stores. `position` is written verbatim, letting the
 * caller deliberately skip a number to preserve a locked-empty-slot reservation. */
export interface OrderLine {
  flag: string;
  realmGuid: string;
  position: number;
}

// ── Bot ops panel ────────────────────────────────────────────────────────────
// Operator-only, gated: opsConfig() returns null unless an ops.json is present. The types and the
// commands both come from the shared `@bot-ops` module (apps/bot-ops) — re-exported here so the
// rest of the app keeps importing types from one place.
export type {
  OpsTargetInfo,
  BotStatus,
  EnvChange,
  EnvSetResult,
  OpsField,
} from "@bot-ops";

/** Mirrors `staticdata::CurrencyMeta` — constant client data, not character state. */
export interface CurrencyMeta {
  name: string;
  icon: string | null; // bare icon name ("inv_misc_coin_01"), null when DB2 has none
  maxQty: number; // 0 = uncapped
  quality: number;
}
