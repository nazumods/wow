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
-- The query is finicky about the skill line it's handed, so we try the parent (base)
-- profession — the one Blizzard itself resolves to — then the recipe's own
-- (expansion-specific) one as a fallback. A response is correlated back to the candidate
-- that asked for it by the (skillLineID, recipeID) pair, since both candidates carry the
-- same recipeID. Some recipes are gaps in Blizzard's guild data and never answer — a
-- per-attempt timeout treats those as "no crafters" rather than leaving the query hanging.

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

-- ─── Priming ──────────────────────────────────────────────────────────────────
-- The guild-recipe subsystem must be initialised for GUILD_RECIPE_KNOWN_BY_MEMBERS to
-- fire: Blizzard_Communities loaded and QueryGuildRecipes() called. Primed when the
-- customer-orders frame opens, so data is ready by the time a row is hovered.
--
-- Getting the subsystem up at all is one-shot: load the addon and issue the first query.
local loaded = false
local function primeOnce()
  if loaded or not IsInGuild() then return end
  loaded = true
  if C_AddOns and not C_AddOns.IsAddOnLoaded("Blizzard_Communities") then
    C_AddOns.LoadAddOn("Blizzard_Communities")
  end
  if QueryGuildRecipes then QueryGuildRecipes() end
end

-- Keeping it *fresh* is not one-shot. Each browsing session wipes the cache to get current data
-- (online/offline especially), which only holds if the roster is re-queried too — otherwise the
-- wipe just re-reads the same stale state. Deliberately scoped to the frame-open event rather
-- than to prime-on-lookup: ns.GuildCrafters primes on every *cold* recipe, so re-querying there
-- would fire a guild query per uncached hover instead of one per browsing session.
local function refreshGuildRecipes()
  if not IsInGuild() then return end
  if not loaded then primeOnce() return end   -- primeOnce already issued the first query
  if QueryGuildRecipes then QueryGuildRecipes() end
end

-- ─── Async query state machine ────────────────────────────────────────────────
-- One query is in flight at a time (a tooltip hovers one row). A newer hover replaces `active`
-- with a *new* table, so the identity check `active == a` is what invalidates a stale timeout or
-- event — that alone is the supersession mechanism. (`a.idx == idx` is separate: it rejects a
-- timeout for candidate N that fires after advance() already moved on to N+1.)
local active    -- { recipeID, recipeLevel, queryID, skillLineID, candidates, idx, tooltip }

local GetProfInfo = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID

-- Skill lines to try for a recipe: the parent (base) profession first, then the recipe's own
-- (expansion-specific) one — QueryGuildMembersForRecipe wants one of these exact ids.
-- Blizzard resolves this as `parentProfessionID or professionID` and never tries the other, so
-- the parent is the likelier match and goes first; we keep the expansion id as the fallback
-- Blizzard's single-shot form has no recovery for.
local function candidateSkillLines(recipeID)
  local out, seen = {}, {}
  if GetProfInfo then
    local ok, info = pcall(GetProfInfo, recipeID)
    if ok and info then
      for _, id in ipairs({ info.parentProfessionID, info.professionID }) do
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
  local a, idx = active, active.idx
  local skillLineID = a.candidates[idx]
  local queryID = C_GuildInfo.QueryGuildMembersForRecipe(skillLineID, a.recipeID, a.recipeLevel)
  -- Documented MayReturnNothing: a nil return means no query was issued, so no event can ever
  -- answer it. Advance immediately rather than masking it as a queryID and then waiting out
  -- QUERY_TIMEOUT for a response that cannot come — that was 3s of dead air per dead candidate.
  if not queryID then advance() return end
  -- The pair onGuildRecipeResult correlates the response on.
  a.queryID, a.skillLineID = queryID, skillLineID
  -- What remains covers only "query accepted, no event arrived" — the genuine gap in Blizzard's
  -- guild data described at the top of this file, and now the rare path rather than the common one.
  C_Timer.After(QUERY_TIMEOUT, function()
    if active == a and a.idx == idx then advance() end
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
  -- The response carries the skill line it answers for as its *first* return. Both candidates
  -- query the same recipeID, so that is the only thing telling them apart: without it a late
  -- answer for candidate 1 satisfies the in-flight candidate-2 query and the crafter list is
  -- computed from the wrong skill line. Correlate on the (skillLine, recipe) pair recorded by
  -- fireCandidate, as Blizzard's own handler does.
  local postSkillLineID, postRecipeID, numMembers = GetGuildRecipeInfoPostQuery()
  postSkillLineID, postRecipeID = nonsecret(postSkillLineID), nonsecret(postRecipeID)
  -- numMembers is compared and used as a loop bound below, so it needs the guard as much as the
  -- GetGuildRecipeMember returns do; a secret one falls into the "no crafters" branch and advances.
  numMembers = nonsecret(numMembers)
  if not postRecipeID then return end
  if postSkillLineID ~= a.skillLineID then return end                          -- another candidate's answer
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
  refreshGuildRecipes()
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
---@param recipeLevel integer?  selected rank of a leveled recipe; nil (the documented Nilable
---  default) means "no particular level", which is correct in the crafting-orders context since
---  there is no schematic form to ask. NOTE: if a caller ever passes one, the result cache must
---  key on recipeID..":"..level — two levels of a recipe can have different crafters.
---@return GuildCrafterEntry[]? crafters
---@return string? state  "ready" | "pending" | nil
function ns.GuildCrafters(recipeID, tooltip, recipeLevel)
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
  primeOnce()
  active = { recipeID = recipeID, recipeLevel = recipeLevel, candidates = candidates, idx = 1, tooltip = tooltip }
  fireCandidate()
  return nil, "pending"
end
