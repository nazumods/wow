local _, ns = ...
local ui = ns.ui
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local insert, sort = table.insert, table.sort

-- Expansion name abbreviations for the hover tooltip.
local EXP_ABBR = {
  ["Vanilla"]                = "Clsc",
  ["Classic"]                = "Clsc",
  ["The Burning Crusade"]    = "TBC",
  ["Burning Crusade"]        = "TBC",
  ["Wrath of the Lich King"] = "WotLK",
  ["Cataclysm"]              = "Cata",
  ["Mists of Pandaria"]      = "MoP",
  ["Warlords of Draenor"]    = "WoD",
  ["Legion"]                 = "Leg",
  ["Battle for Azeroth"]     = "BfA",
  ["Shadowlands"]            = "SL",
  ["Dragonflight"]           = "DF",
  ["The War Within"]         = "TWW",
}

local TRANSPARENT = {color = ns.Colors.TransparentBlack}
-- Per-character group backgrounds: alternate between two shades so rows belonging
-- to the same character read as a single visual block.
local CHAR_BG = {
  {color = {0, 0, 0, 0.35}},
  {color = {0, 0, 0, 0.15}},
}

local COL_INFO = {
  { width = 20,  backdrop = TRANSPARENT },                                          -- faction icon
  { name = "Character",  width = 110, backdrop = TRANSPARENT },
  { width = 20,  backdrop = TRANSPARENT },                                          -- profession icon
  { name = "Profession", width = 110, backdrop = TRANSPARENT },
  { name = "Skill",      width = 75,  backdrop = TRANSPARENT, justifyH = ui.justify.Right },
  { name = "Spec Pts",   width = 55,  backdrop = TRANSPARENT, justifyH = ui.justify.Right },
}

local TABLE_WIDTH = 0
for _, c in ipairs(COL_INFO) do TABLE_WIDTH = TABLE_WIDTH + c.width end

-- Profession slots in display order: primary slots first, then secondary.
local PROF_SLOTS = {
  { field = "primary",   isPrimary = true  },
  { field = "secondary", isPrimary = true  },
  { field = "fishing",   isPrimary = false },
  { field = "cooking",   isPrimary = false },
}

-- ============================================================================
-- Cell builders
-- ============================================================================

local function getNameCell(toon)
  local current = ns.api.GetCurrentCharacter()
  local text = toon.name
  if toon.name == current then
    text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14:14|t " .. text
  end
  return {
    text  = text,
    color = ns.Colors[toon.classKey],
    onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine(toon.realm)
      if toon.basic.specialization and toon.basic.specialization.active then
        ui.tip:AddLine(toon.basic.specialization.active)
      end
      ui.tip:Show()
    end,
    onLeave = function() ui.tip:Hide() end,
  }
end

local function getSkillCell(prof)
  if prof.skillLevel == nil then return "" end
  local atMax = prof.skillLevel >= prof.maxSkill
  return {
    text  = prof.skillLevel .. "/" .. prof.maxSkill,
    color = atMax and DIM_GREEN_FONT_COLOR or NORMAL_FONT_COLOR,
  }
end

-- Returns the Spec Pts cell for a primary profession.  When expansion data is
-- cached the cell gains a hover tooltip showing the per-expansion breakdown.
local function getSpecCell(prof, detail)
  if prof.skillID == nil then return "" end

  local cell
  if detail and detail.specPoints ~= nil then
    cell = { text = detail.specPoints .. " pts", color = { 1, 0.80, 0.27 } }
  else
    cell = { text = "—", color = DISABLED_FONT_COLOR }
  end

  if detail and detail.expansions then
    local expansions = detail.expansions  -- capture for closure
    cell.onEnter = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      ui.tip:AddLine("Expansion Skills", 1, 0.82, 0)
      for _, exp in ipairs(expansions) do
        local abbr  = EXP_ABBR[exp.name] or exp.name
        local maxed = exp.skillLevel >= exp.maxSkillLevel
        ui.tip:AddLine(
          "  " .. abbr .. ": " .. exp.skillLevel .. "/" .. exp.maxSkillLevel,
          maxed and DIM_GREEN_FONT_COLOR or NORMAL_FONT_COLOR
        )
      end
      ui.tip:Show()
    end
    cell.onLeave = function() ui.tip:Hide() end
  end

  return cell
end

-- ============================================================================
-- View
-- ============================================================================

---@class ProfsView: Frame
local ProfsView = Class(Frame, function(self)
  self.table = TableFrame:new{
    parent   = self,
    colInfo  = COL_INFO,
    position = { TopLeft = {} },
  }
  self.table.data = {}
  self:Width(TABLE_WIDTH)
  self:Height(self.table:Height())
end, {
  name   = "profs",
  _title = "Professions",
})
ProfsView.name = "profs"
ns.views.ProfsView = ProfsView

---@return Character[]
function ProfsView:GetCharacters()
  local toons = ns.api.GetAllCharacters()
  toons = ns.lua.lists.filter(toons, function(t) return not t.IsLegionTimerunner end)
  sort(toons, function(a, b)
    if a.basic.level ~= b.basic.level then return a.basic.level > b.basic.level end
    if a.equipment.ilvl ~= b.equipment.ilvl then return a.equipment.ilvl > b.equipment.ilvl end
    return a.name < b.name
  end)
  return toons
end

---Rebuild table content and resize the view.  Called automatically by
---Region:Show() before the frame becomes visible.
function ProfsView:OnBeforeShow()
  local rowInfos = {}
  local rowData  = {}
  local bgIdx    = 1

  for _, toon in ipairs(self:GetCharacters()) do
    local profs = toon.basic.professions
    if profs then
      local firstRow = true

      for _, slot in ipairs(PROF_SLOTS) do
        local prof = profs[slot.field]
        if prof then
          local detail = toon.professions and
                         toon.professions.details and
                         toon.professions.details[prof.skillID]

          insert(rowInfos, { backdrop = CHAR_BG[bgIdx] })
          insert(rowData, {
            -- faction icon: only on the character's first profession row
            firstRow and (toon.isAlliance and ns.icons.AllianceLight or ns.icons.HordeLight) or "",
            -- character name: same; cell is reused as a single visual unit
            firstRow and getNameCell(toon) or "",
            -- profession icon
            prof.icon and { path = prof.icon, position = { TopLeft = {1,-1}, BottomRight = {-1,1} } } or "",
            -- profession name
            { text = prof.name, color = slot.isPrimary and NORMAL_FONT_COLOR or DISABLED_FONT_COLOR },
            -- skill level
            getSkillCell(prof),
            -- spec points (primary only; secondaries have no spec tree)
            slot.isPrimary and getSpecCell(prof, detail) or "",
          })

          firstRow = false
        end
      end

      -- Only advance the background alternation when the character had professions.
      if not firstRow then
        bgIdx = bgIdx % 2 + 1
      end
    end
  end

  -- Grow the row pool for any new rows; update the backdrop on existing ones
  -- (character ordering can change between sessions).
  for i, info in ipairs(rowInfos) do
    if not self.table.rows[i] then
      self.table:addRow(info)
    else
      self.table.rows[i]:backdropColor(unpack(info.backdrop.color))
    end
  end

  self.table.data = rowData
  self.table:update()

  self:Width(self.table:Width())
  self:Height(self.table:Height())
end
