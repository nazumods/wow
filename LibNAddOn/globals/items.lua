local _, ns = ...
-- luacheck: globals GetItemIcon
local NumSlots = C_Container.GetContainerNumSlots -- luacheck: globals C_Container

local Items = {
  GetIcon = GetItemIcon,
  GetNumSlots = NumSlots,
}
ns.wow.Items = Items
