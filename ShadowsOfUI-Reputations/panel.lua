---@type ShadowsOfUI_Reputations
local ns = select(2, ...)

-- The character pane's Reputation tab builds each faction row's tooltip in
-- ReputationEntryMixin:OnEnter (GameTooltip owned by the row). Post-hook it to append our
-- cross-alt standings, then re-Show so the tooltip resizes around the added lines.
local function onRepEnter(self)
  local fid = self.elementData and self.elementData.factionID
  if not fid then return end
  if ns.AppendStandings(GameTooltip, fid) then GameTooltip:Show() end
end

-- ReputationEntryMixin lives in Blizzard base UI (loaded at startup), but guard + expose an
-- installer so core.lua's onLogin can retry if the mixin isn't defined yet at file load.
function ns.InstallPanelHook()
  if ns._panelHooked or not ReputationEntryMixin then return end
  ns._panelHooked = true
  hooksecurefunc(ReputationEntryMixin, "OnEnter", onRepEnter)
end

ns.InstallPanelHook()
