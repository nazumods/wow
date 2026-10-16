-- Loads ShadowsOfUI-Known/tooltip.lua against a minimal fake environment so the
-- pure ns.ReqSkill tooltip parser can be unit-tested. tooltip.lua's only load-time
-- side effects are two ns:OnItemTooltip registrations (stubbed) and reading the
-- ITEM_MIN_SKILL global (set here). Path is relative to the AddOns root.
local M = {}

-- `minSkill`: the ITEM_MIN_SKILL format string to load under. Omit for the default
-- "Requires %s (%d)"; pass `false` to load with ITEM_MIN_SKILL absent (fallback path).
---@return table ns
function M.load(minSkill)
  if minSkill == nil then minSkill = "Requires %s (%d)" end
  _G.ITEM_MIN_SKILL = minSkill or nil
  _G.NORMAL_FONT_COLOR = _G.NORMAL_FONT_COLOR or {}
  _G.C_TradeSkillUI = nil
  _G.SlashCmdList = _G.SlashCmdList or {}  -- tooltip.lua registers /sknown at load
  local ns = { OnItemTooltip = function() end }
  assert(loadfile("ShadowsOfUI-Known/tooltip.lua"))("ShadowsOfUI-Known", ns)
  return ns
end

-- Loads ShadowsOfUI-Known/guild.lua against a minimal fake environment so the pure
-- ns.SortGuildCrafters comparator can be unit-tested. guild.lua's only load-time side
-- effects are two ns:registerEvent calls (stubbed) — the C_* API is only touched at
-- runtime (short-circuited to nil at load here).
---@return table ns
function M.loadGuild()
  local ns = { registerEvent = function() end }
  assert(loadfile("ShadowsOfUI-Known/guild.lua"))("ShadowsOfUI-Known", ns)
  return ns
end

-- ---------------------------------------------------------------------------------------------
-- Loads the REAL core.lua + tooltip.lua against a fake ns / fake WoW globals, captures the two
-- ns:OnItemTooltip callbacks, and returns drivers for them (spec/forever_known_spec.lua).
-- `opts.toons` is the Character[] ns.api:GetAllCharacters() returns; `opts.guild` is what a
-- stubbed ns.GuildCrafters returns as (list, state); `opts.profName` what
-- C_TradeSkillUI.GetProfessionNameForSkillLineAbility returns (nil = the API answers nothing).
-- Globals are restored by M.restore() (call from after_each).
-- ---------------------------------------------------------------------------------------------
local saved

local function wrapColor() return { WrapTextInColorCode = function(_, t) return t end } end

---@param opts { toons: table[]?, guild: { [1]: table?, [2]: string? }?, profName: string? }?
function M.loadTooltips(opts)
  opts = opts or {}
  saved = saved or {}
  local function setGlobal(k, v)
    if saved[k] == nil then saved[k] = { value = _G[k] } end
    _G[k] = v
  end
  setGlobal("NORMAL_FONT_COLOR", wrapColor())
  setGlobal("RED_FONT_COLOR", wrapColor())
  setGlobal("GRAY_FONT_COLOR", wrapColor())
  setGlobal("ITEM_MIN_SKILL", "Requires %s (%d)")
  setGlobal("SlashCmdList", {})
  setGlobal("wipe", function(t) for k in pairs(t) do t[k] = nil end end)
  setGlobal("Enum", { ItemClass = { Recipe = 9 } })
  -- GetItemInfoInstant(itemID) -> 6th return = classID, 7th = subClassID: a Tailoring recipe item
  setGlobal("C_Item", { GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 9, 2 end })
  setGlobal("C_TradeSkillUI", { GetProfessionNameForSkillLineAbility = function() return opts.profName end })
  setGlobal("ProfessionsCustomerOrdersFrame", { IsShown = function() return true end })

  local callbacks, printed = {}, {}
  local ns = {
    RegisterChangelog = function() end,
    registerEvent = function() end,
    OnItemTooltip = function(_, fn) callbacks[#callbacks + 1] = fn end,
    Print = function(...)
      local parts = {}
      for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
      printed[#printed + 1] = table.concat(parts, " ")
    end,
    Colors = { className = function(name) return name end },
    api = { GetAllCharacters = function() return opts.toons or {} end },
  }
  setGlobal("LibNAddOn", function() return ns end)
  assert(loadfile("ShadowsOfUI-Known/core.lua"))("ShadowsOfUI-Known", ns)
  -- the real guild.lua is async and needs a guild; tooltip.lua only calls ns.GuildCrafters
  ns.GuildCrafters = function() return opts.guild and opts.guild[1], opts.guild and opts.guild[2] end
  assert(loadfile("ShadowsOfUI-Known/tooltip.lua"))("ShadowsOfUI-Known", ns)
  assert(#callbacks == 2, "tooltip.lua should register exactly two ns:OnItemTooltip callbacks")

  local function newTooltip(owner)
    local t = { lines = {} }
    function t:AddLine(text) self.lines[#self.lines + 1] = text end
    function t:GetOwner() return owner end
    return t
  end
  local d = { ns = ns, printed = printed }
  -- Run the /sknown slash handler (messages land in d.printed).
  function d.slash(msg) _G.SlashCmdList["SUI_KNOWN"](msg) end
  -- Hover a recipe ITEM (name-matched "Learnable by / Known by" surface).
  function d.hoverRecipeItem(itemName, reqSkill)
    local tip = newTooltip(nil)
    callbacks[1](tip, { id = 4242, lines = {
      { leftText = itemName },
      { leftText = "Requires Tailoring (" .. (reqSkill or 50) .. ")" },
    } })
    return tip.lines
  end
  -- Hover a Place Crafting Order browse row (recipeID-matched "Known by / Not Known / Guild crafters").
  function d.hoverCraftingOrderRow(recipeID, skillLineAbilityID)
    local tip = newTooltip({ option = { spellID = recipeID, skillLineAbilityID = skillLineAbilityID } })
    callbacks[2](tip)
    return tip.lines
  end
  return d
end

function M.restore()
  for k, s in pairs(saved or {}) do _G[k] = s.value end
  saved = nil
end

return M
