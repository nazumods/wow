---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local Class = ns.lua.Class
local GetServerTime = GetServerTime
local DateAndTime = C_DateAndTime
local LAST_DAILY_RESET = GetServerTime() + DateAndTime.GetSecondsUntilDailyReset() - (60*60*24)
local LAST_RESET = GetServerTime() + DateAndTime.GetSecondsUntilWeeklyReset() - (60*60*24)
-- Most recent Sunday 00:00 UTC, derived from the epoch ALONE — never from
-- GetCurrentCalendarTime(). That call is unreliable at addon-load time (the
-- calendar system isn't warm yet — see Warbandeer's init.lua, which pre-warms it),
-- and a zeroed read (weekday=0, hour=0, minute=0) turned the old formula's
-- `-(weekday-1)*day` into `+1 day`, pushing the anchor a day into the FUTURE. That
-- read as a brand-new boundary and fired a spurious Sunday reset that wiped every
-- character's Sunday-cadence data (only the active char was re-populated). Epoch
-- day-of-week is deterministic (1970-01-01 was a Thursday) and needs no calendar
-- API, so this anchor is always valid and identical across every realm/timezone.
local SECONDS_PER_DAY = 24 * 60 * 60
local nowEpoch = GetServerTime()
local epochDays = math.floor(nowEpoch / SECONDS_PER_DAY)
local sundayOffset = (epochDays + 4) % 7 -- 0 = Sunday; +4 aligns the Thursday epoch
local LAST_SUNDAY_RESET = (epochDays - sundayOffset) * SECONDS_PER_DAY

-- The daily/weekly anchors are recomputed every login from the seconds-until APIs,
-- which can skew by a second between sessions. A genuine new boundary advances by
-- at least a day, so only treat an anchor as "new" when it moved by more than this
-- slack. (The Sunday anchor above is now jitter-free, but the same guard applies.)
local RESET_SLACK = 12 * 60 * 60

-- expose reset boundaries for non-broker (account-wide) data that resets on the same cadence
---@class Warbandeer_Characters
---@field LAST_DAILY_RESET integer
---@field LAST_RESET integer
---@field LAST_SUNDAY_RESET integer
ns.LAST_DAILY_RESET = LAST_DAILY_RESET
ns.LAST_RESET = LAST_RESET
ns.LAST_SUNDAY_RESET = LAST_SUNDAY_RESET


---@class BrokerField
---@field get fun(self: BrokerField, toon: Character, currentValue: any?): any
---@field maxLevel boolean?
---@field order integer?
---@field reset? fun(self: BrokerField, toon: Character): any
---@field resetOn string?
---@field [string] any

---@class Broker
---@field new function constructor
---@field name string
---@field fields table<string, BrokerField>
---@field fieldOrder string[] field names sorted by `order` priority, then alphabetically
local Broker = Class(nil, function() end)

---Prepare the broker for a character: ensure its data table exists, sort the
---field order, wire field event handlers, and default auto-reset functions.
---@param toon Character
function Broker:Init(toon)
  local broker = self.name
  if not toon[self.name] then toon[self.name] = {} end
  -- order the fields by priority
  self.fieldOrder = {}
  for name,_ in pairs(self.fields or {}) do
    insert(self.fieldOrder, name)
  end
  table.sort(self.fieldOrder, function(a,b)
    if self.fields[a].order and self.fields[b].order then return self.fields[a].order < self.fields[b].order end
    if self.fields[a].order then return true end
    if self.fields[b].order then return false end
    return a < b
  end)

  -- set up any event handlers we need
  if self.fields then
    for name,field in pairs(self.fields) do
      field.set = function(_, val) toon[broker][name] = val end
      field.get_live = function() return toon[broker][name] end
      if field.event then
        if not field.eventHandler then
          field.eventHandler = function(f, ...)
            if field.eventFilter and not field.eventFilter(f, ...) then return end
            if field.eventDelay then
              ns:after(field.eventDelay, function()
                toon[broker][name] = field:get(toon, toon[broker][name])
              end)
            else
              toon[broker][name] = field:get(toon, toon[broker][name])
            end
          end
        end
        -- register for the event(s)
        local events = type(field.event) == "table" and field.event or {field.event}
        for _,ev in ipairs(events) do
          ns:registerEvent(ev, function(_, ...)
            field.eventHandler(field, toon[broker][name], ...)
          end)
        end
      end

      -- auto-reset for simple fields
      if field.resetOn and not field.reset then
        field.reset = function() return nil end
      end
    end
  end

end
ns.Broker = Broker

---Re-fetch every field's value for a character, in field order.
---@param toon Character
function Broker:Update(toon)
  if not self.fields then return end
  for _, name in ipairs(self.fieldOrder) do
    toon[self.name][name] = self.fields[name]:get(toon, toon[self.name][name])
  end
end

---Reset every field whose `resetOn` matches the given cadence.
---@param type integer reset cadence: ns.RESET_SUNDAY, ns.RESET_DAILY, or ns.RESET_WEEKLY
---@param toon Character
function Broker:Reset(type, toon)
  if self.fields then
    for _,name in ipairs(self.fieldOrder) do
      if self.fields[name].resetOn == type then
        toon[self.name][name] = self.fields[name]:reset(toon)
      end
    end
  end
end

---@class Warbandeer_Characters
---@field Broker Broker
---@field brokers table<string, Broker> registered brokers by name
---@field brokerOrder string[] broker names in registration order
---@field RESET_SUNDAY integer reset cadence: Sunday midnight (realm-local)
---@field RESET_DAILY integer reset cadence: daily reset
---@field RESET_WEEKLY integer reset cadence: weekly reset
ns.brokers = {}
ns.brokerOrder = {}
ns.RESET_SUNDAY = 0
ns.RESET_DAILY = 1
ns.RESET_WEEKLY = 7

---Create and register a named broker; callers then populate its `fields`.
---@class Warbandeer_Characters
---@field RegisterBroker fun(self, name: string): Broker
function ns:RegisterBroker(name)
  self.brokers[name] = Broker:new{name = name}
  insert(self.brokerOrder, name)
  return self.brokers[name]
end

---Init every broker for the current character, then apply any daily/weekly/
---Sunday resets that have elapsed since the last login (with clock-skew slack).
---@class Warbandeer_Characters
---@field InitBrokers fun(self)
function ns:InitBrokers()
  for _,name in ipairs(self.brokerOrder) do
    self.brokers[name]:Init(self.currentData)
  end

  if self.db.lastDailyReset == nil or LAST_DAILY_RESET - self.db.lastDailyReset > RESET_SLACK then
    self.db.lastDailyReset = LAST_DAILY_RESET
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_DAILY, t)
      end
    end
  end

  if self.db.lastReset == nil or LAST_RESET - self.db.lastReset > RESET_SLACK then
    self.db.lastReset = LAST_RESET
    -- new week, reset data
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_WEEKLY, t)
      end
    end
  end

  if self.db.lastSundayReset == nil or LAST_SUNDAY_RESET - self.db.lastSundayReset > RESET_SLACK then
    self.db.lastSundayReset = LAST_SUNDAY_RESET
    -- new week, reset data
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_SUNDAY, t)
      end
    end
  elseif self.db.lastSundayReset > LAST_SUNDAY_RESET then
    -- The Sunday anchor is always a past Sunday midnight; a stored value in the
    -- future is corrupt (e.g. written by the old formula when a zeroed calendar
    -- read pushed it a day forward). Correct it down — without resetting — so the
    -- next genuine boundary still fires on time instead of being skipped.
    self.db.lastSundayReset = LAST_SUNDAY_RESET
  end
end
