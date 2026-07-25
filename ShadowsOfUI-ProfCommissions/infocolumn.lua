---@type ShadowsOfUI_ProfCommissions
local ns = select(2, ...)

---@class ShadowsOfUI_ProfCommissions
---@field ReplaceReagentsColumn fun(page: table)

-- ─── "Info" column: first-craft bonus + reagent provision ────────────────────────────────────
--
-- A second glanceable read for each order: whether crafting it earns the first-craft bonus, and
-- whether the customer supplies the reagents or you do. Rendered as a new fixed-width column of two
-- status icons on the crafter orders browse list. Data comes straight off the order:
-- `spellID` → C_TradeSkillUI.IsRecipeFirstCraft, and `reagentState` (All/Some/None).

local COLUMN_HEADER = "Info"

-- Red ⊗ marker (copy of LibNUI's unresolved.tga; this addon is standalone, no LibNUI dep) shown
-- in place of the first-craft book when the recipe is unlearned — a bonus you can't claim yet.
local UNLEARNED_ICON = [[Interface\AddOns\ShadowsOfUI-ProfCommissions\media\unresolved.tga]]

-- Reagent-provision icon + tooltip per reagentState. All = customer covers everything (good);
-- Some/None = you supply reagents (warning, escalating).
local REAGENT_ICON = {
  [Enum.CraftingOrderReagentsType.All]  = { atlas = "Capacitance-General-WorkOrderCheckmark" },
  [Enum.CraftingOrderReagentsType.Some] = { atlas = "NPE_ExclamationPoint" },
  [Enum.CraftingOrderReagentsType.None] = { atlas = "NPE_ExclamationPoint", r = 1, g = 0.4, b = 0.35 },
}
local REAGENT_TIP = {
  [Enum.CraftingOrderReagentsType.All]  = { "The customer provides all reagents.", GREEN_FONT_COLOR },
  [Enum.CraftingOrderReagentsType.Some] = { "You provide some of the reagents.", NORMAL_FONT_COLOR },
  [Enum.CraftingOrderReagentsType.None] = { "You will be providing all of the reagents.", RED_FONT_COLOR },
}

local function tipLine(text, color, wrap)
  GameTooltip:AddLine(text, color.r, color.g, color.b, wrap)
end

ShadowsOfUI_ProfCommissions_InfoCellMixin = CreateFromMixins(TableBuilderCellMixin)

function ShadowsOfUI_ProfCommissions_InfoCellMixin:Populate(rowData)
  local order = rowData and rowData.option
  local spellID = order and order.spellID

  -- First-craft bonus only matters if you can actually make the recipe. IsRecipeFirstCraft is
  -- true for anything you've never crafted — including recipes you haven't *learned* — so gate on
  -- GetRecipeInfo().learned (Blizzard's own claim check reads the same field) and swap in the red ⊗
  -- unlearned marker rather than dangling a first-craft bonus that isn't claimable yet.
  local info = spellID and C_TradeSkillUI.GetRecipeInfo(spellID)
  if spellID and (not info or not info.learned) then
    self.FirstCraft:SetTexture(UNLEARNED_ICON)
    self.FirstCraft:SetTexCoord(0, 1, 0, 1) -- clear any atlas crop a prior first-craft state left on this recycled cell
    self.FirstCraft:Show()
    self._firstCraftState = "unlearned"
  elseif spellID and C_TradeSkillUI.IsRecipeFirstCraft(spellID) then
    self.FirstCraft:SetAtlas("Professions_Icon_FirstTimeCraft")
    self.FirstCraft:Show()
    self._firstCraftState = "first"
  else
    self.FirstCraft:Hide()
    self._firstCraftState = nil
  end

  local cfg = order and order.reagentState and REAGENT_ICON[order.reagentState]
  if cfg then
    self.Reagents:SetAtlas(cfg.atlas)
    self.Reagents:SetVertexColor(cfg.r or 1, cfg.g or 1, cfg.b or 1)
    self.Reagents:Show()
  else
    self.Reagents:Hide()
  end
end

function ShadowsOfUI_ProfCommissions_InfoCellMixin:OnEnter()
  local row = self:GetParent()
  if row.HighlightTexture then row.HighlightTexture:Show() end

  local order = self.rowData and self.rowData.option
  if not order then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local shown = false
  if self._firstCraftState == "unlearned" then
    tipLine("Recipe Unlearned", NORMAL_FONT_COLOR)
    tipLine("You haven't learned this recipe yet.", RED_FONT_COLOR, true)
    shown = true
  elseif self._firstCraftState == "first" then
    tipLine("First Craft", NORMAL_FONT_COLOR)
    tipLine("Bonus reward the first time you craft this recipe.", GREEN_FONT_COLOR, true)
    shown = true
  end
  local tip = order.reagentState and REAGENT_TIP[order.reagentState]
  if tip then
    tipLine(tip[1], tip[2], true)
    shown = true
  end
  if shown then GameTooltip:Show() else GameTooltip:Hide() end
end

function ShadowsOfUI_ProfCommissions_InfoCellMixin:OnLeave()
  local row = self:GetParent()
  if row.HighlightTexture then row.HighlightTexture:Hide() end
  GameTooltip:Hide()
end

-- Replace Blizzard's text "Reagents" column with our two-icon Info cell (post-hook of SetupTable).
-- Find that column by its sort order — present only on the per-order (Flat) list, so this no-ops on
-- the aggregated bucketed view where there is no Reagents column. Reset() first so the old reagents
-- cells are released through their own pool before the pool is swapped; Arrange() then rebuilds every
-- row's cells, ours included. The header keeps ProfessionsSortOrder.Reagents, so the column still
-- sorts by reagent state — just relabelled and drawn as icons.
function ns.ReplaceReagentsColumn(page)
  local tb = page.tableBuilder
  if not tb then return end
  local column
  for _, col in ipairs(tb:GetColumns() or {}) do
    if col.headerFrame and col.headerFrame.sortOrder == ProfessionsSortOrder.Reagents then
      column = col
      break
    end
  end
  if not column then return end
  column:Reset()
  column:ConstructCells("FRAME", "ShadowsOfUI_ProfCommissions_InfoCellTemplate", page)
  column.headerFrame:SetText(COLUMN_HEADER)
  tb:Arrange()
end
