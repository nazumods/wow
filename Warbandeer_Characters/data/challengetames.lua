---@type Warbandeer_Characters
local ns = select(2, ...)

-- Static "Challenge Tames" catalog: the curated list of rare / hard-to-tame "secret" Hunter pets
-- (Wowhead's Secret Hunter Pet Tames guide — spirit beasts, the Molten Front taming challenges, …),
-- cross-referenced against a Hunter's captured pet roster (data/pets.lua) into an owned/missing
-- checklist. A pet's NAME is user-renameable, so matching keys on the locale-independent ids the
-- stable API persists per pet:
--
--   * `creatureID` — the base creature; the primary match key. A single-appearance tame keys on this
--     alone (any recolor of that creature counts as owned).
--   * `displayID`  — recolor granularity. A catalog entry pins a `displayID` only for a specific
--     recolor within a family that shares one `creatureID` (Sabertron colours, Deth'tilac recolors);
--     then that exact display is required to count as owned.
--
-- Each entry also carries a short `note` (the zone, shown inline beside a missing entry) and a longer
-- `howTo` (the full obtain detail — spawn spot, the taming mechanic, and prerequisites — shown in the
-- row's hover tooltip). Spirit Beasts are EXOTIC (Beast Mastery spec only); the Mechanicals need the
-- Mecha-Bond Imprint Matrix (Goblin/Gnome/Mechagnome Hunters tame them innately); the Molten Front
-- tames require unlocking that zone via the Mount Hyjal "Firelands Invasion" questline.
--
-- These tames are aspirational (a Hunter is never "done" collecting them), so — like the Collected
-- view — they must NOT drive the `/wbc missing` report.
--
-- PROVENANCE / VERIFICATION: creatureIDs are sourced from Wowhead's Secret Hunter Pets guide / Petopia
-- (each pet's `npc=<id>`, whose npc id equals the stable `creatureID`) and spot-confirmed against real
-- rosters in-game via `/wbc dump tames` / `/wbc dump pets` (Arcturis 38453, Ghostcrawler 50051,
-- Anthriss 54338, Karkin 50959, Blue Juggernaut 107676 all matched owned pets). `howTo` + zone
-- corrections researched 2026-07-14 (Petopia + Warcraft Wiki): the four coloured Juggernauts are a
-- Siege of Orgrimmar craft-and-tame (not a Tanaan spawn); Sabertron is in Stormsong Valley (not
-- Ashran); Lightning Paw is an exotic Duskwood spirit-beast fox (moved out of Mechanical). The old
-- Iron Juggernaut (npc 71466) was dropped — it is the untameable raid boss; its tameable form is the
-- Grey Juggernaut craft below. `/wbc dump tames` remains the way to confirm/extend: a wrong id simply
-- reads "missing" until corrected (never a false owned). Fenryr keys on the tameable copy (npc 119990,
-- which spawns after the Halls of Valor encounter); the boss (95674) is NOT what a tamed pet reports.

---@class ChallengeTame
---@field label string       display name (the pet's proper name, e.g. "Loque'nahak")
---@field creatureID integer  base creature id — the primary match key (from stable PetInfo.creatureID)
---@field displayID integer?  a specific recolor's display id — required to count as owned when set
---@field category string     grouping label (e.g. "Spirit Beasts", "Molten Front")
---@field note string?        the zone, shown muted inline beside a missing entry
---@field howTo string?       full obtain detail (spawn spot, taming mechanic, prerequisites), shown in the row's hover tooltip

---@type ChallengeTame[]
ns.ChallengeTames = {
  -- Spirit Beasts — the marquee rare-spawn tames (WotLK → Legion). All EXOTIC (Beast Mastery only).
  { label = "Loque'nahak", creatureID = 32517, category = "Spirit Beasts", note = "Sholazar Basin",
    howTo = "Sholazar Basin roaming rare (7 spawn points, 6-10h respawn). Freeze-trap to tame. Exotic (Beast Mastery only)." },
  { label = "Gondria",     creatureID = 33776, category = "Spirit Beasts", note = "Zul'Drak",
    howTo = "Zul'Drak roaming rare (5 spawn points, 6-24h respawn). Freeze-trap to tame. Exotic (Beast Mastery only)." },
  { label = "Skoll",       creatureID = 35189, category = "Spirit Beasts", note = "The Storm Peaks",
    howTo = "The Storm Peaks roaming rare (Brunnhildar / Snowdrift Plains / Bor's Breath, 8-16h). Freeze-trap. Exotic (BM only)." },
  { label = "Arcturis",    creatureID = 38453, category = "Spirit Beasts", note = "Grizzly Hills",
    howTo = "Grizzly Hills rare north of Amberpine Lodge (about 32,56; 12-24h). Freeze-trap to tame. Exotic (Beast Mastery only)." },
  { label = "Ghostcrawler", creatureID = 50051, category = "Spirit Beasts", note = "Abyssal Depths",
    howTo = "Abyssal Depths (Vashj'ir): stealthed patrol along the Abandoned Reef, southwest. Exotic (Beast Mastery only)." },
  { label = "Ankha",       creatureID = 54318, category = "Spirit Beasts", note = "Mount Hyjal",
    howTo = "Sanctuary of Malorne, Mount Hyjal (needs the Molten Front questline). Strip armor to survive the tame. Exotic (BM only)." },
  { label = "Magria",      creatureID = 54319, category = "Spirit Beasts", note = "Mount Hyjal",
    howTo = "Sanctuary of Malorne, Mount Hyjal; shares Ankha's spawn (needs the questline). Strip armor to tame. Exotic (BM only)." },
  { label = "Ban'thalos",  creatureID = 54320, category = "Spirit Beasts", note = "Mount Hyjal",
    howTo = "Spirit owl above the Sanctuary of Malorne, Mount Hyjal (needs the questline). Tame mid-air via Slow Fall. Exotic (BM)." },
  { label = "Gara",        creatureID = 88708, category = "Spirit Beasts", note = "Shadowmoon Valley (Draenor)",
    howTo = "No spawn: a Draenor (Shadowmoon Valley) Void quest chain: Spirit Effigy, enter the Void realm, kill Xan, then tame. Exotic (BM)." },
  { label = "Fenryr",      creatureID = 119990, category = "Spirit Beasts", note = "Halls of Valor",
    howTo = "Solo Halls of Valor on Mythic: kill Hymdall then Fenryr, then tame the copy in his den. Exotic (Beast Mastery only)." },
  { label = "Lightning Paw", creatureID = 118244, category = "Spirit Beasts", note = "Duskwood",
    howTo = "Duskwood: stealthed exotic fox in glowing-eye bushes; reveal with Flare or Track Hidden. Exotic (Beast Mastery only)." },
  -- Molten Front (Firelands 4.2) — the classic taming challenges. All non-exotic (any spec); the zone
  -- is unlocked via the Mount Hyjal "Firelands Invasion" questline.
  { label = "Deth'tilac",  creatureID = 54322, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (Forlorn Spire). Elite: Molten Will blocks taming until ~20% HP; wear down, then fast-tame. Zone questline required." },
  { label = "Kirix",       creatureID = 54323, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (the Furnace). Green spider with a Toxic Presence AoE; cross the stepping stones into range. Zone questline required." },
  { label = "Solix",       creatureID = 54321, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (the Rune Cave). Blazing Speed makes it tame-immune; kite until it fades, then tame. Zone questline required." },
  { label = "Skitterflame", creatureID = 54324, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (Fireplume Peak, in lava). Ice/Frost Trap lowers its Superheated energy into a tame window. Zone questline required." },
  { label = "Anthriss",    creatureID = 54338, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (Magma Springs, NE corner). Stand in deep lava to melt its Searing Webs, then tame. Zone questline required." },
  { label = "Terrorpene",  creatureID = 50058, category = "Molten Front", note = "Mount Hyjal — fire tortoise",
    howTo = "Mount Hyjal, eastern rim of the Throne of Flame. Fire tortoise: Burning Hatred fire aura, immune to traps. Bring fire resistance." },
  { label = "Skarr",       creatureID = 50815, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (floating rocks by Fireplume Peak). Jump to a rock in range, interrupt its Fieroclast Barrage. Zone questline required." },
  { label = "Karkin",      creatureID = 50959, category = "Molten Front", note = "Molten Front",
    howTo = "Molten Front (floating rocks off E/SE Fireplume Peak). Jump into range, interrupt its Fieroclast fireballs (mind the fall)." },
  -- Mechanical tames — non-exotic, but need the Mecha-Bond Imprint Matrix (Goblin/Gnome/Mechagnome
  -- Hunters tame mechanicals innately). The coloured Juggernauts are a Siege of Orgrimmar craft-and-tame.
  { label = "Grey Juggernaut", creatureID = 107679, category = "Mechanical", note = "Siege of Orgrimmar",
    howTo = "Siege of Orgrimmar craft: Juggernaut Parts + Power Core + Grey Paint (Chamber of Paragons), then summon & tame. Needs Mecha-Bond." },
  { label = "Blue Juggernaut", creatureID = 107676, category = "Mechanical", note = "Siege of Orgrimmar",
    howTo = "Siege of Orgrimmar craft: Juggernaut Parts + Power Core + Blue Paint (Kor'kron Barracks), then summon & tame. Needs Mecha-Bond." },
  { label = "Green Juggernaut", creatureID = 107677, category = "Mechanical", note = "Siege of Orgrimmar",
    howTo = "Siege of Orgrimmar craft: Juggernaut Parts + Power Core + Green Paint (Cleft of Shadow), then summon & tame. Needs Mecha-Bond." },
  { label = "Teal Juggernaut", creatureID = 107678, category = "Mechanical", note = "Siege of Orgrimmar",
    howTo = "Siege of Orgrimmar craft: Juggernaut Parts + Power Core + Teal Paint (The Menagerie), then summon & tame. Needs Mecha-Bond." },
  { label = "Sabertron",   creatureID = 139328, category = "Mechanical", note = "Stormsong Valley",
    howTo = "Stormsong Valley: red in a cave NW of Seeker's Vista (kill the Sabertron Technician); others via the Sabertron WQ. Needs Mecha-Bond." },
}

-- Merge the catalog with a Hunter's owned-pet id sets into an owned/missing status list, preserving
-- catalog order. Pure — no WoW API — so it's unit-tested (spec/challengetames_spec.lua). An entry is
-- owned when its `creatureID` is in `ownedCreatures`, and — only when the entry pins a `displayID` —
-- when that exact display is also in `ownedDisplays[creatureID]` (so a recolor entry needs the right
-- colour, while a creatureID-only entry counts any recolor of that creature).
---@param list ChallengeTame[]?                            the challenge-tames catalog
---@param ownedCreatures table<integer, boolean>?          creatureIDs the Hunter has tamed
---@param ownedDisplays table<integer, table<integer, boolean>>?  displayIDs owned, nested by creatureID
---@return { label: string, creatureID: integer, displayID: integer?, category: string, note: string?, howTo: string?, owned: boolean }[]
function ns.MergeChallengeTames(list, ownedCreatures, ownedDisplays)
  local out = {}
  for _, e in ipairs(list or {}) do
    local owned = ownedCreatures ~= nil and ownedCreatures[e.creatureID] == true
    if owned and e.displayID then
      local displays = ownedDisplays and ownedDisplays[e.creatureID]
      owned = displays ~= nil and displays[e.displayID] == true
    end
    out[#out + 1] = {
      label = e.label,
      creatureID = e.creatureID,
      displayID = e.displayID,
      category = e.category,
      note = e.note,
      howTo = e.howTo,
      owned = owned,
    }
  end
  return out
end
