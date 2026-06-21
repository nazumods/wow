---@class ShadowsOfUI_Compartment: AddOn
local ns = LibNAddOn(...)
local SettingsFrame = ns.ui.SettingsFrame

-- Icon shown on the addon-compartment button when db.useIcon is on. A clean cog;
-- change this one constant to use a different icon (texture path or atlas name).
local ICON = "Interface\\Icons\\inv_misc_gear_08"

function ns:MigrateDB()
  local db = ns.db
  if db.useIcon == nil then db.useIcon = true end
  -- db.position stays nil until the user drags the button (nil = Blizzard default).
  db.version = 1
end

local frame ---@type Button  Blizzard's AddonCompartmentFrame, bound in onLoad
local defaultPoint ---@type table?  the button's Blizzard anchor, captured before we move it
local icon ---@type Texture?  our overlay icon, created lazily

-- Re-anchor the button to the saved, scale-independent UIParent position.
local function applyPosition()
  local p = ns.db.position
  if not p then return end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
end

-- Restore Blizzard's original anchor and forget the saved position.
local function resetPosition()
  ns.db.position = nil
  if defaultPoint then
    frame:ClearAllPoints()
    frame:SetPoint(unpack(defaultPoint))
  end
end

-- Convert the button's on-screen TOPLEFT into UIParent coordinates so the saved
-- offsets are independent of the minimap cluster's scale.
local function savePosition()
  local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  ns.db.position = { x = frame:GetLeft() * scale, y = frame:GetTop() * scale }
end

-- Swap the addon-count number for our icon (or restore the number).
local function applyIcon()
  if ns.db.useIcon then
    if not icon then
      icon = frame:CreateTexture(nil, "OVERLAY", nil, 7)
      icon:SetPoint("CENTER")
      icon:SetSize(32, 32)
      icon:SetTexture(ICON)
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border
    end
    icon:Show()
    frame.Text:Hide() -- the icon replaces the addon-count number
  else
    if icon then icon:Hide() end
    frame.Text:Show()
  end
end

-- ALT+left-drag moves the button; a plain left-click still opens the addon menu.
local function setupDrag()
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if IsAltKeyDown() then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition()
    applyPosition() -- re-anchor to UIParent so the position survives layout changes
  end)
end

function ns:onLoad()
  frame = AddonCompartmentFrame
  defaultPoint = { frame:GetPoint() }
  setupDrag()
  applyPosition()
  applyIcon()

  -- Blizzard re-runs UpdateDisplay whenever the addon count changes or the button
  -- is shown; reassert our position and icon each time so they stick.
  hooksecurefunc(frame, "UpdateDisplay", function()
    applyPosition()
    applyIcon()
  end)

  local settings = SettingsFrame:new{ headingText = ns._TITLE }
  settings:AddToggleControl("Use a custom icon (hides the addon count)", ns.db, "useIcon").SettingChanged = function(_, _state)
    applyIcon()
  end
  settings:RegisterSubcategory(ns:GetSettingsParent("Shadows of UI"), ns._TITLE)
end

-- /scompartment        → open settings
-- /scompartment reset  → move the button back to its default position
SLASH_SUI_COMPARTMENT1 = "/scompartment"
SlashCmdList["SUI_COMPARTMENT"] = function(msg)
  local cmd = (msg or ""):match("^%s*(%S*)"):lower()
  if cmd == "reset" then
    resetPosition()
    ns:Print("Addon-compartment button moved back to its default position.")
  else
    Settings.OpenToCategory(ns._TITLE)
  end
end
