// Shapes returned by the Rust backend (serde camelCase). Keep in sync with
// src-tauri/src/overview.rs and combatlog.rs.

export interface OverviewStats {
  wealthCopper: number;
  weeklyGoldMadeCopper: number;
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
  classKey: string; // uppercase class token, e.g. "MAGE" — empty when unresolved
  className: string;
  level: number;
  role: string; // "Tank" | "Healer" | "DPS" | "?"
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

/** What gets sent back to `saveCharacterOrder` — just the two fields the file format
 * stores; position is recomputed from array order on write. */
export interface OrderLine {
  flag: string;
  realmGuid: string;
}
