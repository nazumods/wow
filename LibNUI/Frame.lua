local _, ns = ...
local _G, insert = _G, table.insert
local CreateFrame = CreateFrame
local UISpecialFrames = UISpecialFrames
local Class, unpack = ns.lua.Class, unpack
local ui = ns.ui
local Region, Texture = ui.Region, ui.Texture

-- https://www.reddit.com/r/wowaddondev/comments/1cc2qgj/creating_a_wow_addon_part_2_creating_a_frame/
-- frame/UI control templates: https://www.wowinterface.com/forums/showthread.php?t=40444

-- empty frame
---@class Frame: Region
---@field OnLogin function
---@field onUpdate function
local Frame = Class(Region, function(self)
  if self.strata then self._widget:SetFrameStrata(self.strata) end
  if self.clamped then self._widget:SetClampedToScreen(true) end
  if self.scale then self._widget:SetScale(self.scale) end
  if self.level then self._widget:SetFrameLevel(self.level) end
  if self.special then
    -- make it closable with Escape key
    _G[self._widget:GetName()] = self._widget -- put it in the global namespace
    insert(UISpecialFrames, self._widget:GetName()) -- make it a special frame
  end

  if self.background then
    self.background = Texture:new{
      parent = self,
      layer = ui.layer.Background,
      position = { All = true },
      color = self.background,
    }
  end

  if self.drag then
    self:makeDraggable()
    self:makeContainerDraggable()
  end
  if self.dragTarget then self:setDragTarget(self.dragTarget._widget or self.dragTarget) end

  if self.scripts then
    self:RegisterScript(unpack(self.scripts))
  end
  if self.events then
    self:listenForEvents()
    for _,e in pairs(self.events) do
      self._widget:RegisterEvent(e)
    end
  end
  if self.unitEvents then
    self:listenForEvents()
    for e,u in pairs(self.unitEvents) do
      self._widget:RegisterUnitEvent(e, unpack(u))
    end
  end
end, {
  CreateWidget = function(self)
    return CreateFrame(self.type or "Frame", self.name, self.parent and self.parent._widget or self.parent, self.template)
  end,
})
ui.Frame = Frame

function Frame:OnEvent(event, ...)
  if self[event] then
    self[event](self, ...)
  end
end

function Frame:PLAYER_ENTERING_WORLD(login, reload)
  if self.OnLogin and (login or reload) then self:OnLogin() end
end

-- separate func so we don't occlude the varargs (...)
local function scriptHandlerFor(c, e)
  return function(...)
    if c[e] then c[e](c, ...) end
  end
end
function Frame:RegisterScript(...)
  local e
  for i=1,select("#", ...) do
    e = select(i, ...)
    self:SetScript(e, scriptHandlerFor(self, e))
  end
end
function Frame:SetScript(event, handler) self._widget:SetScript(event, handler); return self end
function Frame:RemoveScript(event) self._widget:SetScript(event, nil); return self end
function Frame:listenForEvents()
  if self._listening then return end
  self._listening = true
  local o = self
  self:SetScript("OnEvent", function(_, e, ...) o:OnEvent(e, ...) end)
end
function Frame:registerEvent(event) self._widget:RegisterEvent(event); return self end
function Frame:unregisterEvent(event) self._widget:UnregisterEvent(event); return self end

-- https://wowpedia.fandom.com/wiki/Making_draggable_frames
function Frame:makeDraggable()
  self._widget:SetMovable(true)
  self._widget:EnableMouse(true)
  self._widget:RegisterForDrag("LeftButton")
  return self
end
function Frame:makeContainerDraggable()
  self._widget:SetScript("OnDragStart", function()
    self._widget:StartMoving()
  end)
  self._widget:SetScript("OnDragStop", function()
    self._widget:StopMovingOrSizing()
  end)
  return self
end
function Frame:setDragTarget(target)
  self._widget:SetScript("OnMouseDown", function()
    target:StartMoving()
  end)
  self._widget:SetScript("OnMouseUp", function()
    target:StopMovingOrSizing()
  end)
end

function Frame:startUpdates()
  if self.onUpdate and not self.animating then
    self.animating = true
    local s = self
    self._widget:SetScript("OnUpdate", function(_, elapsed)
      if s.animating then s:onUpdate(elapsed * 1000) end
    end)
  end
end
function Frame:stopUpdates()
  self._widget:SetScript("OnUpdate", nil)
  self.animating = false
end

function Frame:delay(ms, fn)
  local s = self
  local t = 0
  self._widget:SetScript("OnUpdate", function(_, elapsed)
    t = t + (elapsed * 1000)
    if t < ms then return end
      s._widget:SetScript("OnUpdate", nil)
      if type(fn) == "function" then
        fn()
      else
        s[fn](s)
      end
  end)
end

-- todo, resizable: https://wowpedia.fandom.com/wiki/Making_resizable_frames

function Frame:Attribute(name, value) return value == nil and self._widget:GetAttribute(name) or self._widget:SetAttribute(name, value) end

function Frame:Level(level)
  if level then
    self._widget:SetFrameLevel(level)
  end
  return self._widget:GetFrameLevel()
end
