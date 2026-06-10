---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- Profession gear % (current expansion).  Per slot, score = rarity (1-5) +
-- crafted tier (1-3), max 8.  3 slots * 2 primaries = 48 points total.
-- Only items whose expacID matches the current expansion contribute; old
-- expac or empty slots score 0.
local MAX_RARITY = 5
local MAX_TIER   = 3
local PER_SLOT_MAX = MAX_RARITY + MAX_TIER

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

local function getProfGearScore(toon)
  if not (toon.basic and toon.basic.professions) then return "" end
  if not (toon.professions and toon.professions.gear) then return "" end
  local profs = toon.basic.professions
  local primaries = {}
  if profs.primary and profs.primary.skillID then insert(primaries, profs.primary.skillID) end
  if profs.secondary and profs.secondary.skillID then insert(primaries, profs.secondary.skillID) end
  if #primaries == 0 then return "" end

  local currentExpac = GetExpansionLevel() -- luacheck: globals GetExpansionLevel
  local score, maxScore = 0, 0
  local lines = {}

  for _, skillID in ipairs(primaries) do
    local profName = profNameBySkillID(skillID) or ("skill "..skillID)
    insert(lines, profName)
    local profGear = toon.professions.gear[skillID]
    local slotCount = 0
    if profGear and profGear.slots then
      for _, item in pairs(profGear.slots) do
        slotCount = slotCount + 1
        maxScore = maxScore + PER_SLOT_MAX
        local label = item.link or item.name or "item"
        if item.expacID == currentExpac then
          local r = clamp(item.rarity, 0, MAX_RARITY)
          local t = clamp(item.tier, 0, MAX_TIER)
          score = score + r + t
          local rc = RarityColors[r] or ""
          insert(lines, ("  %s %sR%d|r T%d   (%d/%d)"):format(label, rc, r, t, r + t, PER_SLOT_MAX))
        else
          insert(lines, "  "..label.." |cffff5555(old expac)|r")
        end
      end
    end
    -- Pad to 3 expected slots so missing equipment drags the score.
    for _ = slotCount + 1, 3 do
      maxScore = maxScore + PER_SLOT_MAX
      insert(lines, "  |cffff5555(empty slot)|r")
    end
  end

  if maxScore == 0 then return "" end
  local pct = math.floor((score / maxScore) * 100 + 0.5)
  local color
  if pct == 100 then color = {0, 1, 0, 1}
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
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\views\\profs.tga",
    iconColor = ns.theme.colors.muted,
    width = 36,
    justifyH = ui.justify.Right,
    tooltip = {
      "Profession Gear",
      "% of max profession-gear score across both primaries (current expansion)."
        .. " Per slot: rarity (1-5) + crafted tier (1-3) = 8 max. 3 slots x 2 primaries = 48 points.",
    },
    getData = getProfGearScore,
  }
)
