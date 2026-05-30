-- luacheck: globals CreateFrame hooksecurefunc
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function SetupBar(prefix, count)
  local first = _G[prefix .. "1"]
  if not first then return end

  local bar = first:GetParent()

  -- Remove padding between buttons
  if bar.GetButtonPadding then
    bar.GetButtonPadding = function() return 0 end
  end

  -- Apply 80% opacity to individual buttons (avoids dimming unrelated UI on the parent)
  local function ApplyAlpha()
    for i = 1, count do
      local btn = _G[prefix .. i]
      if btn then
        btn:SetAlpha(0.7)
        btn.NormalTexture:SetAlpha(0.7)
      end
    end
  end

  if bar.UpdateGridLayout then
    hooksecurefunc(bar, "UpdateGridLayout", ApplyAlpha)
    bar:UpdateGridLayout()
  end

  ApplyAlpha()
end

-- MainActionBarButtonContainer1
frame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  SetupBar("ActionButton", 12)
  SetupBar("MultiBarBottomLeftButton", 12)
end)
