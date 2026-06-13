---@class LibNAddOn
local ns = select(2, ...)
local NumSlots = C_Container.GetContainerNumSlots

---Static item/bag helpers.
---@class Items
---@field GetIcon fun(item: number|string): number? icon FileID for an itemID/name/link
---@field GetNumSlots fun(bagId: number): integer number of slots in a container
local Items = {
  GetIcon = GetItemIcon,
  GetNumSlots = NumSlots,
}
ns.wow.Items = Items
