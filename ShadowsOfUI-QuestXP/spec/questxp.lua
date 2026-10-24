-- Loads the REAL ShadowsOfUI-QuestXP/core.lua against a scriptable fake client so ns.GetRewardPercent
-- and the XP-text hook can be driven out of game. `state` is the fake client: `maxLevel`, `rewardXP`,
-- `maxXP`. The reward frame exists at load (so the hook installs immediately); its FontString records
-- every SetText, running the hooked function after the original like hooksecurefunc does.
-- Path is relative to the AddOns root, where busted runs.
local M = {}

---@param init { maxLevel: boolean?, rewardXP: number?, maxXP: number? }?
---@return table ns, table state, table fontString
function M.load(init)
  local state = { maxLevel = false, rewardXP = nil, maxXP = 100000 }
  for k, v in pairs(init or {}) do state[k] = v end

  _G.GetQuestLogRewardXP = function() return state.rewardXP end
  _G.GRAY_FONT_COLOR = { WrapTextInColorCode = function(_, t) return "<" .. t .. ">" end }
  _G.SlashCmdList = {}
  _G.C_QuestLog = { GetSelectedQuest = function() return 1 end }

  local fs = { texts = {}, calls = 0 }
  function fs:SetText(t) self.calls = self.calls + 1; self.texts[#self.texts + 1] = t end
  _G.MapQuestInfoRewardsFrame = { XPFrame = { Name = fs } }
  _G.hooksecurefunc = function(tbl, name, fn)
    local orig = tbl[name]
    tbl[name] = function(self, ...) orig(self, ...); fn(self, ...) end
  end

  local ns = {
    RegisterChangelog = function() end,
    Print = function() end,
    wow = { Player = {
      isMaxLevel = function() return state.maxLevel end,
      GetMaxXP = function() return state.maxXP end,
    } },
  }
  _G.LibNAddOn = function() return ns end
  assert(loadfile("ShadowsOfUI-QuestXP/core.lua"))("ShadowsOfUI-QuestXP", ns)
  return ns, state, fs
end

return M
