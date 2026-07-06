-- Loads ShadowsOfUI-Known/tooltip.lua against a minimal fake environment so the
-- pure ns.ReqSkill tooltip parser can be unit-tested. tooltip.lua's only load-time
-- side effects are two ns:OnItemTooltip registrations (stubbed) and reading the
-- ITEM_MIN_SKILL global (set here). Path is relative to the AddOns root.
local M = {}

-- `minSkill`: the ITEM_MIN_SKILL format string to load under. Omit for the default
-- "Requires %s (%d)"; pass `false` to load with ITEM_MIN_SKILL absent (fallback path).
---@return table ns
function M.load(minSkill)
  if minSkill == nil then minSkill = "Requires %s (%d)" end
  _G.ITEM_MIN_SKILL = minSkill or nil
  _G.NORMAL_FONT_COLOR = _G.NORMAL_FONT_COLOR or {}
  _G.C_TradeSkillUI = nil
  _G.SlashCmdList = _G.SlashCmdList or {}  -- tooltip.lua registers /sknown at load
  local ns = { OnItemTooltip = function() end }
  assert(loadfile("ShadowsOfUI-Known/tooltip.lua"))("ShadowsOfUI-Known", ns)
  return ns
end

return M
