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

-- ---------------------------------------------------------------------------------------------
-- Loads the REAL guild.lua against a scriptable fake guild client so the async query state machine
-- (candidate skill lines, response correlation, timeout vs supersession, nil queryID, the bounded
-- cache) can be driven out of game (spec/guildquery_spec.lua).
--
-- `state` is the fake client: `queries` logs every QueryGuildMembersForRecipe call; `timers` holds
-- the pending C_Timer.After callbacks (`state.fire(i)` runs one, `state.fireAll()` all in order);
-- `state.profInfo[recipeID]` is what GetProfessionInfoByRecipeID returns; `state.post` is what
-- GetGuildRecipeInfoPostQuery returns ({ skillLineID, recipeID, numMembers }) and `state.members`
-- the GetGuildRecipeMember rows; `state.nilQuery` makes QueryGuildMembersForRecipe return nil;
-- `state.secret[value]` marks a value issecretvalue() reports as secret. `state.respond(post, members)`
-- sets both and fires GUILD_RECIPE_KNOWN_BY_MEMBERS.
-- ---------------------------------------------------------------------------------------------
---@param opts { inGuild: boolean? }?
---@return table ns, table state
function M.loadGuildQuery(opts)
  opts = opts or {}
  local state = {
    inGuild = opts.inGuild ~= false, queries = {}, timers = {}, profInfo = {}, secret = {},
    members = {}, primed = 0, events = {},
  }
  function state.fire(i) local t = state.timers[i]; state.timers[i] = false; t() end
  function state.fireAll() for i = 1, #state.timers do if state.timers[i] then state.fire(i) end end end
  function state.pendingTimers() local n = 0 for _, t in ipairs(state.timers) do if t then n = n + 1 end end return n end

  _G.IsInGuild = function() return state.inGuild end
  _G.QueryGuildRecipes = function() state.primed = state.primed + 1 end
  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  _G.issecretvalue = function(v) return state.secret[v] == true end
  _G.C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() end }
  _G.C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end }
  _G.C_TradeSkillUI = { GetProfessionInfoByRecipeID = function(id) return state.profInfo[id] end }
  _G.C_GuildInfo = {
    QueryGuildMembersForRecipe = function(skillLineID, recipeID, recipeLevel)
      state.queries[#state.queries + 1] = { skillLineID, recipeID, recipeLevel }
      if state.nilQuery then return nil end
      return 1000 + #state.queries
    end,
  }
  _G.GetGuildRecipeInfoPostQuery = function() return unpack(state.post or {}) end
  _G.GetGuildRecipeMember = function(i) local m = state.members[i] or {}; return m[1], nil, m[2], m[3] end

  local ns = {
    wow = { ClassKeyByToken = { MAGE = "Mage", WARRIOR = "Warrior" } },
    registerEvent = function(_, event, fn) state.events[event] = fn end,
  }
  assert(loadfile("ShadowsOfUI-Known/guild.lua"))("ShadowsOfUI-Known", ns)
  function state.respond(post, members)
    state.post, state.members = post, members or {}
    state.events.GUILD_RECIPE_KNOWN_BY_MEMBERS()
  end
  return ns, state
end

return M
