---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert, fmt = table.insert, string.format

-- The craft-hint machinery (index of who-can-craft-what + the per-item / empty-slot
-- hint lines) lives in summaryCol/profsCraft.lua, loaded first, on ns.profsCol.
local PC = ns.profsCol
local familyKey, craftHint, emptyHints = PC.familyKey, PC.craftHint, PC.emptyHints

-- Profession gear % (current expansion).  Per slot, score = rarity + crafted
-- tier against a baseline of rare at max tier (R3+T5 = 8); 3 slots * 2
-- primaries = 48 points = 100%.  Epic gear is hard to source and expensive
-- with no skill bonus, so it isn't required for 100% — it overshoots instead
-- (>100%, shown muted gold).  Only items whose expacID matches the current
-- expansion contribute; old expac or empty slots score 0.
local BASE_RARITY = 3 -- rare (blue)
local MAX_TIER    = 5
local PER_SLOT_MAX = BASE_RARITY + MAX_TIER

-- Every profession's gear is one tool + two accessories.  These are the item
-- equipLocs that distinguish them, so an empty slot can be labelled and its
-- hints filtered to the matching craftables / bank spares.
local TOOL_LOC = "INVTYPE_PROFESSION_TOOL"
local GEAR_LOC = "INVTYPE_PROFESSION_GEAR"

local profInfoBySkill = nil
local function profNameBySkillID(skillID)
  if not profInfoBySkill then
    profInfoBySkill = {}
    for _, info in pairs(ns.api.professionInfo or {}) do
      if info.skillLineID then profInfoBySkill[info.skillLineID] = info.name end
    end
  end
  return profInfoBySkill[skillID]
end

-- Item rarity tint for the rarity number in the tooltip.
local RarityColors = {
  [5] = "|cffff8000", -- legendary
  [4] = "|cffa335ee", -- epic
  [3] = "|cff0070dd", -- rare
  [2] = "|cff1eff00", -- uncommon
  [1] = "|cffffffff", -- common
}

local function clamp(v, lo, hi)
  if not v then return 0 end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- The equipLoc of a stored gear item (tool vs accessory), or nil if its link
-- isn't resolvable yet.  Used to tell which slot types are already filled.
-- Prefers the scan-time capture; the live lookup is the fallback for entries
-- cached before that field existed.
local function equipLocOf(item)
  if item.equipLoc then return item.equipLoc end
  local itemID = item.link and tonumber(item.link:match("item:(%d+)"))
  if not itemID then return nil end
  return select(4, C_Item.GetItemInfoInstant(itemID))
end

local function getProfGearScore(toon)
  if not (toon.basic and toon.basic.professions) then return "" end
  if not (toon.professions and toon.professions.gear) then return "" end
  local profs = toon.basic.professions
  local primaries = {}
  if profs.primary and profs.primary.skillID then insert(primaries, profs.primary.skillID) end
  if profs.secondary and profs.secondary.skillID then insert(primaries, profs.secondary.skillID) end
  if #primaries == 0 then return "" end

  local currentExpac = GetExpansionLevel()
  local score, maxScore = 0, 0
  local lines = {}
  local hints = {} -- [line index] = {skillID, item, isCurrentExpac}; resolved on hover

  for _, skillID in ipairs(primaries) do
    local profName = profNameBySkillID(skillID) or ("skill "..skillID)
    insert(lines, profName)
    local profGear = toon.professions.gear[skillID]
    local filledTool, filledAcc = 0, 0
    local wornAcc = {} -- accessory gear-line families already worn (for empty-slot hints)
    if profGear and profGear.slots then
      for _, item in pairs(profGear.slots) do
        maxScore = maxScore + PER_SLOT_MAX
        local label = item.link or item.name or "item"
        if item.expacID == currentExpac then
          -- Rarity is NOT capped at the baseline: epic+ overshoots on purpose.
          local r = clamp(item.rarity, 0, 5)
          local t = clamp(item.tier, 0, MAX_TIER)
          score = score + r + t
          local rc = RarityColors[r] or ""
          insert(lines, fmt("  %s %sR%d|r T%d   (%d/%d)", label, rc, r, t, r + t, PER_SLOT_MAX))
          hints[#lines] = {skillID, item, true}
        else
          insert(lines, "  "..label.." |cffff5555(old expac)|r")
          hints[#lines] = {skillID, item, false}
        end
        if equipLocOf(item) == TOOL_LOC then
          filledTool = filledTool + 1
        else
          filledAcc = filledAcc + 1
          local fam = familyKey(item.link and tonumber(item.link:match("item:(%d+)")), item.name)
          if fam then wornAcc[fam] = true end
        end
      end
    end
    -- A profession's loadout is 1 tool + 2 accessories; the empty slots are
    -- whatever isn't filled.  Naming the missing type (and padding maxScore so it
    -- drags the score) lets each empty line's hints target that exact slot — and
    -- the accessory hint steers toward a line you aren't already wearing.
    for _ = filledTool + 1, 1 do
      maxScore = maxScore + PER_SLOT_MAX
      insert(lines, "  |cffff5555(empty tool slot)|r")
      hints[#lines] = {empty = true, skillID = skillID, equipLoc = TOOL_LOC}
    end
    for _ = filledAcc + 1, 2 do
      maxScore = maxScore + PER_SLOT_MAX
      insert(lines, "  |cffff5555(empty accessory slot)|r")
      hints[#lines] = {empty = true, skillID = skillID, equipLoc = GEAR_LOC, wornFamilies = wornAcc}
    end
  end

  if maxScore == 0 then return "" end
  local pct = math.floor((score / maxScore) * 100 + 0.5)
  local color
  if pct > 100 then color = {0.902, 0.8, 0.502, 1} -- muted gold (#e6cc80): epic overshoot
  elseif pct == 100 then color = {0, 1, 0, 1}
  elseif pct >= 80 then color = {1, 1, 1, 1}
  elseif pct >= 50 then color = {1, 0.82, 0, 1}
  else color = {1, 0.4, 0.4, 1} end

  return {
    text = pct.."%",
    justifyH = ui.justify.Right,
    color = color,
    onEnter = function(self)
      ns.AnchorTip(self)
      ui.tip:ClearLines()
      ui.tip:AddLine(score.." / "..maxScore.." points")
      for i, l in ipairs(lines) do
        ui.tip:AddLine(l)
        local h = hints[i]
        if h and h.empty then
          for _, hl in ipairs(emptyHints(h.skillID, h.equipLoc, h.wornFamilies)) do ui.tip:AddLine(hl) end
        elseif h then
          for _, hl in ipairs(craftHint(h[1], h[2], h[3])) do ui.tip:AddLine(hl) end
        end
      end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "profs", label = "Professions",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\views\\profs.tga",
    iconColor = ns.theme.colors.muted,
    width = 36,
    justifyH = ui.justify.Right,
    tooltip = {
      "Profession Gear",
      "% of profession-gear score across both primaries (current expansion)."
        .. " Per slot: rarity + crafted tier vs a rare tier-5 baseline (3+5 = 8)."
        .. " 3 slots x 2 primaries = 48 points. Epic gear overshoots past 100% (gold).",
    },
    getData = getProfGearScore,
  }
)
