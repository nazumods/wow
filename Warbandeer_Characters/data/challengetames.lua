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
-- PROVENANCE / VERIFICATION: the ids below are a seed of the well-known single-appearance tames from
-- the Wowhead guide. WoW's stable `creatureID` is locale-proof but its exact value (and every recolor
-- `displayID`) can only be confirmed against a real roster in-game — run `/wbc dump tames` on a Hunter
-- that owns some to verify a seed id, and `/wbc dump pets` to read the stored creature/display of an
-- owned recolor before adding its `displayID` entry. Expand the catalog from those dumps; a wrong seed
-- id simply reads "missing" until corrected (never a false owned).

---@class ChallengeTame
---@field label string       display name (the pet's proper name, e.g. "Loque'nahak")
---@field creatureID integer  base creature id — the primary match key (from stable PetInfo.creatureID)
---@field displayID integer?  a specific recolor's display id — required to count as owned when set
---@field category string     grouping label (e.g. "Spirit Beasts", "Molten Front")
---@field note string?        where/how it's tamed (shown muted beside a missing entry)

---@type ChallengeTame[]
ns.ChallengeTames = {
  -- Spirit Beasts — Wrath of the Lich King (single-appearance rare spawns).
  { label = "Loque'nahak", creatureID = 32517, category = "Spirit Beasts", note = "Sholazar Basin" },
  { label = "Gondria",     creatureID = 33776, category = "Spirit Beasts", note = "Zul'Drak" },
  { label = "Skoll",       creatureID = 35189, category = "Spirit Beasts", note = "The Storm Peaks" },
  { label = "Arcturis",    creatureID = 38453, category = "Spirit Beasts", note = "Grizzly Hills" },
  -- Spirit Beasts — Cataclysm.
  { label = "Ghostcrawler", creatureID = 46990, category = "Spirit Beasts", note = "Abyssal Depths" },
  { label = "Ban'thalos",   creatureID = 50063, category = "Spirit Beasts", note = "Mount Hyjal" },
  { label = "Ankha",        creatureID = 51107, category = "Spirit Beasts", note = "Mount Hyjal" },
  { label = "Magria",       creatureID = 51099, category = "Spirit Beasts", note = "Mount Hyjal" },
  -- Molten Front (Firelands) — the classic taming challenges.
  { label = "Deth'tilac",  creatureID = 50005, category = "Molten Front", note = "Molten Front — elite challenge tame" },
  { label = "Kirix",       creatureID = 50052, category = "Molten Front", note = "Molten Front" },
  { label = "Skitterflame", creatureID = 50054, category = "Molten Front", note = "Molten Front" },
  { label = "Anthriss",    creatureID = 50058, category = "Molten Front", note = "Molten Front" },
  { label = "Karkin",      creatureID = 50051, category = "Molten Front", note = "Molten Front" },
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
