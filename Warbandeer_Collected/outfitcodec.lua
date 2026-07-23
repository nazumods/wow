---@type Warbandeer_Collected
local ns = select(2, ...)
local concat, floor = table.concat, math.floor

-- The `/customset v1 …` interchange codec — Blizzard's own shareable outfit string,
-- encoded and decoded here rather than borrowed.
--
-- Why reimplemented: `TransmogUtil.CreateCustomSetSlashCommand` / `ParseCustomSetSlashCommand`
-- live in **Blizzard_TransmogShared**, whose .toc carries `## LoadOnDemand: 1` — so they are
-- absent until something pulls that addon in, and an addon must not assume they exist. The
-- format is fixed and tiny, so owning it is cheaper than a LoadAddOn dance, and it keeps this
-- file free of WoW API calls so `spec/outfitcodec_spec.lua` can unit-test it.
--
-- The wire format (17 comma-separated ids, one `v1` line):
--
--   /customset v1 7019,7017,0,0,7022,0,0,7015,7020,7016,7018,7021,70216,0,0,0,0
--
--   Head.app, Shoulder.app, Shoulder.secondary, Back.app, Chest.app, Body(shirt).app,
--   Tabard.app, Wrist.app, Hand.app, Waist.app, Legs.app, Feet.app,
--   MainHand.app, MainHand.secondary, MainHand.illusion, OffHand.app, OffHand.illusion
--
-- Shirt and Tabard are already first-class in the format — the addon side is what's catching up.
--
-- Deliberately NOT done here (both need the WoW API, so they live in outfit.lua): validating
-- that a decoded shoulder secondary really is a shoulder appearance, and checking whether the
-- player has collected each source.

-- The slots the format carries, in emission order. Mirrors Blizzard's `TransmogSlotOrder`;
-- note it omits the non-transmoggable slots (neck, rings, trinkets, ranged), so the encoded
-- string is 13 slots wide, not 19.
local SLOT_ORDER = {
  INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_BACK, INVSLOT_CHEST, INVSLOT_BODY, INVSLOT_TABARD,
  INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET,
  INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}

-- 13 slot appearances + the two secondaries (shoulder, main-hand) + the two illusions
-- (main-hand, off-hand). A string with any other count is rejected rather than guessed at.
local VALUE_COUNT = 17

---@class Warbandeer_Collected
---@field OutfitSlotOrder number[]  inventory slot ids the /customset format carries, in wire order
ns.OutfitSlotOrder = SLOT_ORDER

-- Build one ItemTransmogInfo. Uses Blizzard's `ItemUtil` (always loaded — Blizzard_FrameXMLUtil
-- is NOT LoadOnDemand) so the objects carry the real mixin, which the compose path in outfit.lua
-- needs for `:ConfigureSecondaryForMainHand`. The plain-table fallback exists solely so this file
-- loads under busted, where no WoW globals exist; it carries the same three fields the format and
-- the C setters read.
---@param appearanceID number
---@param secondaryAppearanceID number?
---@param illusionID number?
---@return table
function ns.NewTransmogInfo(appearanceID, secondaryAppearanceID, illusionID)
  if ItemUtil and ItemUtil.CreateItemTransmogInfo then
    return ItemUtil.CreateItemTransmogInfo(appearanceID, secondaryAppearanceID, illusionID)
  end
  return {
    appearanceID = appearanceID,
    secondaryAppearanceID = secondaryAppearanceID or 0,
    illusionID = illusionID or 0,
  }
end

---An all-empty outfit list — one zeroed entry per equippable slot, densely indexed by
---inventory slot id (so `list[INVSLOT_MAINHAND]` addresses the main hand). The slots the
---wire format doesn't carry stay zeroed and simply never round-trip.
---@return table[]
function ns.EmptyOutfitList()
  local list = {}
  for i = 1, INVSLOT_LAST_EQUIPPED do list[i] = ns.NewTransmogInfo(0, 0, 0) end
  return list
end

---Encode an outfit list as the `/customset v1 …` string.
---
---The off-hand is emitted verbatim rather than collapsed to `-1` for a paired Legion artifact:
---Blizzard's encoder guards that case with a local that is declared and never assigned (so it
---never fires), and its decoder has no matching branch — emitting `-1` would produce a string
---the game's own parser stores as a literal `-1` appearance. Matching the reference
---implementation exactly is what keeps our strings interchangeable with the game's.
---@param list table[]  as produced by ns.EmptyOutfitList / ns.ComposeOutfit
---@return string
function ns.EncodeOutfit(list)
  local out = {}
  for _, slotID in ipairs(SLOT_ORDER) do
    local info = list[slotID] or ns.NewTransmogInfo(0, 0, 0)
    out[#out + 1] = info.appearanceID or 0
    if slotID == INVSLOT_SHOULDER or slotID == INVSLOT_MAINHAND then
      out[#out + 1] = info.secondaryAppearanceID or 0
    end
    if slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND then
      out[#out + 1] = info.illusionID or 0
    end
  end
  return "/customset v1 " .. concat(out, ",")
end

-- Split a comma-separated id list into integers. Hand-rolled rather than calling
-- C_Transmog.ExtractTransmogIDList so this file stays WoW-free (and testable); the ids are
-- plain signed integers, so `tonumber` + an integrality check is the whole grammar. Returns nil
-- on the first value that isn't one.
---@param body string
---@return number[]?
local function splitIDs(body)
  local out = {}
  for field in (body .. ","):gmatch("([^,]*),") do
    local n = tonumber((field:gsub("%s", "")))
    if not n or floor(n) ~= n then return nil end
    out[#out + 1] = n
  end
  return out
end

---Which interchange format a pasted string is, so a caller can route it to the right decoder:
---`"link"` for a chat hyperlink (only the game can read those), `"v1"` for the `/customset`
---string (decoded here), nil for neither.
---
---Sniffed up front rather than discovered by trying both decoders, so a malformed *link* is
---refused as a malformed link instead of as "not a /customset v1 string". Pure string work, so
---the routing decision is unit-testable even though one of its two branches isn't.
---
---The link is tested first and deliberately: a hyperlink's display text is arbitrary and could
---itself begin `v1 `, while a `/customset` string can only ever contain `transmogcustomset` as
---part of a value, which isn't a whole number and gets refused downstream anyway.
---@param str string
---@return string?  "link" | "v1" | nil
function ns.OutfitInputKind(str)
  if type(str) ~= "string" then return nil end
  local body = str:gsub("^%s+", ""):gsub("%s+$", "")
  -- Both shapes a link arrives in: the full `|H…|h[…]|h` a shift-click inserts, and the bare
  -- link data someone re-typed out of one.
  if body:find("|Htransmogcustomset:", 1, true) or body:match("^transmogcustomset:") then
    return "link"
  end
  body = body:gsub("^/customset%s+", "")
  if body:match("^v1%s+(.+)$") then return "v1" end
  return nil
end

---Decode a `/customset v1 …` string into an outfit list.
---
---Accepts the full slash command, a bare `v1 …` payload, and surrounding whitespace — the three
---shapes a string actually arrives in when pasted between players. Anything else is refused with
---a reason rather than a partially-filled list, so a caller can surface it.
---@param str string
---@return table[]? list, string? err  exactly one is non-nil
function ns.DecodeOutfit(str)
  if type(str) ~= "string" then return nil, "expected a string" end
  local body = str:gsub("^%s+", ""):gsub("%s+$", "")
  body = body:gsub("^/customset%s+", "")
  local payload = body:match("^v1%s+(.+)$")
  if not payload then return nil, "not a /customset v1 string" end

  local ids = splitIDs(payload)
  if not ids then return nil, "contains a value that isn't a whole number" end
  if #ids ~= VALUE_COUNT then
    return nil, ("expected %d values, got %d"):format(VALUE_COUNT, #ids)
  end

  local read = 0
  local function next_()
    read = read + 1
    return ids[read]
  end

  local list = ns.EmptyOutfitList()
  for _, slotID in ipairs(SLOT_ORDER) do
    local info = list[slotID]
    info.appearanceID = next_()
    if slotID == INVSLOT_SHOULDER or slotID == INVSLOT_MAINHAND then
      info.secondaryAppearanceID = next_()
    end
    -- An illusion id is clamped at 0: the main-hand secondary legitimately carries -1
    -- ("an ordinary weapon, not a paired artifact"), but there is no negative illusion, and a
    -- stray negative would otherwise be handed to the model as a real id.
    if slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND then
      local v = next_()
      info.illusionID = v > 0 and v or 0
    end
  end
  return list
end
