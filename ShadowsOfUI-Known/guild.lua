---@type ShadowsOfUI_Known
local ns = select(2, ...)

local insert, sort = table.insert, table.sort

-- ─── Guild crafter lookup ─────────────────────────────────────────────────────
--
-- "Which guild members can craft this recipe" via Blizzard's native async query:
-- C_GuildInfo.QueryGuildMembersForRecipe -> GUILD_RECIPE_KNOWN_BY_MEMBERS ->
-- GetGuildRecipeInfoPostQuery + GetGuildRecipeMember. No SavedVars, no addon comms —
-- the client already tracks guild recipe knowledge; we just ask it per recipe.
--
-- The query is finicky about the skill line it's handed, so we try the recipe's own
-- (expansion-specific) profession then its parent (base) profession. Some recipes are
-- gaps in Blizzard's guild data and never answer — a per-attempt timeout treats those
-- as "no crafters" rather than leaving the query hanging.

local QUERY_TIMEOUT = 3   -- seconds to await GUILD_RECIPE_KNOWN_BY_MEMBERS per skill line
local MAX_CACHE = 30      -- bounded per-recipe result cache (FIFO eviction)

-- Guild data returns can be *secret values* (12.0): reading one from tainted code and
-- then using it (as a table key, in arithmetic, via SetText width math) can crash and be
-- blamed on us. Treat a secret as unknowable -> nil; a later query refills it.
local function nonsecret(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

---@class GuildCrafterEntry
---@field name string      display (short) character name
---@field classKey string? PascalCase class key for colouring (nil if unknown/secret)
---@field online boolean

-- Online crafters first (they can make it right now), then alphabetical.
---@param list GuildCrafterEntry[]
---@return GuildCrafterEntry[] list  sorted in place
function ns.SortGuildCrafters(list)
  sort(list, function(a, b)
    if a.online ~= b.online then return a.online end
    return a.name < b.name
  end)
  return list
end

-- ─── Result cache (per recipeID, bounded FIFO) ────────────────────────────────
local cache = {}   -- [recipeID] = GuildCrafterEntry[]  (empty list = queried, none found)
local order = {}   -- recipeIDs in insertion order, for eviction

local function cacheResult(recipeID, crafters)
  if cache[recipeID] == nil then
    insert(order, recipeID)
    if #order > MAX_CACHE then cache[table.remove(order, 1)] = nil end
  end
  cache[recipeID] = crafters
end

-- ─── One-shot priming ─────────────────────────────────────────────────────────
-- The guild-recipe subsystem must be initialised for GUILD_RECIPE_KNOWN_BY_MEMBERS to
-- fire: Blizzard_Communities loaded and QueryGuildRecipes() called once. Primed when the
-- customer-orders frame opens, so data is ready by the time a row is hovered.
local primed = false
local function prime()
  if primed or not IsInGuild() then return end
  primed = true
  if C_AddOns and not C_AddOns.IsAddOnLoaded("Blizzard_Communities") then
    C_AddOns.LoadAddOn("Blizzard_Communities")
  end
  if QueryGuildRecipes then QueryGuildRecipes() end
end

-- ─── Async query state machine ────────────────────────────────────────────────
-- One query is in flight at a time (a tooltip hovers one row). `session` invalidates a
-- stale timeout/event when a newer hover supersedes an older query.
local active    -- { recipeID, queryID, candidates, idx, tooltip, session }
local session = 0

local GetProfInfo = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID

-- Skill lines to try for a recipe: its own profession then the parent (base) profession —
-- QueryGuildMembersForRecipe wants one of these exact ids.
local function candidateSkillLines(recipeID)
  local out, seen = {}, {}
  if GetProfInfo then
    local ok, info = pcall(GetProfInfo, recipeID)
    if ok and info then
      for _, id in ipairs({ info.professionID, info.parentProfessionID }) do
        if id and not seen[id] then seen[id] = true; insert(out, id) end
      end
    end
  end
  return out
end

local function refreshTooltip(tt)
  if tt and tt.IsShown and tt:IsShown() then
    if tt.RefreshDataNextUpdate then tt:RefreshDataNextUpdate()
    elseif tt.RefreshData then tt:RefreshData() end
  end
end

local function finish(crafters)
  if not active then return end
  local a = active
  active = nil
  cacheResult(a.recipeID, crafters)
  refreshTooltip(a.tooltip)
end

local advance  -- fwd (mutually recursive with fireCandidate)

local function fireCandidate()
  if not active then return end
  local a, idx, s = active, active.idx, active.session
  a.queryID = C_GuildInfo.QueryGuildMembersForRecipe(a.candidates[idx], a.recipeID, 1) or a.recipeID
  C_Timer.After(QUERY_TIMEOUT, function()
    if active == a and a.session == s and a.idx == idx then advance() end
  end)
end

-- Move to the next candidate skill line, or finish empty once they're exhausted.
advance = function()
  if not active then return end
  local a = active
  a.idx = a.idx + 1
  if a.idx > #a.candidates then finish({}) else fireCandidate() end
end

local function onGuildRecipeResult()
  if not (active and GetGuildRecipeInfoPostQuery) then return end
  local a = active
  local _, postRecipeID, numMembers = GetGuildRecipeInfoPostQuery()
  if not postRecipeID then return end
  if postRecipeID ~= a.queryID and postRecipeID ~= a.recipeID then return end  -- not our query
  if not (numMembers and numMembers > 0) then advance() return end

  local crafters = {}
  for i = 1, numMembers do
    local displayName, _, classFileName, online = GetGuildRecipeMember(i)
    displayName, classFileName, online = nonsecret(displayName), nonsecret(classFileName), nonsecret(online)
    if displayName then
      insert(crafters, {
        name     = displayName,
        classKey = classFileName and ns.wow.ClassKeyByToken[classFileName] or nil,
        online   = online or false,
      })
    end
  end
  finish(ns.SortGuildCrafters(crafters))
end

ns:registerEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS", onGuildRecipeResult)

-- Fresh guild data (and online/offline) each browsing session; cancel any in-flight query.
ns:registerEvent("CRAFTINGORDERS_SHOW_CUSTOMER", function()
  prime()
  active = nil
  wipe(cache)
  wipe(order)
end)

-- Guild crafters for `recipeID`. Returns cached results (possibly empty) when ready, or
-- kicks off the async query and reports "pending" — pass the live `tooltip` so its line
-- refreshes when the result lands. `nil` state means not queryable here (not in a guild,
-- or the recipe has no resolvable profession).
---@param recipeID integer
---@param tooltip table?
---@return GuildCrafterEntry[]? crafters
---@return string? state  "ready" | "pending" | nil
function ns.GuildCrafters(recipeID, tooltip)
  if not recipeID then return nil, nil end
  local hit = cache[recipeID]
  if hit then return hit, "ready" end
  if active and active.recipeID == recipeID then
    active.tooltip = tooltip or active.tooltip
    return nil, "pending"
  end
  if not (IsInGuild() and C_GuildInfo and C_GuildInfo.QueryGuildMembersForRecipe) then return nil, nil end
  local candidates = candidateSkillLines(recipeID)
  if #candidates == 0 then return nil, nil end
  prime()
  session = session + 1
  active = { recipeID = recipeID, candidates = candidates, idx = 1, tooltip = tooltip, session = session }
  fireCandidate()
  return nil, "pending"
end
