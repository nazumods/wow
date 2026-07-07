---@class ShadowsOfUI_Artisan: AddOn
local ns = LibNAddOn(...)

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

local insert, sort = table.insert, table.sort
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo

-- Current-expansion artisan crafting currency, keyed by PARENT skill line ID. In Midnight
-- this is the per-profession "Artisan's ... Moxie" family — every profession has one,
-- gathering professions included. Mirrors Warbandeer_Characters/data/artisancurrency.lua
-- (kept here too for the live logged-in read, as ShadowsOfUI-Known duplicates its skill
-- map); keep the two tables in sync, and update both each expansion.
ns.ARTISAN_CURRENCIES = {
  [171] = 3256, -- Alchemy        — Artisan Alchemist's Moxie
  [164] = 3257, -- Blacksmithing  — Artisan Blacksmith's Moxie
  [333] = 3258, -- Enchanting     — Artisan Enchanter's Moxie
  [202] = 3259, -- Engineering    — Artisan Engineer's Moxie
  [182] = 3260, -- Herbalism      — Artisan Herbalist's Moxie
  [773] = 3261, -- Inscription    — Artisan Scribe's Moxie
  [755] = 3262, -- Jewelcrafting  — Artisan Jewelcrafter's Moxie
  [165] = 3263, -- Leatherworking — Artisan Leatherworker's Moxie
  [186] = 3264, -- Mining         — Artisan Miner's Moxie
  [393] = 3265, -- Skinning       — Artisan Skinner's Moxie
  [197] = 3266, -- Tailoring      — Artisan Tailor's Moxie
}

local PROF_SLOTS = { "primary", "secondary", "fishing", "cooking" }

-- Whether a character has the profession with this parent skill line ID.
---@param toon Character
---@param skillLineID integer
local function hasProf(toon, skillLineID)
  local profs = toon.basic and toon.basic.professions
  if not profs then return false end
  for _, slot in ipairs(PROF_SLOTS) do
    local p = profs[slot]
    if p and p.skillID == skillLineID then return true end
  end
  return false
end

-- Profession intent rank from Warbandeer's WarbandeerDB (optional dependency): main = 1,
-- secondary = 2, everything else (gatherer / unset / no Warbandeer installed) = 3. Same
-- helper shape as ShadowsOfUI-Known so the two addons order alts consistently.
local INTENT_RANK = { main = 1, secondary = 2 }
local function intentRank(charName, skillLineID)
  local forChar = WarbandeerDB and WarbandeerDB.profIntent and WarbandeerDB.profIntent[charName]
  return INTENT_RANK[forChar and forChar[skillLineID]] or 3
end

---@class ArtisanEntry
---@field name string
---@field classKey string
---@field quantity integer
---@field rank integer        intent rank (1 main, 2 secondary, 3 other) for ordering
---@field isCurrent boolean   the logged-in character (its quantity is live, not cached)

-- Account-wide breakdown of the artisan currency for one profession: every character that
-- has the profession and how much currency it holds. The logged-in character's amount is
-- read live (GetCurrencyInfo); alts use the Warbandeer_Characters cache (nil → 0 until that
-- alt has logged in since the broker shipped). Ordered main -> secondary -> other, then
-- quantity desc, then name. Returns nil when the skill line has no mapped currency.
---@param skillLineID integer
---@return ArtisanEntry[]?
function ns.BuildBreakdown(skillLineID)
  local currencyId = ns.ARTISAN_CURRENCIES[skillLineID]
  if not currencyId then return nil end
  local api = ns.api
  if not api or not api.GetAllCharacters then return nil end

  local current = api:GetCurrentCharacter()
  local liveInfo = GetCurrencyInfo(currencyId)
  local liveQty = liveInfo and liveInfo.quantity or 0

  local list = {}
  for _, toon in ipairs(api:GetAllCharacters()) do
    if hasProf(toon, skillLineID) then
      local isCurrent = toon.name == current
      local qty
      if isCurrent then
        qty = liveQty
      else
        local entry = toon.artisanCurrency and toon.artisanCurrency.data
          and toon.artisanCurrency.data[skillLineID]
        qty = entry and entry.quantity or 0
      end
      insert(list, {
        name      = toon.name,
        classKey  = toon.classKey,
        quantity  = qty,
        rank      = intentRank(toon.name, skillLineID),
        isCurrent = isCurrent,
      })
    end
  end
  sort(list, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
    return a.name < b.name
  end)
  return list
end

-- /sartisan [name] — dump the breakdown for each crafting profession (testing aid, since
-- tooltip text can't be copied). With no name, reports the logged-in character's professions.
SLASH_SUI_ARTISAN1 = "/sartisan"
SlashCmdList["SUI_ARTISAN"] = function(msg)
  local api = ns.api
  if not api or not api.GetAllCharacters then ns.Print("Warbandeer data not ready.") return end
  local who = msg and msg:match("%S+")
  local toon = who and api:GetCharacterData(who) or api:GetCharacterData()
  if not toon then ns.Print("No character named", who) return end

  local any = false
  for skillLineID in pairs(ns.ARTISAN_CURRENCIES) do
    if hasProf(toon, skillLineID) then
      any = true
      local info = GetCurrencyInfo(ns.ARTISAN_CURRENCIES[skillLineID])
      ns.Print(("[%d] %s, account-wide:"):format(skillLineID, info and info.name or "?"))
      for _, e in ipairs(ns.BuildBreakdown(skillLineID) or {}) do
        ns.Print(("  %s%s: %d"):format(e.name, e.isCurrent and " (live)" or "", e.quantity))
      end
    end
  end
  if not any then ns.Print(toon.name, "has no crafting profession with a mapped currency.") end
end
