---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui

-- Matches the addon's `IconTexture` / compartment icon for a consistent identity
-- across the addon list, the compartment menu, and the minimap.
local ICON          = "Interface\\Icons\\inv_10_tailoring2_banner_green"
local DEFAULT_ANGLE = 210  -- degrees around the ring

local button  -- ui.MinimapButton, created at login

-- Toggle the main window (same shown-check ns:view uses).
local function toggleWindow()
  local w = ns.MainWindow
  if w and w._widget:IsShown() then w:Hide() else ns:Open() end
end

---Show or hide the minimap button and persist the choice.
---@param show boolean
function ns.SetMinimapShown(show)
  if button then button:Shown(show) end
end

ns:registerCommand("minimap", nil, function()
  local show = not button:Shown()  -- toggle from current state
  button:Shown(show)
  ns.Print(show and "Minimap button shown." or "Minimap button hidden.")
end, "Toggle the minimap button")

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
          root:CreateButton("Settings", function()
            if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
          end)
          root:CreateDivider()
          for _, v in ipairs(ns.NavViews()) do
            root:CreateButton(v.title, function() ns:view(v.name) end)
          end
        end)
      else
        toggleWindow()
      end
    end,
  }
end)
