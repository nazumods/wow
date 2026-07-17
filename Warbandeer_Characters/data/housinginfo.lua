---@type Warbandeer_Characters
local ns = select(2, ...)
local pairs = pairs

-- Pure shapes + shaping for the per-character neighborhood-endeavor tracker (issue #550). The
-- capture that fills these (WoW housing/initiative APIs, events, the /wbc dump housing probe) lives
-- in data/housing.lua; this file is WoW-API-free, so the shapers are unit-tested (spec/housing_spec.lua).
--
-- What's per-character vs account-wide (the #550 in-game probes settled this): only the SUBSCRIPTION
-- — which endeavor a character is actively feeding — is per-character. House favor/level and the
-- endeavor progress are account-wide PER HOUSE (identical for every character), so they're cached on
-- the neighborhood/house, not the character, and surfaced once in the Overview. "House XP Available"
-- (GetAvailableHouseXP) is a countdown of what you can STILL earn (not a count-up total), so it's
-- stored as `xp` but shown only in the endeavor tooltip, never as a headline number.

-- Account-wide neighborhood identity + its (account-wide) endeavor state. *Which* house a
-- neighborhood belongs to (Horde vs Alliance) is account-global; title/progress/reset are the
-- house's shared endeavor, readable only for the active neighborhood so captured whenever any
-- character is subscribed to it.
---@class HousingNeighborhood
---@field isAlliance boolean?  absolute faction of the neighborhood (nil until resolved)
---@field name string?         neighborhood display name
---@field title string?        current endeavor title
---@field progress number?     current endeavor progress toward the neighborhood goal (counts up)
---@field required number?     endeavor progress required for the goal
---@field resetAt integer?     server-time epoch the endeavor cycle resets
---@field xp number?           House XP still earnable this cycle (GetAvailableHouseXP; a countdown)

---@class HousingHouse
---@field neighborhoodGUID string?
---@field name string?
---@field level integer?
---@field favor integer?

---@class HousingAccount
---@field neighborhoods table<string, HousingNeighborhood>  keyed by neighborhoodGUID
---@field houses table<string, HousingHouse>                keyed by houseGUID

---@class WarbandeerCharactersDB
---@field housing HousingAccount?

-- Per-character endeavor state (a `housing` broker with one field): only which neighborhood the
-- character is actively feeding. The account-wide house data lives on the neighborhood, not here.
---@class HousingChar
---@field active string?  the neighborhoodGUID this character is currently feeding (its endeavor)

---@class Character
---@field housing HousingChar?

-- Pure: resolve a character's active neighborhood against the account neighborhood map into the
-- Endeavors column's shape — which faction house the character is feeding + that endeavor's title.
-- nil when the character has no resolvable active endeavor (so the column blanks the cell).
---@class Warbandeer_Characters
---@field ShapeHousing fun(active: string?, neighborhoods: table<string, HousingNeighborhood>?): { active: ("alliance"|"horde"), title: string? }?
function ns.ShapeHousing(active, neighborhoods)
  neighborhoods = neighborhoods or {}
  local nb = active and neighborhoods[active]
  if not nb or nb.isAlliance == nil then return nil end
  return { active = nb.isAlliance and "alliance" or "horde", title = nb.title }
end

-- Pure: join the account-wide house records (level/favor) with their neighborhoods (faction +
-- endeavor) into the Overview's per-faction house views. Either side may be nil until captured.
---@class HouseView
---@field name string?
---@field level integer?
---@field favor integer?
---@field title string?
---@field progress number?
---@field required number?
---@field resetAt integer?
---@field xp number?

---@class Warbandeer_Characters
---@field ShapeHouses fun(houses: table<string, HousingHouse>?, neighborhoods: table<string, HousingNeighborhood>?): { alliance: HouseView?, horde: HouseView? }
function ns.ShapeHouses(houses, neighborhoods)
  houses = houses or {}
  neighborhoods = neighborhoods or {}
  local out = {}
  for _, h in pairs(houses) do
    local nb = h.neighborhoodGUID and neighborhoods[h.neighborhoodGUID]
    if nb and nb.isAlliance ~= nil then
      out[nb.isAlliance and "alliance" or "horde"] = {
        name = h.name, level = h.level, favor = h.favor,
        title = nb.title, progress = nb.progress, required = nb.required, resetAt = nb.resetAt, xp = nb.xp,
      }
    end
  end
  return out
end
