-- Loads the REAL ShadowsOfUI-Quests/core.lua against a fake warband so the cross-alt quest block
-- (ns.AppendQuestStatus, and the `names()` helper behind it) can be driven out of game.
-- `opts.status` is what ns.api:GetQuestStatus(questID) returns ({ active = {...}, completed = {...}} of
-- { name, classKey }), `opts.current` the logged-in character. Path is relative to the AddOns root.
local M = {}

---@param opts { status: table?, current: string? }?
---@return table ns
function M.load(opts)
  opts = opts or {}
  local color = { WrapTextInColorCode = function(_, t) return t end }
  _G.NORMAL_FONT_COLOR, _G.GRAY_FONT_COLOR = color, color
  local ns = {
    RegisterChangelog = function() end,
    Colors = { className = function(name) return name end },
    api = {
      GetQuestStatus = function() return opts.status end,
      GetCurrentCharacter = function() return opts.current end,
    },
  }
  _G.LibNAddOn = function() return ns end
  assert(loadfile("ShadowsOfUI-Quests/core.lua"))("ShadowsOfUI-Quests", ns)
  return ns
end

---A tooltip fake recording every AddLine's text.
function M.tooltip()
  local t = { lines = {} }
  function t:AddLine(text) self.lines[#self.lines + 1] = text end
  return t
end

---`n` entries named `<prefix>1..n`.
function M.entries(prefix, n)
  local out = {}
  for i = 1, n do out[i] = { name = prefix .. i, classKey = "Mage" } end
  return out
end

return M
