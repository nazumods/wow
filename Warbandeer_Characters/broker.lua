local _, ns = ...
local insert = table.insert
local Class = ns.lua.Class
local maxLevel = ns.wow.maxLevel
local GetServerTime = GetServerTime -- luacheck: globals GetServerTime
local DateAndTime = C_DateAndTime -- luacheck: globals C_DateAndTime
local LAST_DAILY_RESET = GetServerTime() + DateAndTime.GetSecondsUntilDailyReset() - (60*60*24)
local LAST_RESET = GetServerTime() + DateAndTime.GetSecondsUntilWeeklyReset() - (60*60*24)
local time = DateAndTime.GetCurrentCalendarTime()
local LAST_SUNDAY_RESET = GetServerTime() - ((time.weekday - 1) * 24 * 60 * 60) - (time.hour * 60 * 60) - (time.minute * 60) -- reset to sunday midnight
LAST_SUNDAY_RESET = LAST_SUNDAY_RESET - (LAST_SUNDAY_RESET % 60) -- zero out seconds

local eventListener = CreateFrame("Frame")
local _delay = function(ms, fn)
  local timer = 0
  eventListener:SetScript("OnUpdate", function(_, elapsed)
    timer = timer + (elapsed * 1000)
    if timer < ms then return end
    eventListener:SetScript("OnUpdate", nil)
    fn()
  end)
end

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
local Broker = Class(nil, function() end)

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
      if field.event then
        if not field.eventHandler then
          field.eventHandler = function(self, ...)
            if field.eventFilter and not field.eventFilter(self, ...) then return end
            if field.eventDelay then
              _delay(field.eventDelay, function()
                toon[broker][name] = field:get(toon)
              end)
            else
              toon[broker][name] = field:get(toon)
            end
          end
        end
        -- register for the event
        ns:registerEvent(field.event, function(_, ...)
          field.eventHandler(field, toon[broker][name], ...)
        end)
      end
      
      -- auto-reset for simple fields
      if field.resetOn and not field.reset then
        field.reset = function() return nil end
      end
    end
  end

end
ns.Broker = Broker

function Broker:Update(toon)
  if self.fields then
    for _,name in ipairs(self.fieldOrder) do
      if self.fields[name].maxLevel and toon.basic.level < maxLevel then return end
      toon[self.name][name] = self.fields[name]:get(toon, toon[self.name][name])
    end
  end
end

function Broker:Reset(type, toon)
  if self.fields then
    for _,name in ipairs(self.fieldOrder) do
      if self.fields[name].resetOn == type then
        toon[self.name][name] = self.fields[name]:reset(toon)
      end
    end
  end
end

ns.brokers = {}
ns.brokerOrder = {}
ns.RESET_SUNDAY = 0
ns.RESET_DAILY = 1
ns.RESET_WEEKLY = 7

function ns:RegisterBroker(name)
  self.brokers[name] = Broker:new{name = name}
  insert(self.brokerOrder, name)
  return self.brokers[name]
end

function ns:InitBrokers()
  for _,name in ipairs(self.brokerOrder) do
    self.brokers[name]:Init(self.currentData)
  end

  if self.db.lastDailyReset == nil or self.db.lastDailyReset < LAST_DAILY_RESET then
    self.db.lastDailyReset = LAST_DAILY_RESET
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_DAILY, t)
      end
    end
  end

  if self.db.lastReset == nil or self.db.lastReset < LAST_RESET then
    self.db.lastReset = LAST_RESET
    -- new week, reset data
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_WEEKLY, t)
      end
    end
  end

  if self.db.lastSundayReset == nil or self.db.lastSundayReset < LAST_SUNDAY_RESET then
    self.db.lastSundayReset = LAST_SUNDAY_RESET
    -- new week, reset data
    for _,t in pairs(self.db.characters) do
      for _,name in ipairs(self.brokerOrder) do
        self.brokers[name]:Reset(ns.RESET_SUNDAY, t)
      end
    end
  end
end
