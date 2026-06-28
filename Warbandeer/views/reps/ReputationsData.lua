---@type Warbandeer
local ns = select(2, ...)
local floor = math.floor
local unpack = unpack
local Colors = ns.Colors

-- Shared layout constants, the categoryId→release map, and the inline-colour cell
-- helpers for the Reputations view. Exposed on `ns.reps` (loaded before
-- ReputationsView.lua) so the view shell + its render methods share one source.

local ROW_H, CONTENT_W, SCROLLBAR_W = 24, 480, 20
local ICON, SIDE, STAND_W = 18, 16, 96
local MAX_H = 18 * ROW_H -- viewport cap; pages taller than this scroll

-- categoryId (top-level reputation header factionID) → Collected release index.
local REL = {
  [1118] = 1,  -- Classic (Vanilla)
  [980]  = 2,  -- The Burning Crusade
  [1097] = 3,  -- Wrath of the Lich King
  [1162] = 4,  -- Cataclysm
  [1245] = 5,  -- Mists of Pandaria
  [1444] = 6,  -- Warlords of Draenor
  [1834] = 7,  -- Legion
  [2104] = 8,  -- Battle for Azeroth
  [2414] = 9,  -- Shadowlands
  [2506] = 10, -- Dragonflight
  [2569] = 11, -- The War Within
  [2698] = 12, -- Midnight
}

-- Fallback expansion names (parallel to release index) when the Collected addon — the
-- source of the names + badge icons — isn't loaded.
local EXP_NAMES = {
  "Vanilla", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm",
  "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
  "Shadowlands", "Dragonflight", "The War Within", "Midnight",
}

local END, MUTED = "|r", "|cff9d9d9d"
local GREEN, WHITE, PARAGON = "|cff66cc66", "|cffe6e6e6", "|cff66b3ff"

-- Inline class-colour escape for a character name in the standings tooltip.
local function classCode(key)
  local c = key and Colors[key]
  if not c then return "|cffffffff" end
  return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

-- The display label, repairing a stale "Renown %d" label cached before the broker
-- formatted it (the level lives in `rank`, so substitute it in). Newer scans store the
-- finished string, where this is a no-op.
local function cleanLabel(s)
  local l = s.label or ""
  if l:find("%%d") then l = l:gsub("%%d", tostring(s.rank or 0)) end
  return l
end

-- Coloured standing text for one entry: green at the cap, white otherwise, with a blue
-- Paragon marker when earning paragon rewards.
local function standingText(s)
  local t = (s.done and GREEN or WHITE) .. cleanLabel(s) .. END
  if s.paragon then t = t .. " " .. PARAGON .. "Paragon" .. END end
  return t
end

-- The faction's own emblem: major-faction texture kit, friendship icon, else a generic
-- reputation icon.  Resolved live by ID (works for offline alts' factions too).
local function factionIconSpec(fid)
  if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(fid) then
    local mf = C_MajorFactions.GetMajorFactionData(fid)
    if mf and mf.textureKit then
      local atlas = ("majorfactions_icons_%s512"):format(mf.textureKit)
      if C_Texture.GetAtlasInfo(atlas) then return { atlas = atlas } end
    end
  end
  local friend = C_GossipInfo.GetFriendshipReputation(fid)
  if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0
     and friend.texture and friend.texture ~= 0 then
    return { path = friend.texture }
  end
  return { path = "Interface\\Icons\\Achievement_Reputation_01" }
end

-- Point a pooled Texture at an icon spec ({atlas} | {path, coords?, vertexColor?}).
local function applyIcon(tex, spec)
  if spec.atlas then
    tex:Atlas(spec.atlas, false)
    tex:SetVertexColor(1, 1, 1, 1)
  else
    tex:Texture(spec.path)
    if spec.coords then tex:Coords(unpack(spec.coords)) else tex:Coords(0, 1, 0, 1) end
    if spec.vertexColor then tex:SetVertexColor(unpack(spec.vertexColor)) else tex:SetVertexColor(1, 1, 1, 1) end
  end
end

---@class Warbandeer
---@field reps table  shared constants + cell helpers for the Reputations view (see views/reps/ReputationsData.lua)
ns.reps = {
  ROW_H = ROW_H, CONTENT_W = CONTENT_W, SCROLLBAR_W = SCROLLBAR_W,
  ICON = ICON, SIDE = SIDE, STAND_W = STAND_W, MAX_H = MAX_H,
  REL = REL, EXP_NAMES = EXP_NAMES, END = END, MUTED = MUTED,
  classCode = classCode, cleanLabel = cleanLabel, standingText = standingText,
  factionIconSpec = factionIconSpec, applyIcon = applyIcon,
}
