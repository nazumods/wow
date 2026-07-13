---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local strsplit = strsplit
local GetServerTime = GetServerTime
local date = date
local UnitExists = UnitExists
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitCreatureFamily = UnitCreatureFamily
local WARLOCK = 9 -- classId; the other "pet" class

---@class DemonRecord
---@field species string   localized creature family (Imp, Voidwalker, …) from UnitCreatureFamily
---@field name string      the demon's persistent name — last-seen (Lazjub, Jhomnuz, …)
---@field npcID integer?   npcID parsed from the pet GUID — a locale-proof dedup key + the panel icon lookup
---@field seenAt integer   server time this demon was last observed as the active pet

---@class DemonsData
---@field scannedAt integer   server time of the last demon capture (any demon)
---@field list DemonRecord[]  one record per demon family seen, last-seen, npcID-deduped

---@class Character
---@field demons DemonsData?

-- Warlocks are the other "pet" class, but unlike a Hunter's stable there is NO enumeration API — a
-- Warlock summons demons by spell rather than stabling collected ones, so the roster is only readable
-- from the currently-summoned demon. This is therefore a per-summon, last-seen cache: each demon (an
-- Imp named Lazjub, a Voidwalker named Jhomnuz, …) is captured while it's the active pet, filling in as
-- the Warlock summons Imp / Voidwalker / Felhunter / Sayaad / Felguard (Demonology). The species comes
-- straight from UnitCreatureFamily; the npcID (parsed from the pet GUID) is a locale-proof dedup key and
-- drives the panel's per-species icon. Names persist across summons (a Voidwalker read the same in two
-- zones), so the last-seen name is the demon's real name. Mirrors the Hunter scanner (data/pets.lua).

-- Pet/Creature GUID layout is "Pet-0-<server>-<instance>-<zone>-<npcID>-<spawn>", so the npcID is the
-- 6th dash-field (e.g. Pet-0-3131-0-35525-416-… → 416). nil for a GUID with no parseable id (the record
-- then dedups on species instead).
---@param guid string?
---@return integer? npcID
local function npcID(guid)
  if not guid then return nil end
  local id = select(6, strsplit("-", guid))
  return id and tonumber(id) or nil
end

local function scan()
  local toon = ns.currentData
  if not toon or toon.classId ~= WARLOCK then return end
  if not UnitExists("pet") then return end
  local species = UnitCreatureFamily("pet")
  if not species then return end  -- a pet with no creature family isn't a demon we can key on
  local id = npcID(UnitGUID("pet"))
  local now = GetServerTime()
  toon.demons = toon.demons or { scannedAt = 0, list = {} }
  local list = toon.demons.list
  -- Dedup by npcID (locale-proof), falling back to species when the GUID had no parseable npcID; a
  -- re-summon of a known demon updates its record in place, so the last-seen name wins and the list
  -- keeps first-seen order.
  local rec
  for _, d in ipairs(list) do
    if (id and d.npcID == id) or (not id and d.species == species) then rec = d; break end
  end
  if not rec then rec = {}; insert(list, rec) end
  rec.species, rec.name, rec.npcID, rec.seenAt = species, UnitName("pet"), id, now
  toon.demons.scannedAt = now
end

-- UNIT_PET fires (with a unit arg) when a unit's pet changes — on summon, on a demon swap, and when
-- the demon re-materialises on login / zone-in. Only the player's own pet matters. Cheap enough to run
-- per event (a Warlock has at most a handful of demon families) — no debounce, mirroring data/pets.lua.
ns:registerEvent("UNIT_PET", function(_, unit)
  if unit == "player" then scan() end
end)

-- `/wbc dump demons` (+ `wdump demons`): verify the captured roster + the locale-proof npcIDs the
-- panel's per-species icon keys off. The list is tiny (one row per demon family), so chat is fine —
-- no toWindow.
ns:registerDump("demons", "Warlock Demons",
  "Summoned demons (name + species) for the current Warlock — fills in as you summon each",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    if toon.classId ~= WARLOCK then out:line("Not a Warlock."); return end
    local demons = toon.demons
    if not demons or #demons.list == 0 then
      out:line("No demons seen — summon your demons to capture them."); return
    end
    out:line("Scanned " .. date("%Y-%m-%d %H:%M", demons.scannedAt))
    out:line(("Demons (%d):"):format(#demons.list))
    for _, d in ipairs(demons.list) do
      out:line(("  %s — %s  [npc %s]"):format(d.name, d.species, tostring(d.npcID or "?")))
    end
  end)
