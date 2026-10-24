-- Loads the REAL ShadowsOfUI-Artisan/core.lua against a fake warband so ns.BuildBreakdown can be
-- driven out of game. `opts.toons` is the Character[] ns.api:GetAllCharacters() returns, `opts.current`
-- the logged-in character's name, `opts.live` the logged-in character's live currency quantity
-- (nil = GetCurrencyInfo answers nothing), `opts.intent` WarbandeerDB.profIntent
-- ([name][skillLineID] = "main" | "secondary"). Path is relative to the AddOns root.
local M = {}

---@param opts { toons: table[]?, current: string?, live: integer?, intent: table?, noApi: boolean? }?
---@return table ns
function M.load(opts)
  opts = opts or {}
  local color = { WrapTextInColorCode = function(_, t) return t end }
  _G.NORMAL_FONT_COLOR = color
  _G.SlashCmdList = {}
  _G.WarbandeerDB = opts.intent and { profIntent = opts.intent } or nil
  _G.C_CurrencyInfo = {
    GetCurrencyInfo = function() return opts.live and { quantity = opts.live, name = "Moxie" } or nil end,
  }
  local ns = { RegisterChangelog = function() end, Print = function() end }
  if not opts.noApi then
    ns.api = {
      GetAllCharacters = function() return opts.toons or {} end,
      GetCurrentCharacter = function() return opts.current end,
    }
  end
  _G.LibNAddOn = function() return ns end
  assert(loadfile("ShadowsOfUI-Artisan/core.lua"))("ShadowsOfUI-Artisan", ns)
  return ns
end

local TAILORING, MINING = 197, 186
M.TAILORING, M.MINING = TAILORING, MINING

---A character holding `skillIDs` in the given profession slots, optionally with cached artisan currency
---(`cached[skillLineID] = quantity`).
---@param name string
---@param slots table<string, integer>  e.g. { primary = 197 }
---@param cached table<integer, integer>?
function M.toon(name, slots, cached)
  local profs = {}
  for slot, skillID in pairs(slots) do profs[slot] = { skillID = skillID } end
  local t = { name = name, classKey = "Mage", basic = { professions = profs } }
  if cached then
    local data = {}
    for skillLineID, qty in pairs(cached) do data[skillLineID] = { quantity = qty } end
    t.artisanCurrency = { data = data }
  end
  return t
end

return M
