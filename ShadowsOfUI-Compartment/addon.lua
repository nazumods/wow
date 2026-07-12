---@class ShadowsOfUI_Compartment: AddOn
local ns = LibNAddOn(...)

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- Single-toggle settings panel, nested under the shared "Shadows of UI" group.
-- Declarative (ns:RegisterSettings) rather than a hand-built LibNUI SettingsFrame so
-- the category is recorded in settingsCategoriesByTitle — that is what lets the
-- changelog button (registered above) find and reuse this same category instead of
-- minting a second "Addon Compartment" subcategory under the parent.
local function dbTable(db) return db end
ns:RegisterSettings{
  {
    title = ns._TITLE,
    parent = "Shadows of UI",
    fields = {
      { typ = "checkbox", key = "useIcon", default = true, name = "Custom icon",
        label = "Use a custom icon (hides the addon count)", table = dbTable,
        tooltip = "Replace Blizzard's addon-count number on the compartment button with a clean cog icon." },
    },
  },
}

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
  -- SetPoint offsets are in the button's OWN coordinate space; our saved x/y are in
  -- UIParent units, so counter-convert by the button's effective scale relative to
  -- UIParent (the minimap-size slider makes the button's cluster scale != 1). This is
  -- the exact inverse of savePosition's fS/uiS, so the round-trip is scale-independent.
  local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x * scale, p.y * scale)
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

-- The settings toggle flips db.useIcon; re-apply the icon/number swap on change.
function ns:settingChanged()
  applyIcon()
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
end

-- /scompartment        → open settings
-- /scompartment reset  → move the button back to its default position
SLASH_SUI_COMPARTMENT1 = "/scompartment"
SlashCmdList["SUI_COMPARTMENT"] = function(msg)
  local cmd = (msg or ""):match("^%s*(%S*)"):lower()
  if cmd == "reset" then
    resetPosition()
    ns:Print("Addon-compartment button moved back to its default position.")
  elseif ns.settingsCategory then
    -- OpenToCategory takes a category ID, not a name (and ours is a subcategory).
    Settings.OpenToCategory(ns.settingsCategory:GetID())
  end
end
