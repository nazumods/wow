local _, ns = ...

ns:registerCommand("refresh", "locks", function(self)
  self.brokers.instances:Update(self.currentData)
  self.Print("instance locks refreshed.")
end)

local difficulties = {}
difficulties[15] = "Normal"
difficulties[17] = "Heroic"
difficulties[16] = "Mythic"

ns:registerCommand("dump", "locks", function(self)
  if ns.currentData.instances.locks then
    ns.Print("Instance locks:")
    for id,i in pairs(ns.currentData.instances.locks) do
      for d,l in pairs(i) do
        print(l.name, id, difficulties[d], l.progress.."/"..l.total)
      end
    end
  else
    ns.Print("No instance locks found.")
  end
end)

---@type Broker
ns.Instances = ns:RegisterBroker("instances")
ns.Instances.fields = {
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
