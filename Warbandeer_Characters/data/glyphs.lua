---@type Warbandeer_Characters
local ns = select(2, ...)
local C_SpellBook = C_SpellBook
local C_Spell = C_Spell
local C_SpecializationInfo = C_SpecializationInfo
local GetFlyoutInfo, GetFlyoutSlotInfo = GetFlyoutInfo, GetFlyoutSlotInfo
local IsSpellKnown = IsSpellKnown
local PLAYER_BANK = Enum.SpellBookSpellBank.Player
local FLYOUT = Enum.SpellBookItemType.Flyout
local GetItemName = C_Item.GetItemNameByID
local IsAccountQuestDone = C_QuestLog.IsQuestFlaggedCompletedOnAccount

-- The `glyphs` broker records which cosmetic glyphs the character has *applied* to its
-- spells, keyed by spec id. Detection mirrors the community GlyphList addon: walk the
-- spellbook and for each known spell pull the glyph id embedded in its hyperlink
-- (…::<glyph>:…). We scan EVERY spec tab (grouped by the tab's spec) so a single scan can
-- capture all of a character's specs — but WoW only reliably surfaces the ACTIVE spec's
-- applied glyphs, so an inactive spec's tab may expose nothing until that spec is played.
-- The active spec therefore always gets a (possibly empty) entry — "scanned, none applied" is
-- distinguishable from "not yet discovered" — while an inactive spec is stored only once a
-- glyph is actually found there. Only the logged-in character is readable, so `applied` is a
-- last-seen per-spec snapshot. Account-wide barbershop unlocks (Marks / Grimoires) are NOT
-- stored here — the API reads them live from C_QuestLog (identical across the class).

-- Numeric id of the active specialization (nil before specs are chosen at low level).
local function currentSpecID()
  local idx = C_SpecializationInfo.GetSpecialization()
  if not idx then return nil end
  return (C_SpecializationInfo.GetSpecializationInfo(idx))
end

-- Extract a spell link's applied glyph id (…::<glyph>:…) into the spec's set. Unglyphed spells
-- parse to id 0 (the empty `::0` field) — skip them.
local function addGlyph(bySpec, spec, link)
  local glyph = link and tonumber(link:match("%b::(%d+)"))
  if glyph and glyph ~= 0 then
    bySpec[spec] = bySpec[spec] or {}
    bySpec[spec][glyph] = true
  end
end

-- Applied glyph ids across every spec tab, grouped by spec id. The active spec always gets an
-- entry (even empty); an inactive spec only when a glyph is found in its tab (so a spec WoW
-- won't surface stays "undiscovered", not falsely "none").
---@param activeSpecID integer
---@return table<integer, table<integer, boolean>>
local function scanAllSpecs(activeSpecID)
  local bySpec = { [activeSpecID] = {} }
  for i = 2, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
    if info then
      -- The general/class tab (offSpecID nil) reflects the active spec; a spec tab carries its
      -- own spec id.
      local spec = info.offSpecID or activeSpecID
      for j = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local itemType, actionID = C_SpellBook.GetSpellBookItemType(j, PLAYER_BANK)
        if itemType == FLYOUT then
          local _, _, numSpells = GetFlyoutInfo(actionID)
          for s = 1, (numSpells or 0) do
            local spellID = GetFlyoutSlotInfo(actionID, s)
            if spellID and IsSpellKnown(spellID) then
              addGlyph(bySpec, spec, C_Spell.GetSpellLink(spellID))
            end
          end
        elseif actionID and IsSpellKnown(actionID) then
          addGlyph(bySpec, spec, C_SpellBook.GetSpellBookItemLink(j, PLAYER_BANK))
        end
      end
    end
  end
  return bySpec
end

---@class Character
---@field glyphs GlyphsBroker?

---@class GlyphsBroker: Broker
---@field applied table<integer, table<integer, boolean>>?  applied glyph ids keyed by spec id
local Glyphs = ns:RegisterBroker("glyphs")

Glyphs.fields = {
  applied = {
    -- No missing report: applied glyphs are per-character × per-spec *loadout* state (not a
    -- collection flag), and WoW only surfaces the active spec's glyphs per login — so a "missing
    -- appearance glyphs" line would sit unresolved across most of the warband forever. Opt out
    -- explicitly (`false`, not nil) so the field still declares a stance for `missing audit`.
    missing = false,
    -- Merge-preserving: overwrite each spec the scan captured (always the active spec, plus any
    -- inactive spec that surfaced a glyph); specs the scan didn't touch keep their cached set.
    get = function(_, _, currentValue)
      local specID = currentSpecID()
      if not specID then return currentValue end
      local store = currentValue or {}
      for spec, set in pairs(scanAllSpecs(specID)) do store[spec] = set end
      return store
    end,
    event = { "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" },
    eventDelay = 1000,
  },
  -- Learned class unlocks (Druid "Tome of the Wilds", Hunter "Tomes & Tames") — items/skills that
  -- permanently grant an ability, so per-character (not per-spec). `{ [spell] = true }` for the ids
  -- the character has, via IsSpellKnown OR an innate racial grant (e.g. Goblin/Gnome hunters tame
  -- Mechanicals without the matrix); nil for a class with no unlocks. Last-seen (logged-in only).
  unlocks = {
    -- Flag a class that HAS learnable unlocks but has no captured `unlocks` set yet (needs a
    -- login); labelled by the class's unlock title (Druid "tome of the wilds", …).
    missing = { order = 120, check = function(toon)
      if ns.LearnedUnlocks[toon.classId] and not (toon.glyphs and toon.glyphs.unlocks) then
        return (ns.LearnedUnlockTitle[toon.classId] or "class unlocks"):lower()
      end
    end },
    get = function(_, toon)
      local list = ns.LearnedUnlocks[toon.classId]
      if not list then return nil end
      local known = {}
      for _, e in ipairs(list) do
        if C_SpellBook.IsSpellKnown(e.spell) or (e.races and e.races[toon.race]) then
          known[e.spell] = true
        end
      end
      return known
    end,
    event = "SPELLS_CHANGED",
    eventDelay = 1000,
  },
}

-- `/wbc dump glyphs` (+ `wdump glyphs`): the in-game verification probe. Prints each catalog
-- entry's stored label beside its live-resolved item name (a wrong item id shows a mismatch),
-- the live per-spec scan (so all-spec capture is verifiable), and the applied/unlocked state.
ns:registerDump("glyphs", "Appearance Glyphs",
  "Applied glyphs + account appearance unlocks for the current character's class",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    local classId = toon.classId
    local specID = currentSpecID()
    out:line(("Class %s (%d)  active spec %s"):format(toon.className or "?", classId, tostring(specID)))

    -- Live per-spec scan: exactly what the spellbook walk finds now (all spec tabs), independent
    -- of the cache — reveals whether a single scan captured inactive specs, and rules the
    -- scan/link-parse in or out as the culprit for an empty result.
    if specID then
      local bySpec = scanAllSpecs(specID)
      local specs = {}
      for sp in pairs(bySpec) do specs[#specs + 1] = sp end
      table.sort(specs)
      for _, sp in ipairs(specs) do
        local ids = {}
        for g in pairs(bySpec[sp]) do ids[#ids + 1] = g end
        table.sort(ids)
        out:line(("Live scan spec %d: %d glyph(s)%s"):format(sp, #ids,
          #ids > 0 and (" -> " .. table.concat(ids, ", ")) or ""))
      end
    end

    local glyphs = ns.AppearanceGlyphs[classId]
    if glyphs then
      local applied = (toon.glyphs and toon.glyphs.applied and specID and toon.glyphs.applied[specID]) or {}
      out:line(("Applied glyphs — active spec catalog (%d):"):format(#glyphs))
      for _, e in ipairs(glyphs) do
        out:line(("  %s  ->  %s%s"):format(e.label, GetItemName(e.itemID) or ("item:" .. e.itemID),
          applied[e.glyph] and "  <APPLIED>" or ""))
      end
    else
      out:line("No applied-glyph catalog for this class.")
    end

    local learned = ns.LearnedUnlocks[classId]
    if learned then
      local known = (toon.glyphs and toon.glyphs.unlocks) or {}
      out:line(("%s (%d):"):format(ns.LearnedUnlockTitle[classId] or "Learned unlocks", #learned))
      for _, e in ipairs(learned) do
        out:line(("  %s  ->  %s  [%s]%s"):format(e.label,
          GetItemName(e.itemID) or ("item:" .. e.itemID),
          C_Spell.GetSpellName(e.spell) or ("spell:" .. e.spell),
          known[e.spell] and "  <KNOWN>" or ""))
      end
    end

    local unlocks = ns.AppearanceUnlocks[classId]
    if unlocks then
      -- The account-wide snapshot (data/classcollectibles.lua) answers these same quest flags for a
      -- reader with no client, so the probe prints it beside live and flags any row where the two
      -- DISAGREE — the only interesting case, and the one thing a unit test can't check.
      local snap = ns.db.classCollectibles
      out:line(snap
        and ("Account appearance unlocks (%d)  [snapshot: %d quest(s), build %s, by %s]:"):format(
          #unlocks, snap.questCount or 0, snap.build or "?", snap.scannedBy or "?")
        or ("Account appearance unlocks (%d)  [snapshot: not scanned yet]:"):format(#unlocks))
      for _, e in ipairs(unlocks) do
        local live = IsAccountQuestDone(e.quest) == true
        local stored = snap and snap.quests[e.quest] == true
        out:line(("  %s  ->  %s%s%s"):format(e.label, GetItemName(e.itemID) or ("item:" .. e.itemID),
          live and "  <UNLOCKED>" or "",
          (snap and stored ~= live) and ("  <SNAPSHOT SAYS " .. tostring(stored) .. ">") or ""))
      end
    end
  end)
