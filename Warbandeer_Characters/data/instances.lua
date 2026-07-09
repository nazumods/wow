---@type Warbandeer_Characters
local ns = select(2, ...)

ns:registerCommand("refresh", "locks", function(self)
  self.brokers.instances:Update(self.currentData)
  self.Print("instance locks refreshed.")
end, "refresh instance locks")

local difficulties = {}
difficulties[15] = "Normal"
difficulties[17] = "Heroic"
difficulties[16] = "Mythic"

---@class Character
---@field instances InstancesBroker?

ns:registerDump("locks", "Instance Locks", "dump instance locks", function(_, out)
  if ns.currentData.instances.locks then
    out:line("Instance locks:")
    for id,i in pairs(ns.currentData.instances.locks) do
      for d,l in pairs(i) do
        out:line(l.name, id, difficulties[d], l.progress.."/"..l.total)
      end
    end
  else
    out:line("No instance locks found.")
  end
end)

---@class InstancesBroker: Broker
local Instances = ns:RegisterBroker("instances")
Instances.fields = {
  ---@class InstancesBroker
  ---@field locks any -- TODO
  locks = {
    resetOn = ns.RESET_WEEKLY,
    get = function()
      local locks = {}
      local time = GetServerTime()
      local numLocks = GetNumSavedInstances()
      for i=1,numLocks do
        local name, _, resetSeconds, difficultyId, locked, extended, _, isRaid,
          _, _, numEncounters, encounterProgress, _, instanceID = GetSavedInstanceInfo(i)
        if locked then
          if not locks[instanceID] then locks[instanceID] = {} end
          locks[instanceID][difficultyId] = {
            name = name,
            total = numEncounters,
            progress = encounterProgress,
            reset = time + resetSeconds,
            extended = extended,
            isRaid = isRaid,
          }
        end
      end
      return locks
    end,
    event = "INSTANCE_LOCK_STOP",
  },
}
