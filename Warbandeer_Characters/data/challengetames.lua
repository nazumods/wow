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
--     recolor within a family that shares one `creatureID` (Sabertron colours, Deth'tilac recolors,
--     Iron Juggernaut paints); then that exact display is required to count as owned.
--
-- These tames are aspirational (a Hunter is never "done" collecting them), so — like the Collected
-- view — they must NOT drive the `/wbc missing` report.
--
-- PROVENANCE / VERIFICATION: creatureIDs are sourced from Wowhead's Secret Hunter Pets guide — each
-- pet's `npc=<id>` link, whose npc id equals the stable `creatureID` — and spot-confirmed against real
-- rosters in-game via `/wbc dump tames` / `/wbc dump pets` (Arcturis 38453, Ghostcrawler 50051,
-- Anthriss 54338, Karkin 50959, Blue Juggernaut 107676 all matched owned pets). Note: the Iron
-- Juggernaut "paints" and the Molten Front spider "recolors" are DISTINCT creatureIDs (not displayID
-- variants of one creature), so every entry here keys on `creatureID` alone — the optional `displayID`
-- field stays for a future family that genuinely shares one creatureID. `/wbc dump tames` remains the
-- way to confirm/extend: a wrong id simply reads "missing" until corrected (never a false owned).

---@class ChallengeTame
---@field label string       display name (the pet's proper name, e.g. "Loque'nahak")
---@field creatureID integer  base creature id — the primary match key (from stable PetInfo.creatureID)
---@field displayID integer?  a specific recolor's display id — required to count as owned when set
---@field category string     grouping label (e.g. "Spirit Beasts", "Molten Front")
---@field note string?        where/how it's tamed (shown muted beside a missing entry)

---@type ChallengeTame[]
ns.ChallengeTames = {
  -- Spirit Beasts — the marquee rare-spawn tames (WotLK → Legion).
  { label = "Loque'nahak", creatureID = 32517, category = "Spirit Beasts", note = "Sholazar Basin" },
  { label = "Gondria",     creatureID = 33776, category = "Spirit Beasts", note = "Zul'Drak" },
  { label = "Skoll",       creatureID = 35189, category = "Spirit Beasts", note = "The Storm Peaks" },
  { label = "Arcturis",    creatureID = 38453, category = "Spirit Beasts", note = "Grizzly Hills" },
  { label = "Ghostcrawler", creatureID = 50051, category = "Spirit Beasts", note = "Abyssal Depths" },
  { label = "Ankha",       creatureID = 54318, category = "Spirit Beasts", note = "Mount Hyjal" },
  { label = "Magria",      creatureID = 54319, category = "Spirit Beasts", note = "Mount Hyjal" },
  { label = "Ban'thalos",  creatureID = 54320, category = "Spirit Beasts", note = "Mount Hyjal" },
  { label = "Fenryr",      creatureID = 95674, category = "Spirit Beasts", note = "Halls of Valor" },
  -- Molten Front (Firelands 4.2) — the classic taming challenges.
  { label = "Deth'tilac",  creatureID = 54322, category = "Molten Front", note = "Molten Front — elite challenge tame" },
  { label = "Kirix",       creatureID = 54323, category = "Molten Front", note = "Molten Front" },
  { label = "Solix",       creatureID = 54321, category = "Molten Front", note = "Molten Front" },
  { label = "Skitterflame", creatureID = 54324, category = "Molten Front", note = "Molten Front" },
  { label = "Anthriss",    creatureID = 54338, category = "Molten Front", note = "Molten Front" },
  { label = "Terrorpene",  creatureID = 50058, category = "Molten Front", note = "Mount Hyjal — fire tortoise" },
  { label = "Skarr",       creatureID = 50815, category = "Molten Front", note = "Molten Front" },
  { label = "Karkin",      creatureID = 50959, category = "Molten Front", note = "Molten Front" },
  -- Mechanical tames (Pandaria → Warlords) — the Juggernaut "paints" are distinct creatures, not recolors.
  { label = "Iron Juggernaut", creatureID = 71466,  category = "Mechanical", note = "Siege of Orgrimmar" },
  { label = "Grey Juggernaut", creatureID = 107679, category = "Mechanical", note = "Tanaan Jungle" },
  { label = "Blue Juggernaut", creatureID = 107676, category = "Mechanical", note = "Tanaan Jungle" },
  { label = "Green Juggernaut", creatureID = 107677, category = "Mechanical", note = "Tanaan Jungle" },
  { label = "Teal Juggernaut", creatureID = 107678, category = "Mechanical", note = "Tanaan Jungle" },
  { label = "Lightning Paw", creatureID = 118244, category = "Mechanical", note = "Draenor" },
  { label = "Sabertron",   creatureID = 139328, category = "Mechanical", note = "Ashran" },
}

-- Merge the catalog with a Hunter's owned-pet id sets into an owned/missing status list, preserving
-- catalog order. Pure — no WoW API — so it's unit-tested (spec/challengetames_spec.lua). An entry is
-- owned when its `creatureID` is in `ownedCreatures`, and — only when the entry pins a `displayID` —
-- when that exact display is also in `ownedDisplays[creatureID]` (so a recolor entry needs the right
-- colour, while a creatureID-only entry counts any recolor of that creature).
---@param list ChallengeTame[]?                            the challenge-tames catalog
---@param ownedCreatures table<integer, boolean>?          creatureIDs the Hunter has tamed
---@param ownedDisplays table<integer, table<integer, boolean>>?  displayIDs owned, nested by creatureID
---@return { label: string, creatureID: integer, displayID: integer?, category: string, note: string?, owned: boolean }[]
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
      owned = owned,
    }
  end
  return out
end
