local _, ns = ...
local Mixin, setmetatable = Mixin, setmetatable
local fill = ns.lua.maps.fill

---@param parent table? Parent Class
---@param fn function constructor
---@param defaults table? default properties
---@param ... table? additional table to mixin
---@return table Class
function ns.lua.Class(parent, fn, defaults, ...)
  local c, onLoad = {}, defaults and defaults.onLoad
  if defaults then defaults.onLoad = nil end
  Mixin(c, ...)

  -- define the constructor
  function c:new(o)
    if defaults then fill(o, defaults) end
    o = parent and parent:new(o) or o
    Mixin(o, parent or {}, c)
    setmetatable(o, self)
    self.__index = self
    fn(o)
    if parent and parent.onLoad then parent.onLoad(o) end
    if c.onLoad then c.onLoad(o) end
    if onLoad then onLoad(o) end
    return o
  end

  return c
end
