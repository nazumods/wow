---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local insert = table.insert

-- Profession gear % (current expansion).  Per slot, score = rarity + crafted
-- tier against a baseline of rare at max tier (R3+T5 = 8); 3 slots * 2
-- primaries = 48 points = 100%.  Epic gear is hard to source and expensive
-- with no skill bonus, so it isn't required for 100% — it overshoots instead
-- (>100%, shown muted gold).  Only items whose expacID matches the current
-- expansion contribute; old expac or empty slots score 0.
local BASE_RARITY = 3 -- rare (blue)
local MAX_TIER    = 5
local PER_SLOT_MAX = BASE_RARITY + MAX_TIER

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

-- ─── Warband craft hints ─────────────────────────────────────────────────────
-- "X can upgrade this." / "X can craft a better version." lines under each
-- tooltip item.  Recipe → prof-gear resolution comes from the account-wide
-- cache behind ns.api:ResolveRecipeOutput; the crafters half (who knows it,
-- skill, intent flag) is volatile, so it's rebuilt per session on first hover.

local RECIPE_EXP_KEY = "midnight" -- recipe bucket to scan (matches CraftingView)

local craftable       -- [itemID] = { rarity, equipLoc, crafters = {{name, skill, isMain}} }
local craftableByProf -- [skillLineID the gear is for] = entry[]
local craftableDirty  -- some output items weren't in the item cache; rebuild next hover

local function buildCraftable()
  craftable, craftableByProf, craftableDirty = {}, {}, false
  for _, toon in ipairs(ns.api:GetAllCharacters()) do
    local details = toon.professions and toon.professions.details
    for craftSkillID, det in pairs(details or {}) do
      local bucket = det.recipes and det.recipes[RECIPE_EXP_KEY]
      for _, recipe in ipairs(bucket and bucket.learned or {}) do
        local out = ns.api:ResolveRecipeOutput(recipe.id)
        if out == nil then craftableDirty = true end
        if out then
          local entry = craftable[out.itemID]
          if not entry then
            entry = { rarity = out.rarity, equipLoc = out.equipLoc, crafters = {} }
            craftable[out.itemID] = entry
            craftableByProf[out.skillID] = craftableByProf[out.skillID] or {}
            insert(craftableByProf[out.skillID], entry)
          end
          local known = false
          for _, c in ipairs(entry.crafters) do
            if c.name == toon.name then known = true break end
          end
          if not known then
            local prof = ns.data.FindProf(toon, craftSkillID)
            insert(entry.crafters, {
              name   = toon.name,
              skill  = prof and prof.skillLevel or 0,
              isMain = ns.data.GetProfIntent(toon.name, craftSkillID) == "main",
            })
          end
        end
      end
    end
  end
end

-- The toon flagged "main" for the crafting profession, else the highest skill.
local function bestCrafter(entry)
  local best
  for _, c in ipairs(entry.crafters) do
    if not best
      or (c.isMain and not best.isMain)
      or (c.isMain == best.isMain and c.skill > best.skill) then
      best = c
    end
  end
  return best
end

-- Hint line for a worn item, or nil.  A higher-rarity craftable for the same
-- slot type wins over recrafting the worn item to a higher quality tier (we
-- only know the recipe is learned, not the quality the crafter would reach).
-- Suggestions stop at the rare baseline — epic isn't part of the 100% goal,
-- so it's never pushed on a character already wearing rare.
-- Old-expansion items treat any current-expansion craftable as better.
local function craftHint(skillID, item, isCurrentExpac)
  if not craftable or craftableDirty then buildCraftable() end
  local itemID = item.link and tonumber(item.link:match("item:(%d+)"))
  if not itemID then return nil end
  local equipLoc = select(4, C_Item.GetItemInfoInstant(itemID))
  local wornRarity = isCurrentExpac and (item.rarity or 0) or 0
  local better
  for _, entry in ipairs(craftableByProf[skillID] or {}) do
    if entry.equipLoc == equipLoc and entry.rarity > wornRarity
      and entry.rarity <= BASE_RARITY
      and (not better or entry.rarity > better.rarity) then
      better = entry
    end
  end
  if better then
    local c = bestCrafter(better)
    if c then return ("    |cffaaaaaa%s can craft a better version.|r"):format(c.name) end
  end
  local own = craftable[itemID]
  if own and item.tier and item.tier < MAX_TIER then
    local c = bestCrafter(own)
    if c then return ("    |cffaaaaaa%s can upgrade this.|r"):format(c.name) end
  end
  return nil
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
  local hints = {} -- [line index] = {skillID, item, isCurrentExpac}; resolved on hover

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
          -- Rarity is NOT capped at the baseline: epic+ overshoots on purpose.
          local r = clamp(item.rarity, 0, 5)
          local t = clamp(item.tier, 0, MAX_TIER)
          score = score + r + t
          local rc = RarityColors[r] or ""
          insert(lines, ("  %s %sR%d|r T%d   (%d/%d)"):format(label, rc, r, t, r + t, PER_SLOT_MAX))
          hints[#lines] = {skillID, item, true}
        else
          insert(lines, "  "..label.." |cffff5555(old expac)|r")
          hints[#lines] = {skillID, item, false}
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
        if h then
          local hint = craftHint(h[1], h[2], h[3])
          if hint then ui.tip:AddLine(hint) end
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
