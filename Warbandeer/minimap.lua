---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui

-- Matches the addon's `IconTexture` / compartment icon for a consistent identity
-- across the addon list, the compartment menu, and the minimap.
local ICON          = "Interface\\Icons\\inv_10_tailoring2_banner_green"
local DEFAULT_ANGLE = 210  -- degrees around the ring
local VIEW_ICONS    = "Interface\\AddOns\\Warbandeer\\icons\\views\\"  -- per-view glyphs (white TGAs, same as the rail)

local button  -- ui.MinimapButton, created at login

-- Toggle the main window (same shown-check ns:view uses).
local function toggleWindow()
  local w = ns.MainWindow
  if w and w._widget:IsShown() then w:Hide() else ns:Open() end
end

-- Populate a right-click menu with the Settings entry, a divider, then one button
-- per nav view (each prefixed with the view's rail glyph). Shared by the minimap
-- button and the addon-compartment entry so both launchers offer the same views.
---@param root table the MenuUtil rootDescription
local function populateViewMenu(root)
  root:CreateButton("Settings", function()
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
  end)
  root:CreateDivider()
  for _, v in ipairs(ns.NavViews()) do
    -- inline the view's rail glyph; |T| can't rotate, so the Bars icon
    -- shows in its base orientation here (cosmetic only)
    local label = ("|T%s%s.tga:16:16|t  %s"):format(VIEW_ICONS, v.name, v.title)
    root:CreateButton(label, function() ns:view(v.name) end)
  end
end

---Show or hide the minimap button and persist the choice.
---@param show boolean
function ns.SetMinimapShown(show)
  if button then button:Shown(show) end
end

-- Addon-compartment click handler: right-click opens the same view menu the
-- minimap button offers (positioned at the cursor, owned by the always-present
-- compartment frame); any other click opens the window.
---@param btn string "LeftButton"|"RightButton"|"MiddleButton"
function ns:CompartmentClick(btn)
  if btn == "RightButton" then
    MenuUtil.CreateContextMenu(AddonCompartmentFrame, function(_, root) populateViewMenu(root) end)
  else
    self:Open()
  end
end

ns:registerCommand("minimap", nil, function()
  local show = not button:Shown()  -- toggle from current state
  button:Shown(show)
  ns.Print(show and "Minimap button shown." or "Minimap button hidden.")
end, "Toggle the minimap button")

-- Surface the same show/hide state as a checkbox in the Warbandeer Settings panel
-- (#218), alongside Default View / Tooltip Side. A second RegisterSettings on the
-- existing "Warbandeer" category reuses that panel (getParent), keeping the minimap
-- concern co-located here rather than in init.lua. Binds directly to `hide`, so the
-- box reads "checked = hidden" — matching the right-click "Hide minimap button"
-- wording; the slash command, the menu, and this checkbox all drive ns.db.minimap.hide.
ns:RegisterSettings{
  {
    title = "Warbandeer",
    fields = {
      {
        name = "Hide minimap button",
        typ = "checkbox",
        default = false,
        -- ns.db.minimap is otherwise lazy-created at PLAYER_LOGIN, which runs *after*
        -- settings register on ADDON_LOADED; register() silently skips a field whose
        -- table closure returns nil, so ensure-create it here. Mirrors the ensure-and-
        -- return in views/summaryColumnsSettings.lua.
        table = function(db)
          db.minimap = db.minimap or {}
          return db.minimap
        end,
        key = "hide",
        label = "Hide minimap button",
        tooltip = "Hide the Warbandeer button on the minimap",
        -- `value` is the new hide state (checked = hidden); apply the inverse live so
        -- the button appears/disappears immediately, not just on next /reload.
        callback = function(_, value) ns.SetMinimapShown(not value) end,
      },
    },
  },
}

-- Warbandeer already registers an addon-compartment entry via the .toc
-- (AddonCompartmentFunc), so the widget's `compartment` option is omitted here.
ns:registerEvent("PLAYER_LOGIN", function()
  ns.db.minimap = ns.db.minimap or {}  -- lazy-init store (no DB version bump)
  button = ui.MinimapButton:new{
    name         = "WarbandeerMinimapButton",
    icon         = ICON,
    db           = ns.db.minimap,
    defaultAngle = DEFAULT_ANGLE,
    tooltip      = {
      "Warbandeer",
      "Left-click to open",
      "Right-click for menu",
      "Drag to move",
    },
    onClick = function(self, mouseButton)
      if mouseButton == "RightButton" then
        self:ShowContextMenu(function(_, root)
          root:CreateButton("Hide minimap button", function() self:Shown(false) end)
          populateViewMenu(root)
        end)
      else
        toggleWindow()
      end
    end,
  }
end)
