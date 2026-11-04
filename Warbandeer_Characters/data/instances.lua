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
    missing = false,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      local numLocks = GetNumSavedInstances()
      local locks = {}
      local time = GetServerTime()
      -- Saved-instance info is requested from the server; read before it arrives, the list is empty. Keep the
      -- stored locks then rather than storing {} (#1046) -- but only those still running: this field also holds
      -- non-weekly (dungeon) locks, which expire mid-week, and a zero read must not keep a dead one.
      if numLocks == 0 and current then
        for id, byDifficulty in pairs(current) do
          for d, l in pairs(byDifficulty) do
            if (l.reset or 0) > time then
              locks[id] = locks[id] or {}
              locks[id][d] = l
            end
          end
        end
        return locks
      end
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
    event = { "INSTANCE_LOCK_STOP", "UPDATE_INSTANCE_INFO" },
  },
}

-- UPDATE_INSTANCE_INFO is the answer to RequestRaidInfo (Blizzard asks on every zone-in), so the lockouts
-- refresh when it arrives. A boss kill in an already-locked raid fires no lock event: ask for fresh info (#1046).
ns:registerEvent("BOSS_KILL", function() RequestRaidInfo() end)
