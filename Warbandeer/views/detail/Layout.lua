---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Texture = ui.Texture
local GetItemInfo, select = GetItemInfo, select
local theme = ns.theme

-- Shared layout constants + leaf helpers for the Detail view, split out of
-- DetailView.lua so the view's row-pool / filter files (detail/Professions.lua,
-- detail/Gear.lua, detail/Filter.lua) can reference the same metrics. Everything
-- lives on `ns.detail`; each file aliases `local D = ns.detail`.
--
---@class DetailLayout
---@field [string] number             layout-metric constants (P, GAP, PANEL_W, GEAR_*, PG_*, …)
---@field gearInnerW fun(nameW: number): number   inner width of a gear row for a given name-column width
---@field gearPanelW fun(nameW: number): number   gear panel width for a given name-column width
---@field tierAtlas fun(tier: integer): string    crafted-quality tier icon atlas (1-5 stars)
---@field intentColor fun(intent: string?): number[]  bar fill tint for a crafter intent
---@field attachItemTip fun(frame: Frame)         wire a row for item-tooltip hover
---@field rarityColor fun(link: string?): number, number, number  rgb from an item link's colour prefix
---@field reqLevel fun(link: string?): integer?   required character level of an item link
---@field raceAtlas fun(char: Character): string  gender-aware race-icon atlas
---@field CHEVRON string             inline picker down-arrow markup
---@field INTENT_OPTIONS table[]     intent dropdown options

---@class Warbandeer
---@field detail DetailLayout

ns.detail = {}
local D = ns.detail

-- ─── Layout ─────────────────────────────────────────────────────────────────────
D.P, D.GAP = 12, 12              -- outer padding / section gap
D.PORTRAIT = 56                  -- class-icon portrait edge
D.STRIP_H = 56                   -- stat-card height
D.ICON_W, D.ICON_GAP = 28, 10    -- profession icon
D.BAR_W = 150                    -- labelled bar width
D.DD_GAP, D.DD_W = 12, 124       -- intent dropdown gap / width
D.ROW_PAD = 12                   -- inner padding of a profession panel
D.ROW_H, D.ROW_GAP = 44, 8       -- profession panel height / gap between panels

-- Header identity icons inserted left of the class portrait: a race icon, and
-- left of that a faction icon stacked over a role icon.
D.RACE_W = D.PORTRAIT            -- race icon edge (matches the class portrait)
D.FR_W = 24                      -- faction / role icon edge (stacked column)
D.HEADER_GAP = 6                 -- gap between header icon columns

D.PANEL_W = D.ROW_PAD + D.ICON_W + D.ICON_GAP + D.BAR_W + D.DD_GAP + D.DD_W + D.ROW_PAD
D.CONTENT_TOP = D.P + D.PORTRAIT + D.GAP            -- stat strip top
-- Secondary-stat 2×2 grid, slotted between the Item Level/Playtime cards and the
-- professions block (Crit + Mastery on top, Haste + Versatility below).
D.STATS_TOP = D.CONTENT_TOP + D.STRIP_H + D.GAP     -- stat grid top
D.STATS_ROW_H = 38                                  -- one grid row (pitch)
D.STATS_H = 2 * D.STATS_ROW_H                        -- 2×2 grid height
D.STATS_CHART = 64                                  -- secondary-stat radar edge (centred between the two cell columns)
D.PROF_HEADER_Y = D.STATS_TOP + D.STATS_H + D.GAP   -- professions header top (below the grid)

-- ─── Gear list (right column) ─────────────────────────────────────────────────
D.GEAR_PAD = 12                             -- gear panel inner padding
D.GEAR_ROW_H = 20                           -- gear row head line (icon + name + ilvl + track)
D.GEAR_UP_H = 14                            -- extra height for the suggested-upgrade sub-line
D.GEAR_HEADER_GAP = 8                       -- header → first row
D.GEAR_ICON_W, D.GEAR_ICON_GAP = 18, 8      -- left slot-icon column / gap to name
D.GEAR_ILVL_W, D.GEAR_TRACK_W = 30, 28      -- right-aligned ilvl / track columns
D.GEAR_COL_GAP = 8                          -- gap between name/ilvl/track
D.GEAR_NAME_MIN, D.GEAR_NAME_MAX = 150, 320 -- autosize clamp for the name column. Sub-line notes (upgrade / missing-enchant / empty-socket) each render on their own line, so this only needs to fit the widest single note (~one recommendation), not several joined
D.GEAR_X = D.P + D.PANEL_W + D.GAP          -- gear panel left edge

-- Width left of the name column (slot icon + gap).
D.GEAR_LEAD_W = D.GEAR_ICON_W + D.GEAR_ICON_GAP
-- Width contributed by everything right of the name column (gaps + ilvl + track).
D.GEAR_EXTRAS_W = D.GEAR_COL_GAP + D.GEAR_ILVL_W + D.GEAR_COL_GAP + D.GEAR_TRACK_W
function D.gearInnerW(nameW) return D.GEAR_LEAD_W + nameW + D.GEAR_EXTRAS_W end
function D.gearPanelW(nameW) return D.gearInnerW(nameW) + 2 * D.GEAR_PAD end

D.VIEW_WIDTH = D.GEAR_X + D.gearPanelW(D.GEAR_NAME_MIN) + D.P

-- vertical centring of each element inside a profession panel
D.ICON_Y, D.BAR_Y, D.DD_Y = (D.ROW_H - D.ICON_W) / 2, 8, (D.ROW_H - 20) / 2
D.BAR_X = D.ROW_PAD + D.ICON_W + D.ICON_GAP
D.DD_X = D.BAR_X + D.BAR_W + D.DD_GAP

-- Profession-gear sub-rows: the equipped profession tool / accessories listed
-- beneath each profession panel. Indented to line up under the progress bar, with
-- the crafted-quality tier icon right-aligned.
D.PG_ROW_H   = 18                                -- one profession-gear row
D.PG_TOP_GAP = 6                                 -- panel bottom → first gear row
D.PG_TIER_W  = 16                                -- right-aligned crafted-tier icon edge
D.PG_COL_GAP = 8                                 -- gap between name and tier icon
D.PG_INDENT  = D.BAR_X                            -- left inset within the panel
D.PG_ROW_W   = D.PANEL_W - D.ROW_PAD - D.PG_INDENT -- gear-row content width

-- Crafted-quality tier icon atlas (1-5 stars). The "-Small" variant is sized for
-- inline list use; built by string so we don't depend on the LoD Professions UI.
function D.tierAtlas(tier) return ("Professions-Icon-Quality-Tier%d-Small"):format(tier) end

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a) for the picker.
D.CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:12:12|a"

-- Intent editor options. `key = false` is the "clear" sentinel (stored as nil).
D.INTENT_OPTIONS = {
  { key = "main",      label = "Main Crafter" },
  { key = "secondary", label = "Secondary"    },
  { key = "gatherer",  label = "Gatherer"     },
  { key = false,       label = "Unset"        },
}
-- Bar fill tint per intent, so picking an intent recolours the bar. Progression is
-- independent of intent: an unset profession still shows a filled, warm-neutral bar
-- (muted tan) so real skill reads as progressed; intent only overrides the tint.
local INTENT_COLOR = {
  main      = theme.colors.orange,
  secondary = theme.colors.gold,
  gatherer  = theme.colors.green,
}
function D.intentColor(intent) return INTENT_COLOR[intent] or theme.colors.muted end

-- Re-render the open Detail view (after an enchant accept toggle) so the affected note
-- clears or returns immediately.
local function refreshDetail()
  local view = ns.MainWindow and ns.MainWindow:ShownView()
  if view and view.name == "detail" then view:OnBeforeShow(); ns.MainWindow:Fit() end
end

-- Flip the per-item enchant accept and report the new state, then refresh. Direction-
-- agnostic: prints/behaves per the resulting state.
local function applyEnchantToggle(itemID, enchantID, itemLink)
  local accepted = ns.ToggleEnchantIgnore(itemID, enchantID)
  ns.Print(accepted
    and ("accepting the enchant on %s (right-click again to undo)"):format(itemLink or "this item")
    or  ("flagging the enchant on %s again"):format(itemLink or "this item"))
  refreshDetail()
end

-- Accepting a wrong enchant silences the flag, so confirm it (an accidental right-click
-- shouldn't quietly hide a real issue). Un-accepting needs no confirm — it only re-flags.
StaticPopupDialogs["WARBANDEER_ACCEPT_ENCHANT"] = {
  text = "Accept the current enchant on %s?\nWarbandeer will stop flagging it as the wrong enchant.",
  button1 = YES,
  button2 = NO,
  OnAccept = function(self) local d = self.data; applyEnchantToggle(d.itemID, d.enchantID, d.link) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- Wire a gear/prof-gear row for hover: a row highlight plus the shared item tooltip
-- (`ns.ShowItemTooltip`). The row stores its current item link in `frame._itemLink`
-- and, for an equipped slot with a suggested upgrade, that upgrade's link in
-- `frame._upgradeLink` (both updated each time it's populated), so a single set of
-- scripts survives row pooling. We always suppress the "Upgrade for:" block here
-- (the suggestion is shown as a side-by-side comparison instead).
function D.attachItemTip(frame)
  local hi = Texture:new{
    parent = frame, layer = ui.layer.Background, color = theme.colors.hover,
    position = { All = true, Hide = true },
  }
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function()
    hi:Show()
    if frame._itemLink then ns.ShowItemTooltip(frame, frame._itemLink, frame._upgradeLink, true) end
  end)
  frame:SetScript("OnLeave", function()
    hi:Hide()
    ns.HideItemTooltip()
  end)
  -- Left-click a row carrying a suggested upgrade → flash that item in the open
  -- bags / bank (the upgrade is held gear; the equipped piece itself is never in a
  -- bag, so only `_upgradeLink` is flashable). No-op on rows without an upgrade.
  -- Right-click a row flagged with a wrong enchant → accept/un-accept that enchant on this
  -- specific item (toggles the per-item ignore), then re-render so the note clears/returns.
  -- Accepting (silencing) asks for confirmation; un-accepting (re-flagging) is immediate.
  -- No-op otherwise (`_enchMismatch` is set per render only for slots with a mismatch).
  frame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and frame._upgradeLink then ns.FlashItem(frame._upgradeLink) end
    if button == "RightButton" and frame._enchMismatch then
      local m = frame._enchMismatch
      if ns.IsEnchantIgnored(m.itemID, m.enchantID) then
        applyEnchantToggle(m.itemID, m.enchantID, frame._itemLink) -- un-accept, no confirm
      else
        local dialog = StaticPopup_Show("WARBANDEER_ACCEPT_ENCHANT", frame._itemLink or "this item")
        if dialog then dialog.data = { itemID = m.itemID, enchantID = m.enchantID, link = frame._itemLink } end
      end
    end
  end)
end

-- Rarity color pulled straight from the stored item link's color prefix, so it works
-- for any character without relying on the item being in this client's cache. Modern
-- links color by quality name (|cnIQ<n>: where n is Enum.ItemQuality); older ones use
-- the literal |cffRRGGBB hex. Handle both.
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
---@return number, number, number
function D.rarityColor(link)
  if link then
    local iq = link:match("|cnIQ(%d+):")
    if iq then
      local q = ITEM_QUALITY_COLORS[tonumber(iq)]
      if q then return q.r, q.g, q.b end
    end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    if hex then
      return tonumber(hex:sub(1, 2), 16) / 255,
             tonumber(hex:sub(3, 4), 16) / 255,
             tonumber(hex:sub(5, 6), 16) / 255
    end
  end
  local t = theme.colors.text
  return t[1], t[2], t[3]
end

-- Required character level of an item link (5th GetItemInfo return), or nil when
-- the item isn't cached on this client (alt's bank/warband gear may not be).
---@return integer?
function D.reqLevel(link) return link and select(5, GetItemInfo(link)) or nil end

-- Race-file token → race-icon atlas token where the two differ (the file token
-- from UnitRace isn't always the atlas spelling).
local RACE_ATLAS_FIX = {
  scourge            = "undead",
  highmountaintauren = "highmountain",
  lightforgeddraenei = "lightforged",
  zandalaritroll     = "zandalari",
  harronir           = "haranir",
  earthendwarf       = "earthen",
}

-- Gender-aware race-icon atlas for a character. `char.race` is the race file token
-- (e.g. "Human", "HighmountainTauren"); `char.sex` is 2=male / 3=female (captured by
-- Warbandeer_Characters for the logged-in character; defaults to male for alts not
-- yet seen since the field was added). Atlas tokens are the lowercased race file,
-- with a handful of exceptions (RACE_ATLAS_FIX); we use the 128px hi-res variant.
---@return string
function D.raceAtlas(char)
  local race = (char.race or ""):lower()
  race = RACE_ATLAS_FIX[race] or race
  return ("raceicon128-%s-%s"):format(race, char.sex == 3 and "female" or "male")
end
