---@class ShadowsOfUI_ProfCommissions: AddOn
local ns = LibNAddOn(...)

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local QUALITY_COLORS = ITEM_QUALITY_COLORS

local ICON_SIZE = 18
local ICON_GAP = 3 -- px between adjacent reward icons (and between the group and the money)

-- On the crafter's "Crafting Orders" browse list, Patron (NPC) orders carry bonus item/currency
-- rewards on top of the gold commission. Blizzard renders these as a single generic treasure-chest
-- icon in the Commission cell (ProfessionsCrafterTableCellCommissionMixin) whose contents only show
-- on hover. We replace that chest with the actual reward icons in the same spot — each still hoverable
-- for the full item/currency tooltip, so you can see *what* the reward is at a glance without opening
-- every order.

-- Point the tooltip at whatever this icon represents (an item link or a currency).
local function iconOnEnter(icon)
  GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
  if icon.itemLink then
    GameTooltip:SetHyperlink(icon.itemLink)
  elseif icon.currencyType then
    GameTooltip:SetCurrencyByID(icon.currencyType)
  end
  local row = icon:GetParent() and icon:GetParent():GetParent()
  if row and row.HighlightTexture then row.HighlightTexture:Show() end
  GameTooltip:Show()
end

local function iconOnLeave(icon)
  GameTooltip:Hide()
  local row = icon:GetParent() and icon:GetParent():GetParent()
  if row and row.HighlightTexture then row.HighlightTexture:Hide() end
end

-- Lazily grow a per-cell pool of reward-icon buttons, so recycled rows reuse their buttons.
---@param cell table  the commission table cell
---@param index integer
local function acquireIcon(cell, index)
  local pool = cell.soiRewardIcons
  local icon = pool[index]
  if icon then return icon end

  icon = CreateFrame("Button", nil, cell)

  icon.tex = icon:CreateTexture(nil, "ARTWORK")
  icon.tex:SetAllPoints()
  icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border

  -- Quality-tinted frame around the icon (item rewards only). WhiteIconFrame is a hollow border
  -- texture, so vertex-colouring it rims the icon without painting over it.
  icon.border = icon:CreateTexture(nil, "OVERLAY")
  icon.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  icon.border:SetPoint("TOPLEFT", -1, 1)
  icon.border:SetPoint("BOTTOMRIGHT", 1, -1)

  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  icon.count:SetPoint("BOTTOMRIGHT", 1, 0)

  icon:SetScript("OnEnter", iconOnEnter)
  icon:SetScript("OnLeave", iconOnLeave)

  pool[index] = icon
  return icon
end

-- Fill one reward icon from a reward entry: { itemLink, count } or { currencyType, count }.
local function fillIcon(icon, reward)
  icon:SetSize(ICON_SIZE, ICON_SIZE) -- re-applied each populate so /sprofcomm size retunes live
  icon.itemLink, icon.currencyType = nil, nil
  local texture, quality

  if reward.itemLink then
    icon.itemLink = reward.itemLink
    local _, _, _, _, tex = GetItemInfoInstant(reward.itemLink)
    texture = tex
    quality = C_Item.GetItemQualityByID(reward.itemLink)
  elseif reward.currencyType then
    icon.currencyType = reward.currencyType
    local info = GetCurrencyInfo(reward.currencyType)
    texture = info and info.iconFileID
    quality = info and info.quality
  end

  icon.tex:SetTexture(texture or 134400) -- INV_Misc_QuestionMark fallback

  -- Quality border is item-rewards-only (per README/CONTEXT); currency rewards can
  -- also report a quality but must not get the border.
  local color = reward.itemLink and quality and quality > Enum.ItemQuality.Common and QUALITY_COLORS[quality]
  if color then
    icon.border:SetVertexColor(color.r, color.g, color.b)
    icon.border:Show()
  else
    icon.border:Hide()
  end

  local count = reward.count or 0
  if count > 1 then
    icon.count:SetText(AbbreviateNumbers(count))  -- currency counts can be 3-4 digits; keep it inside the 18px icon
    icon.count:Show()
  else
    icon.count:Hide()
  end
end

-- Post-hook on the commission cell's Populate: hide Blizzard's chest and lay our reward icons out
-- to the left of the money display (where the chest sat), reward 1 leftmost.
---@param cell table
---@param rowData table
local function onPopulate(cell, rowData)
  cell.RewardIcon:Hide() -- always suppress the native chest; we render its contents instead

  cell.soiRewardIcons = cell.soiRewardIcons or {}
  local pool = cell.soiRewardIcons

  local order = rowData and rowData.option
  local rewards = order and order.npcOrderRewards
  local count = rewards and #rewards or 0

  -- Anchor rightmost reward next to the money and walk leftward, so reward 1 ends up on the left.
  local prev = cell.TipMoneyDisplayFrame
  for i = count, 1, -1 do
    local icon = acquireIcon(cell, i)
    fillIcon(icon, rewards[i])
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", prev, "LEFT", -ICON_GAP, 0)
    icon:Show()
    prev = icon
  end
  for i = count + 1, #pool do pool[i]:Hide() end
end

-- ─── "Info" column: first-craft bonus + reagent provision ────────────────────────────────────
--
-- A second glanceable read for each order: whether crafting it earns the first-craft bonus, and
-- whether the customer supplies the reagents or you do. Rendered as a new fixed-width column of two
-- status icons on the crafter orders browse list. Data comes straight off the order:
-- `spellID` → C_TradeSkillUI.IsRecipeFirstCraft, and `reagentState` (All/Some/None).

local COLUMN_HEADER = "Info"

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
  self.FirstCraft:SetShown((order and order.spellID and C_TradeSkillUI.IsRecipeFirstCraft(order.spellID)) or false)

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
  if self.FirstCraft:IsShown() then
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
local function replaceReagentsColumn(page)
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

-- Blizzard_Professions is load-on-demand; its Templates dependency (which defines the commission
-- mixin) is already loaded by the time this fires. Hooking the shared mixin table before any cell
-- is created means every cell picks up the wrapped Populate. The orders page instance already
-- exists at this point, so hook it directly (hooking the mixin table would miss the live instance).
local hooked = false
EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
  if hooked then return end
  hooked = true
  if ProfessionsCrafterTableCellCommissionMixin then
    hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", onPopulate)
  end
  if ProfessionsFrame and ProfessionsFrame.OrdersPage then
    hooksecurefunc(ProfessionsFrame.OrdersPage, "SetupTable", replaceReagentsColumn)
  end
end)

-- /sprofcomm            — status (whether the commission hook is installed + current icon size)
-- /sprofcomm size <n>   — retune the reward icon size live; takes effect on the next list refresh
--                         (re-sort a column or reopen the Crafting Orders window). A tuning aid,
--                         since exact pixel sizing is easier eyeballed in-game than guessed.
SLASH_SUI_PROFCOMM1 = "/sprofcomm"
SlashCmdList["SUI_PROFCOMM"] = function(msg)
  local n = tonumber((msg or ""):match("^%s*size%s+(%d+)"))
  if n then
    ICON_SIZE = n
    ns.Print(("Reward icon size set to %d (refresh the order list to apply)."):format(n))
    return
  end
  ns.Print(("Crafting-order hook %s; reward icon size %d."):format(
    hooked and "installed" or "not installed (open a profession window first)", ICON_SIZE))
end
