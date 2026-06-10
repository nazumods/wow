---@class LibNAddOn
local ns = select(2, ...)
local Mixin = Mixin
local GetMajorFactionRenownInfo = C_MajorFactions.GetMajorFactionRenownInfo

local Faction = {}

local Factions = {
  GetMajorFactionRenownInfo = GetMajorFactionRenownInfo,
  Get = function(self, id)
    if not self._data[id] then self._data[id] = Mixin({id = id}, Faction) end
    return self._data[id]
  end,
}
ns.wow.Factions = Factions
