local _, ns = ...

---@class ReputationBroker: Broker
ns.Reputation = ns:RegisterBroker("reputation")

-- doesn't seem a good way to get this via the api
-- except to crawl the discovered factions by expanding/collapsing what's shown in the standard rep window
-- which would need to be saved in db, at which point why not just hardcode it from wago:
-- https://wago.tools/db2/Faction?filter%5BExpansion%5D=10&page=1

ns.Reputation.fields = {
  legion = {
    ids = {
      2170, -- Argussian Reach
      2045, -- Armies of Legionfall
      2165, -- Army of the Light
      1900, -- Court of Farondis
      1883, -- Dreamweavers
      1828, -- Highmountain Tribe
      1859, -- The Nightfallen
      1894, -- The Wardens
      1948, -- Valarjar
    },
    get = function(self)
      return ns.lua.maps.toMap(self.ids, function(id)
        local info = C_Reputation.GetFactionDataByID(id)
        local done = C_Reputation.IsFactionParagon(id)
        return {
          name = info.name,
          done = done,
          current = info.currentStanding,
          max = 42000,
        }
      end)
    end,
  },
}
