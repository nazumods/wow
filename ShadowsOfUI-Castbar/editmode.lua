---@type ShadowsOfUI_Castbar
local ns = select(2, ...)

-- Blizzard Edit Mode integration.
--
-- WoW's Edit Mode has no public registration API for third-party frames, so instead of
-- becoming a true Edit Mode "system" the bars piggy-back on it: while Edit Mode is open
-- each bar shows a static, labelled, draggable sample; closing Edit Mode returns them to
-- their normal cast-driven behaviour. EnterEditMode/ExitEditMode are hooked once at load.

-- Flip every bar into (or out of) placement mode.
---@param on boolean
function ns:SetConfigMode(on)
  if not self.bars then return end
  for _, bar in pairs(self.bars) do bar:SetConfig(on) end
end

-- Hook Edit Mode's enter/exit. Guarded so a client without EditModeManagerFrame (or a
-- renamed mixin) just leaves the bars in live mode rather than erroring.
function ns:WireEditMode()
  if not (EditModeManagerFrame and EditModeManagerFrame.EnterEditMode) then return end
  hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() ns:SetConfigMode(true) end)
  hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() ns:SetConfigMode(false) end)
  -- Sync if the addon somehow loaded while Edit Mode was already open.
  if EditModeManagerFrame.editModeActive then ns:SetConfigMode(true) end
end
