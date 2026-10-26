-- Loads ShadowsOfUI-Ilvl/render.lua against a scriptable fake client so ns.WantGear and the
-- ns.UpdateButton stale-token guard can be driven out of game (spec/updatebutton_spec.lua).
-- Items are fakes whose ContinueOnItemLoad queues its callback on `state.loads` (the item data has
-- not arrived yet); `state.flush(i)` delivers one, `state.flush()` all in order. Path is relative to
-- the AddOns root, where busted runs.
local M = {}

local ARMOR, WEAPON = 4, 2

---@return table ns, table state
function M.load()
  local state = { loads = {}, itemClass = {}, upgrade = nil }
  function state.flush(i)
    if i then
      local fn = state.loads[i]; state.loads[i] = false; fn()
    else
      for j = 1, #state.loads do if state.loads[j] then state.flush(j) end end
    end
  end

  local env = {
    Enum = { ItemClass = { Weapon = WEAPON, Armor = ARMOR } },
    C_Item = {
      GetItemUpgradeInfo = function() return state.upgrade end,
      GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, state.itemClass[id] end,
      GetItemQualityColor = function() return 1, 1, 1 end,
    },
    CreateColor = function() return { GenerateHexColor = function() return "ffffffff" end } end,
  }
  local function region()
    local r = { shown = false }
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetText(t) self.text = t end
    for _, m in ipairs({ "SetFont", "SetPoint", "SetTextColor", "SetJustifyH", "SetAllPoints", "SetFrameLevel" }) do
      r[m] = function() end
    end
    return r
  end
  env.CreateFrame = function()
    local f = region()
    function f:CreateFontString() return region() end
    return f
  end
  env._G = env
  setmetatable(env, { __index = _G })

  local ns = { flavor = { isForever = false }, db = {} }
  local chunk = assert(loadfile("ShadowsOfUI-Ilvl/render.lua"))
  setfenv(chunk, env)
  chunk("ShadowsOfUI-Ilvl", ns)
  return ns, state
end

M.ARMOR, M.WEAPON = ARMOR, WEAPON

---A fake loaded Item. `opts.empty` makes IsItemEmpty true.
---@param state table  from M.load
---@param id integer  itemID (its class comes from state.itemClass[id])
---@param opts { ilvl: integer?, quality: integer?, empty: boolean?, sync: boolean? }?
function M.item(state, id, opts)
  opts = opts or {}
  local item = {}
  function item:IsItemEmpty() return opts.empty == true end
  function item:GetItemQuality() return opts.quality or 4 end
  function item:GetItemID() return id end
  function item:GetItemLocation() return nil end
  function item:GetCurrentItemLevel() return opts.ilvl or 500 end
  function item:GetItemLink() return "|Hitem:" .. id .. "|h[Item]|h" end
  function item:ContinueOnItemLoad(fn)
    if opts.sync then fn() else state.loads[#state.loads + 1] = fn end
  end
  return item
end

---A fake item button. Its labels are created on demand by render.lua.
function M.button(name)
  local b = {}
  function b:GetName() return name end
  function b:GetFrameLevel() return 1 end
  function b:CreateFontString() return nil end
  return b
end

return M
