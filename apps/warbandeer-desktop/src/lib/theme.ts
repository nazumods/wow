// Visual constants mirrored from Warbandeer's "void-dark" theme (theme.lua) and the
// in-game ilvl/class color tables, so the desktop view matches the addon 1:1.

// Standard WoW class colors keyed by classKey (the uppercase class file token).
export const CLASS_COLORS: Record<string, string> = {
  DEATHKNIGHT: "#C41E3A",
  DEMONHUNTER: "#A330C9",
  DRUID: "#FF7C0A",
  EVOKER: "#33937F",
  HUNTER: "#AAD372",
  MAGE: "#3FC7EB",
  MONK: "#00FF98",
  PALADIN: "#F48CBA",
  PRIEST: "#FFFFFF",
  ROGUE: "#FFF468",
  SHAMAN: "#0070DD",
  WARLOCK: "#8788EE",
  WARRIOR: "#C69B6D",
};

// The addon stores classKey in PascalCase ("DeathKnight"); normalize so any
// casing finds its color.
export function classColor(classKey: string | undefined): string {
  return (classKey && CLASS_COLORS[classKey.toUpperCase()]) || "#e6e2e1";
}

// Item-level tier thresholds + colors (data.lua: gearTiers + IlvlColorObj).
// Thresholds are by ilvl, not upgrade track, matching the addon.
const TIERS: { min: number; color: string }[] = [
  { min: 272, color: "#e6cc80" }, // mythic  (ITEM_ARTIFACT_COLOR, muted gold)
  { min: 259, color: "#ff8000" }, // hero    (legendary orange)
  { min: 246, color: "#a335ee" }, // champion(epic purple)
  { min: 233, color: "#0070dd" }, // veteran (superior blue)
  { min: 220, color: "#1eff00" }, // adventurer (good green)
  { min: 207, color: "#ffffff" }, // explorer (standard white)
];
const POOR = "#9d9d9d";

export function ilvlColor(ilvl: number): string {
  for (const t of TIERS) if (ilvl >= t.min) return t.color;
  return POOR;
}
