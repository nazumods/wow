local _, ns = ...
local insert = table.insert
local lists = ns.lua.lists
local CreateColor = CreateColor

-- https://wowpedia.fandom.com/wiki/ColorMixin#Global_Colors
-- https://www.rapidtables.com/convert/color/hex-to-rgb.html

ns.Colors = {
  -- https://wowpedia.fandom.com/wiki/Class_colors
  DeathKnight = {0.77, 0.12, 0.23},
  DemonHunter = {0.64, 0.19, 0.79},
  Druid = {1, 0.49, 0.04},
  Evoker = {0.2, 0.58, 0.5},
  Hunter = {0.67, 0.83, 0.45},
  Mage = {0.41, 0.8, 0.94},
  Monk = {0.33, 0.54, 0.52},
  Paladin = {0.96, 0.55, 0.73},
  Priest = {1, 1, 1},
  Rogue = {1, 0.96, 0.41},
  Shaman = {0, 0.44, 0.87},
  Warlock = {0.58, 0.51, 0.79},
  Warrior = {0.78, 0.61, 0.43},

  TransparentBlack = {0, 0, 0, 0},
}

ns.Colors.Strings = {
  Icons = {
    Empty = "|T:14:14:0:0|t",
    Alliance = "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:19:16:0:0:64:64:0:32:0:38|t",
    Horde = "|TInterface\\TargetingFrame\\UI-PVP-HORDE:18:19:0:0:64:64:0:38:0:36|t",
    Lock = "|TInterface\\LFGFrame\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:28:0:28|t",
  },
}

---Create a new color table with the specified RGBA values.
---@param r integer The red component (0-255).
---@param g integer The green component (0-255).
---@param b integer The blue component (0-255).
---@param a integer The alpha component (0-255).
---@return table A table representing the color in normalized RGBA format.
ns.Colors.rgba = function(r, g, b, a)
  return CreateColor(r/255, g/255, b/255, a)
end

---Create a new color table with the specified RGB values and an optional alpha.
---If the color already has an alpha value, it will be replaced.
---@param color table The original color table.
---@param alpha number The alpha value to set (0-1).
---@return table A new color table with the specified alpha.
ns.Colors.alpha = function(color, alpha)
  local c = lists.values(color.GetRGBA and {color:GetRGBA()} or color)
  if #c < 4 then
    insert(c, alpha)
  else
    c[4] = alpha or 1
  end
  return c
end
