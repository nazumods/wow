---@class LibNAddOn
local ns = select(2, ...)
local Mixin, setmetatable, getmetatable, type, pairs = Mixin, setmetatable, getmetatable, type, pairs
local merge = ns.lua.maps.merge

---@class Lua
---@field Class fun(parent: table?, fn: function, defaults: table?, ...: table?): table create a class with optional parent class, constructor function, default properties and mixins

---@class Class
---@field new fun(self: Class, o: table?): any constructor

---@param parent table? Parent Class
---@param fn function constructor
---@param defaults table? default properties
---@param ... table? additional table to mixin
---@return Class
function ns.lua.Class(parent, fn, defaults, ...)
  local c, onLoad = {}, defaults and defaults.onLoad
  if defaults then defaults.onLoad = nil end
  Mixin(c, ...)

  -- define the constructor
  function c:new(o)
    if defaults then
      for k, v in pairs(defaults) do
        if o[k] == nil then
          -- plain-table defaults are copied so instances never share (or
          -- corrupt) the class's default tables; metatabled values (frames,
          -- widget instances) are shared by reference on purpose
          o[k] = (type(v) == "table" and getmetatable(v) == nil) and merge({}, v) or v
        end
      end
    end
    o = parent and parent:new(o) or o
    Mixin(o, parent or {}, c)
    setmetatable(o, self)
    self.__index = self
    fn(o)
    if c.onLoad then c.onLoad(o) end
    if onLoad then onLoad(o) end
    return o
  end

  return c
end
