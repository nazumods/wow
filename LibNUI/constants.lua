---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local ToMap = ns.lua.maps.toMap

---@class LibNUI
---@field edge table edge constants
---@field layer table layer constants
---@field wrap table wrap constants
---@field justify table justify constants

ui.edge = ToMap({
  "Top", "Center", "TopLeft", "TopRight",
  "Bottom", "BottomLeft", "BottomRight",
  "Left", "Right"
}, string.upper)
ui.layer = ToMap({"Background", "Border", "Artwork", "Overlay", "Highlight"}, string.upper)
ui.wrap = ToMap({"Clamp", "Repeat", "Mirror"}, string.upper)
ui.justify = ToMap({"Left", "Center", "Right", "Top", "Middle", "Bottom"}, string.upper)
