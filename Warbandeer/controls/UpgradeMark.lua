---@type Warbandeer
local ns = select(2, ...)
-- luacheck: read globals ShadowsOfUI_UpgradeApi

-- Optional integration with ShadowsOfUI-Upgrade (OptionalDep).  When that addon
-- is loaded it publishes ShadowsOfUI_UpgradeApi; these helpers turn a slot's
-- available upgrade into a cell glyph + a hover line.  Everything degrades to
-- "no marker" when the addon is absent, so the views never hard-depend on it.

-- ▲ tinted green when the upgrade is held in the character's own bags/bank, gold
-- when the best copy is in the warband bank (your "better elsewhere" case).
local HELD_ARROW    = " |cff40c040\226\150\178|r"
local WARBAND_ARROW = " |cffe6cc80\226\150\178|r"

---Best available upgrade for a character's slot, or nil (also nil when the
---upgrade addon isn't loaded).
---@param charName string
---@param slot string
---@return UpgradeResult?
local function slotUpgrade(charName, slot)
  local api = ShadowsOfUI_UpgradeApi
  return api and api:SlotUpgrade(charName, slot) or nil
end

---Cell-text glyph for a slot's available upgrade, or "" when none.
---@param charName string
---@param slot string
---@return string
function ns.UpgradeMark(charName, slot)
  local r = slotUpgrade(charName, slot)
  if not r then return "" end
  return (r.where == "warband" or r.betterElsewhere) and WARBAND_ARROW or HELD_ARROW
end

---One-line hover description of a slot's available upgrade, or nil when none.
---@param charName string
---@param slot string
---@return string?
function ns.UpgradeTip(charName, slot)
  local r = slotUpgrade(charName, slot)
  if not r then return nil end
  local where = r.betterElsewhere and "better one in warband bank"
    or (r.where == "warband" and "in warband bank" or "held in bags/bank")
  local stat = r.statTag and (", " .. r.statTag .. " stats") or ""
  return ("Upgrade: +%d ilvl (%s%s)"):format(r.ilvlGain, where, stat)
end
