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
-- spells. Detection mirrors the community GlyphList addon: walk the class + active-spec
-- spellbook, and for each known spell pull the glyph id embedded in its hyperlink
-- (…::<glyph>:…). Only the logged-in character's spellbook is readable, and only for the
-- active spec, so `applied` is a last-seen per-spec snapshot (keyed by spec id). Account-
-- wide barbershop unlocks (Marks / Grimoires) are NOT stored here — they're read live from
-- C_QuestLog by the API, since they're identical across every character of the class.

-- Numeric id of the active specialization (nil before specs are chosen at low level).
local function currentSpecID()
  local idx = C_SpecializationInfo.GetSpecialization()
  if not idx then return nil end
  return (C_SpecializationInfo.GetSpecializationInfo(idx))
end

-- Set of glyph ids applied across the character's class + active-spec spellbook. A spell's
-- link carries its applied glyph as the `::<glyph>:` field; unglyphed spells have none.
---@param specID integer
---@return table<integer, boolean>
local function scanAppliedGlyphs(specID)
  local applied = {}
  for i = 2, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
    -- The class tab (offSpecID nil) and the active spec's tab only; skip other specs'.
    if info and (info.offSpecID == nil or info.offSpecID == specID) then
      for j = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local itemType, actionID = C_SpellBook.GetSpellBookItemType(j, PLAYER_BANK)
        if itemType == FLYOUT then
          local _, _, numSpells = GetFlyoutInfo(actionID)
          for s = 1, (numSpells or 0) do
            local spellID = GetFlyoutSlotInfo(actionID, s)
            if spellID and IsSpellKnown(spellID) then
              local link = C_Spell.GetSpellLink(spellID)
              local glyph = link and tonumber(link:match("%b::(%d+)"))
              if glyph then applied[glyph] = true end
            end
          end
        elseif actionID and IsSpellKnown(actionID) then
          local link = C_SpellBook.GetSpellBookItemLink(j, PLAYER_BANK)
          local glyph = link and tonumber(link:match("%b::(%d+)"))
          if glyph then applied[glyph] = true end
        end
      end
    end
  end
  return applied
end

---@class Character
---@field glyphs GlyphsBroker?

---@class GlyphsBroker: Broker
---@field applied table<integer, table<integer, boolean>>?  applied glyph ids keyed by spec id
local Glyphs = ns:RegisterBroker("glyphs")

Glyphs.fields = {
  applied = {
    -- Merge-preserving: only the active spec's set is rescanned; other specs' cached
    -- snapshots survive (a character can carry different glyphs per spec).
    get = function(_, _, currentValue)
      local specID = currentSpecID()
      if not specID then return currentValue end
      local store = currentValue or {}
      store[specID] = scanAppliedGlyphs(specID)
      return store
    end,
    event = { "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" },
    eventDelay = 1000,
  },
}

-- `/wbc dump glyphs` (+ `wdump glyphs`): the in-game verification probe. Prints each
-- catalog entry's stored label beside its live-resolved item name — a wrong item id shows
-- a mismatched (or missing) name — plus the applied/unlocked state for the current char.
ns:registerDump("glyphs", "Appearance Glyphs",
  "Applied glyphs + account appearance unlocks for the current character's class",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    local classId = toon.classId
    local specID = currentSpecID()
    out:line(("Class %s (%d)  spec %s"):format(toon.className or "?", classId, tostring(specID)))

    -- Live-scan diagnostic: exactly what the spellbook walk finds right now, independent of
    -- the cached broker value — an empty result here on a character with a glyph applied means
    -- the scan/link-parse is the problem, not the catalog mapping.
    if specID then
      local raw = scanAppliedGlyphs(specID)
      local ids = {}
      for g in pairs(raw) do ids[#ids + 1] = g end
      table.sort(ids)
      out:line(("Live spellbook scan: %d applied glyph id(s)%s"):format(#ids,
        #ids > 0 and (" -> " .. table.concat(ids, ", ")) or ""))
    end

    local glyphs = ns.AppearanceGlyphs[classId]
    if glyphs then
      local applied = (toon.glyphs and toon.glyphs.applied and specID and toon.glyphs.applied[specID]) or {}
      out:line(("Applied glyphs (%d):"):format(#glyphs))
      for _, e in ipairs(glyphs) do
        out:line(("  %s  ->  %s%s"):format(e.label, GetItemName(e.itemID) or ("item:" .. e.itemID),
          applied[e.glyph] and "  <APPLIED>" or ""))
      end
    else
      out:line("No applied-glyph catalog for this class.")
    end

    local unlocks = ns.AppearanceUnlocks[classId]
    if unlocks then
      out:line(("Account appearance unlocks (%d):"):format(#unlocks))
      for _, e in ipairs(unlocks) do
        out:line(("  %s  ->  %s%s"):format(e.label, GetItemName(e.itemID) or ("item:" .. e.itemID),
          IsAccountQuestDone(e.quest) and "  <UNLOCKED>" or ""))
      end
    end
  end)
