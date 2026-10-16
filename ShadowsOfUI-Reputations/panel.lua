---@type ShadowsOfUI_Reputations
local ns = select(2, ...)

-- The character pane's Reputation tab builds each faction row's tooltip in
-- ReputationEntryMixin:OnEnter (GameTooltip owned by the row). Post-hook it to append our
-- cross-alt standings, then re-Show so the tooltip resizes around the added lines.
--
-- Forever (the Camelot client) loads its own reputation frame, whose OnEnter opens NO
-- tooltip (Blizzard_UIPanels_Game/Camelot/ReputationFrame.lua). There the addon opens its
-- own: faction name + the standings block, and the OnLeave post-hook hides it again.

-- The row whose tooltip THIS addon opened (Forever only); nil when it opened none.
local openedFor

local function onRepEnter(self)
  local fid = self.elementData and self.elementData.factionID
  if not fid then return end
  -- Only standard/friendship/major-faction rows own GameTooltip. A Paragon row builds its
  -- tooltip on EmbeddedItemTooltip, and a selected row shows none (OnEnter skips it when
  -- IsSelected) — appending + Show()ing GameTooltip there floats a detached, mis-anchored
  -- tooltip with only our block. Guard on ownership so we only extend the row's own tooltip.
  if GameTooltip:GetOwner() == self then
    if ns.AppendStandings(GameTooltip, fid) then GameTooltip:Show() end
    return
  end

  -- Not owned by the row. Retail: nothing to extend. Forever: no row ever owns it, so the
  -- addon opens its own tooltip, except on the selected row (Retail shows none there either).
  if not (ns.flavor and ns.flavor.isForever) then return end
  if self.IsSelected and self:IsSelected() then return end

  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local data = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(fid)
  local name = (data and data.name) or self.elementData.name
  if name then GameTooltip:SetText(name, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b) end
  if ns.AppendStandings(GameTooltip, fid) then
    openedFor = self
    GameTooltip:Show()
  else
    -- No tracked standings: never leave a title-only tooltip behind.
    GameTooltip:Hide()
  end
end

-- Hide the tooltip only when this addon opened it for this row and the row still owns it;
-- never one Blizzard (Retail) or another addon opened.
local function onRepLeave(self)
  if openedFor ~= self then return end
  openedFor = nil
  if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

-- ReputationEntryMixin lives in Blizzard base UI (loaded at startup), but guard + expose an
-- installer so core.lua's onLogin can retry if the mixin isn't defined yet at file load.
function ns.InstallPanelHook()
  if ns._panelHooked or not ReputationEntryMixin then return end
  ns._panelHooked = true
  hooksecurefunc(ReputationEntryMixin, "OnEnter", onRepEnter)
  if ReputationEntryMixin.OnLeave then hooksecurefunc(ReputationEntryMixin, "OnLeave", onRepLeave) end
end

ns.InstallPanelHook()
