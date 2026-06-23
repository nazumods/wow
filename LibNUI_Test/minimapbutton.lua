local MinimapButton = LibNUI.MinimapButton
local toggling      = LibNUITest.toggling

-- Throwaway persistence store for the test (angle/hide live here in a real addon).
local db = {}

-- A draggable button on the real minimap. Exercises the default look (Blizzard
-- ring + background around an inset icon), the shape-aware positioning, the
-- click handler, the tooltip, and the addon-compartment entry. Drag it around
-- the ring; toggling the test hides/shows it.
---@return MinimapButton
local function makeMinimapButton()
  return MinimapButton:new{
    name         = "LibNUITest_MinimapButton",
    icon         = "Interface\\Icons\\achievement_guildperk_bountifulbags",
    db           = db,
    defaultAngle = 198,
    tooltip      = { "LibNUI MinimapButton", "Left-click / right-click: print", "Drag to move" },
    onClick      = function(_, mouseButton) print("MinimapButton: " .. mouseButton) end,
    compartment  = { text = "LibNUI MinimapButton", onClick = function() print("MinimapButton: compartment") end },
  }
end

table.insert(LibNUITest.tests, {
  key  = "minimapbutton",
  name = "Minimap Button",
  desc = "Draggable minimap-edge button (icon, tooltip, compartment)",
  run  = toggling(makeMinimapButton),
})
