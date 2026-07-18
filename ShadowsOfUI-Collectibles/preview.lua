---@type ShadowsOfUI_Collectibles
local ns = select(2, ...)

-- The tint picker + live preview for the Collectible Tints settings panel — there
-- is no separate dropdown; this IS the picker. Two side-by-side columns of three
-- sample merchant items (common/rare/epic) built from the real merchant textures
-- (UI-EmptySlot slot, UI-Merchant-LabelSlots name plate, item icon + border): a
-- left untinted control and a right tinted twin, tinted "known" exactly the way
-- surfaces.lua tints the live merchant. Back/next wrap arrows cycle the tint; two
-- sliders preview saturation + icon dim. Registered as the FIRST settings field via
-- LibNAddOn's `element` field type (so it sits at the top of the panel); preview.xml
-- holds the virtual template (the mixin must be a global for the XML `mixin=`).

-- One sample collectible per quality the tint has to sit alongside (1 Common,
-- 3 Rare, 4 Epic; Uncommon/green is skipped — it clashes with the collectible tint).
local SAMPLES = {
  { name = "Faded Recipe",     icon = "Interface\\Icons\\inv_scroll_03",             quality = 1, price = 5000 },
  { name = "Azure Whelpling",  icon = "Interface\\Icons\\inv_box_petcarrier_01",     quality = 3, price = 250000 },
  { name = "Swift Windsteed",  icon = "Interface\\Icons\\ability_mount_ridinghorse", quality = 4, price = 5000000 },
}

-- Cycle the selected preset by delta with wrap-around. settingChanged applies the
-- preset's rgb to the db and calls ns.Refresh(), which re-tints both this card (via
-- the refresher) and any open merchant/AH surface.
local function step(delta)
  local n = #ns.PRESETS
  ns.db.knownColor = ((ns.db.knownColor or 1) - 1 + delta) % n + 1
  ns:settingChanged("knownColor")
end

-- Fade a colour toward its own luminance grey by (1 - sat): sat 1 = full colour,
-- sat 0 = neutral grey. Used to desaturate the item-name text in lockstep with the
-- icon (SetDesaturation greys a texture the same way, but not a FontString).
local function desaturate(r, g, b, sat)
  local lum = 0.3 * r + 0.59 * g + 0.11 * b
  return lum + (r - lum) * sat, lum + (g - lum) * sat, lum + (b - lum) * sat
end

-- Re-apply the live known-item tint to every card, mirroring surfaces.lua: the name
-- plate + slot take the full colour, the icon + its border take the 0.9x multiply.
-- The saturation slider desaturates the item's own content — the icon art and the
-- name text — but NOT the tint wash, so the colour mark stays vivid as the item fades.
local function updateCard(self)
  if not self.rows then return end
  local r, g, b = ns.KnownColor()
  local sat = self.saturation or 1
  local alpha = 1 - (self.dim or 0)
  for _, card in ipairs(self.rows) do
    card.slot:SetVertexColor(r, g, b)
    card.nameFrame:SetVertexColor(r, g, b)
    card.border:SetVertexColor(0.9 * r, 0.9 * g, 0.9 * b)
    card.icon:SetVertexColor(0.9 * r, 0.9 * g, 0.9 * b)
    card.icon:SetDesaturation(1 - sat)
    card.icon:SetAlpha(alpha) -- debug dim: fade the icon (Blizzard's unusable-item look)
    card.name:SetTextColor(desaturate(card.qr, card.qg, card.qb, sat))
  end
  if self.tintName then
    -- After /scollect custom the tint is an arbitrary r/g/b with knownColor left pointing at the
    -- old preset, so label it "Custom" whenever the live colour no longer matches that preset.
    local k = (ns.db and ns.db.knownColor) or 1
    local p = ns.PRESETS[k]
    local named = p and ns.db and ns.db.r == p[1] and ns.db.g == p[2] and ns.db.b == p[3]
    self.tintName:SetText(named and (ns.COLOR_OPTIONS[k] or "") or "Custom")
  end
end

local function makeArrow(parent, atlas, tip, delta)
  local a = CreateFrame("Button", nil, parent)
  a:SetSize(22, 22)
  a:SetNormalAtlas(atlas)
  a:SetHighlightAtlas(atlas)
  a:GetHighlightTexture():SetAlpha(0.3)
  a:SetScript("OnClick", function() step(delta) end)
  a:SetScript("OnEnter", function()
    GameTooltip:SetOwner(a, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tip)
    GameTooltip:Show()
  end)
  a:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return a
end

-- One merchant-style card: slot bevel, name plate, icon + border, quality-coloured
-- name, coin price. Tint is applied later by updateCard.
local function buildRow(self, sample)
  local card = CreateFrame("Frame", nil, self)
  card:SetSize(170, 42)

  local slot = card:CreateTexture(nil, "BACKGROUND")
  slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
  slot:SetSize(64, 64)
  slot:SetPoint("TOPLEFT", card, "TOPLEFT", -13, 13)
  card.slot = slot

  local nameFrame = card:CreateTexture(nil, "BACKGROUND")
  nameFrame:SetTexture("Interface\\MerchantFrame\\UI-Merchant-LabelSlots")
  nameFrame:SetSize(136, 78)
  nameFrame:SetPoint("LEFT", slot, "RIGHT", -9, -18)
  card.nameFrame = nameFrame

  local icon = card:CreateTexture(nil, "ARTWORK")
  icon:SetSize(37, 37)
  icon:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
  icon:SetTexture(sample.icon)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's baked border
  card.icon = icon

  local border = card:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetSize(64, 64)
  border:SetPoint("CENTER", icon, "CENTER", 0, -1)
  card.border = border

  local qr, qg, qb = C_Item.GetItemQualityColor(sample.quality)
  local name = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  name:SetPoint("LEFT", slot, "RIGHT", -3, 8)
  name:SetWidth(120)
  name:SetJustifyH("LEFT")
  name:SetText(sample.name)
  name:SetTextColor(qr, qg, qb)
  card.name = name
  card.qr, card.qg, card.qb = qr, qg, qb -- base quality colour, faded by saturation

  local price = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  price:SetPoint("LEFT", slot, "RIGHT", -1, -13)
  price:SetText(GetCoinTextureString(sample.price))

  return card
end

-- A labelled 0–100% debug slider (MinimalSliderWithSteppers). `anchor`/`dx`/`dy`
-- position the label's TOPLEFT off another frame's BOTTOMLEFT; the slider hangs
-- under the label. Returns the slider so the next one can stack beneath it.
local function makeSlider(self, anchor, dx, dy, text, initial, apply)
  local label = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", dx, dy)
  local function fmt(v) label:SetText(("%s: %d%%"):format(text, math.floor(v * 100 + 0.5))) end
  fmt(initial)

  local slider = CreateFrame("Frame", nil, self, "MinimalSliderWithSteppersTemplate")
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -6)
  slider:SetWidth(195) -- fits the left controls column, clear of the preview column
  slider:Init(initial, 0, 1, 20) -- 0..1 in 0.05 steps
  slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    apply(value)
    fmt(value)
    updateCard(self)
  end, self)
  return slider
end

local COLUMN_GAP = 175 -- horizontal offset from an untinted card to its tinted twin
local PREVIEW_X = 230   -- left edge of the preview column, right of the controls column

local function build(self)
  -- Left = controls column (tint stepper + the two sliders); right = preview, each
  -- item's untinted control card beside its tinted twin so the tint's effect (and the
  -- sliders) read against a baseline.

  -- Controls column: a "Tint" caption over the wrap-arrow stepper (the native
  -- dropdown's own arrows only clamp; these wrap), then the two debug sliders.
  local controlsHeader = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  controlsHeader:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -10)
  controlsHeader:SetText("Tint")

  local back = makeArrow(self, "common-dropdown-icon-back", "Previous tint (wraps around)", -1)
  back:SetPoint("TOPLEFT", controlsHeader, "BOTTOMLEFT", 4, -8)
  local tintName = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  tintName:SetPoint("LEFT", back, "RIGHT", 6, 0)
  tintName:SetWidth(90)
  tintName:SetJustifyH("CENTER")
  self.tintName = tintName
  local fwd = makeArrow(self, "common-dropdown-icon-next", "Next tint (wraps around)", 1)
  fwd:SetPoint("LEFT", tintName, "RIGHT", 6, 0)

  -- Debug sliders (preview-only; not saved, not applied to the real tinting). They
  -- affect only the tinted column, so the control column stays the baseline.
  self.saturation = 0.5
  self.dim = 0.5
  local satSlider = makeSlider(self, back, -4, -16, "Icon & text saturation", 0.5,
    function(v) self.saturation = v end)
  makeSlider(self, satSlider, -4, -12, "Icon dim", 0.5,
    function(v) self.dim = v end)

  -- Preview column: a "Preview" header over an untinted/tinted pair of sample columns,
  -- captioned so each item reads as a normal/coloured pair.
  local previewHeader = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  previewHeader:SetPoint("TOPLEFT", self, "TOPLEFT", PREVIEW_X, -10)
  previewHeader:SetText("Preview")

  local untintedLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  untintedLabel:SetPoint("TOPLEFT", previewHeader, "BOTTOMLEFT", 0, -6)
  untintedLabel:SetText("Not tinted")
  local tintedLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  tintedLabel:SetPoint("TOPLEFT", untintedLabel, "TOPLEFT", COLUMN_GAP, 0)
  tintedLabel:SetText("Tinted")

  -- Each row: an untinted control card (left, never touched by updateCard) and its
  -- tinted twin (right, +COLUMN_GAP).
  self.rows = {}
  local prevControl
  for i, sample in ipairs(SAMPLES) do
    local control = buildRow(self, sample)
    if prevControl then
      control:SetPoint("TOPLEFT", prevControl, "BOTTOMLEFT", 0, -6)
    else
      control:SetPoint("TOPLEFT", untintedLabel, "BOTTOMLEFT", 4, -12)
    end
    prevControl = control

    local tinted = buildRow(self, sample)
    tinted:SetPoint("TOPLEFT", control, "TOPLEFT", COLUMN_GAP, 0)
    self.rows[i] = tinted
  end
end

ShadowsOfUI_Collectibles_TintPreviewMixin = {}

function ShadowsOfUI_Collectibles_TintPreviewMixin:OnLoad()
  build(self)
  updateCard(self)
  -- Every tint change (dropdown, a wrap arrow, or /scollect custom) calls
  -- ns.Refresh(); ride that to keep the card current.
  ns.AddRefresher(function() updateCard(self) end)
end

function ShadowsOfUI_Collectibles_TintPreviewMixin:Init()
  updateCard(self)
end
