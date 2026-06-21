---@class ShadowsOfUI_WarbandInventory: AddOn
local ns = LibNAddOn(...)

local floor = math.floor

-- Wrap a character name in its class colour. `ns.Colors` keys are PascalCase,
-- matching `Character.classKey`; falls back to the bare name when the colour is
-- unknown (e.g. an alt stored before classKey existed).
---@param name string
---@param classKey string?
---@return string
function ns.ColorName(name, classKey)
  local c = classKey and ns.Colors[classKey]
  if not c or not c[1] then return name end
  return ("|cff%02x%02x%02x%s|r"):format(
    floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5), name)
end
