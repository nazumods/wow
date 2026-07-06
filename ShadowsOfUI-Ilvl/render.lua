---@type ShadowsOfUI_Ilvl
local ns = select(2, ...)

local GetItemUpgradeInfo  = C_Item.GetItemUpgradeInfo
local GetItemInfoInstant  = C_Item.GetItemInfoInstant
local GetItemQualityColor = C_Item.GetItemQualityColor

local NUMBER_FONT = [[Fonts\ARIALN.TTF]]
local TRACK_HEX   = "ffffd100"     -- gold (inset combined label)
local TRACK_RGB   = { 1, 0.82, 0 } -- gold (overlay track text)

-- Inset (character / inspect) label position per slot-button name. Left-column
-- slots get their label to the RIGHT of the icon, right-column slots to the
-- LEFT — i.e. always toward the centre of the panel, where it's easy to scan.
-- { point, relativePoint, x, y, justifyH }
local InsetPositions = {}
ns.InsetPositions = InsetPositions
do
    local ONRIGHT = { "LEFT", "RIGHT", 6, 0, "LEFT" }
    local ONLEFT  = { "RIGHT", "LEFT", -6, 0, "RIGHT" }
    for _, slot in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }) do
        InsetPositions["Character" .. slot .. "Slot"] = ONRIGHT
        InsetPositions["Inspect" .. slot .. "Slot"]   = ONRIGHT
    end
    for _, slot in ipairs({ "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }) do
        InsetPositions["Character" .. slot .. "Slot"] = ONLEFT
        InsetPositions["Inspect" .. slot .. "Slot"]   = ONLEFT
    end
    -- Weapons sit at the bottom centre; label them like the columns (main hand to
    -- its left, off hand to its right) but vertically centred so they drop below
    -- the wrist / trinket-2 labels at the column bottoms instead of overlapping.
    InsetPositions["CharacterMainHandSlot"]      = ONLEFT
    InsetPositions["InspectMainHandSlot"]        = ONLEFT
    InsetPositions["CharacterSecondaryHandSlot"] = ONRIGHT
    InsetPositions["InspectSecondaryHandSlot"]   = ONRIGHT
end

-- Compact upgrade-track code (e.g. "C2" = Champion 2, "H6" = Hero 6) from a full
-- item hyperlink, or nil for non-upgradeable gear. GetItemUpgradeInfo accepts
-- only a hyperlink — passing an ItemLocation errors.
---@param link string? full item hyperlink
---@return string? track
function ns.TrackFromLink(link)
    local up = link and GetItemUpgradeInfo(link)
    if up and up.trackString and up.currentLevel and up.currentLevel > 0 then
        return up.trackString:sub(1, 1) .. up.currentLevel
    end
end

-- Gear we tag: a weapon or armor piece at or above the minimum-quality setting.
---@param itemInfo number|string itemID or item link
function ns.WantGear(itemInfo, quality)
    if (quality or 0) < ((ns.db and ns.db.minQuality or 3) - 1) then return false end
    local classID = select(6, GetItemInfoInstant(itemInfo))
    return classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
end

-- ilvl + compact upgrade-track code for an equippable item, or nil when the item
-- isn't gear we want to tag.
---@param item table loaded Item
---@return integer? ilvl, integer? quality, string? track
function ns.ItemDetails(item)
    if not item or item:IsItemEmpty() then return end
    local quality = item:GetItemQuality() or 0
    if not ns.WantGear(item:GetItemID(), quality) then return end
    -- A freshly-seen bag item's GetItemLink can be sparse, so for items with a
    -- live location pull the authoritative container/inventory link; else use the
    -- item link (loot/guild bank).
    local link
    local loc = item:GetItemLocation()
    if loc and loc:IsValid() then
        if loc:IsBagAndSlot() then
            link = C_Container.GetContainerItemLink(loc:GetBagAndSlot())
        elseif loc:IsEquipmentSlot() then
            link = GetInventoryItemLink("player", loc:GetEquipmentSlot())
        end
    end
    return item:GetCurrentItemLevel() or 0, quality, ns.TrackFromLink(link or item:GetItemLink())
end

local function makeFS(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(NUMBER_FONT, size, "OUTLINE")
    fs:Hide()
    return fs
end

-- One overlay Frame per button (a frame level above it), shared by both display
-- modes. The FontStrings are created on demand so a button can switch between
-- inset and overlay at runtime when the setting changes.
local function frameFor(button)
    if not button.soiOverlay then
        local o = CreateFrame("Frame", nil, button)
        o:SetAllPoints()
        o:SetFrameLevel(button:GetFrameLevel() + 1)
        button.soiOverlay = o
    end
    return button.soiOverlay
end

local function ensureOverlay(button, big)
    if button.soiIlvl then return end
    local o = frameFor(button)
    button.soiIlvl = makeFS(o, big and 15 or 13)
    button.soiIlvl:SetPoint("TOPRIGHT", -2, -2)
    button.soiTrack = makeFS(o, big and 13 or 11)
    button.soiTrack:SetPoint("BOTTOMLEFT", 2, 2)
end

-- Inset is only ever the paperdoll, so its label is the larger size.
local function ensureInset(button)
    if button.soiInset then return end
    local pos = InsetPositions[button:GetName() or ""] or { "LEFT", "RIGHT", 6, 0, "LEFT" }
    button.soiInset = makeFS(frameFor(button), 14)
    button.soiInset:SetPoint(pos[1], button, pos[2], pos[3], pos[4])
    button.soiInset:SetJustifyH(pos[5])
end

-- Average equipped item level, shown at the top centre of a paperdoll model.
-- Created lazily on the host frame; hidden when no item level is available.
---@param parent table frame to host the label (a paperdoll model)
---@param ilvl integer? equipped average item level, or nil/0 to hide
function ns.SetAvgIlvl(parent, ilvl)
    if not parent.soiAvg then
        parent.soiAvg = makeFS(parent, 18)
        parent.soiAvg:SetPoint("TOP", parent, "TOP", 0, -6)
    end
    if ilvl and ilvl > 0 then
        parent.soiAvg:SetFormattedText("%d ilvl", ilvl)
        parent.soiAvg:Show()
    else
        parent.soiAvg:Hide()
    end
end

function ns.CleanButton(button)
    -- Invalidate any in-flight ContinueOnItemLoad paint (see UpdateButton) so a stale
    -- callback can't repaint a button that was just cleared (e.g. slot emptied, mode off).
    button.soiToken = (button.soiToken or 0) + 1
    if button.soiIlvl  then button.soiIlvl:Hide() end
    if button.soiTrack then button.soiTrack:Hide() end
    if button.soiInset then button.soiInset:Hide() end
end

local function applyOverlay(button, ilvl, quality, track)
    local r, g, b = GetItemQualityColor(quality)
    button.soiIlvl:SetText(ilvl)
    button.soiIlvl:SetTextColor(r, g, b)
    button.soiIlvl:Show()
    if track then
        button.soiTrack:SetText(track)
        button.soiTrack:SetTextColor(TRACK_RGB[1], TRACK_RGB[2], TRACK_RGB[3])
        button.soiTrack:Show()
    else
        button.soiTrack:Hide()
    end
end

local function applyInset(button, ilvl, quality, track)
    local r, g, b = GetItemQualityColor(quality)
    local text = "|c" .. CreateColor(r, g, b):GenerateHexColor() .. ilvl .. "|r"
    if track then
        text = text .. "  |c" .. TRACK_HEX .. track .. "|r"
    end
    button.soiInset:SetText(text)
    button.soiInset:Show()
end

-- Tag a button with its item's ilvl/track once the item data has loaded. Callers
-- ns.CleanButton(button) first, so switching mode (or toggling a place off)
-- clears the other label set.
---@param button table item button (frame)
---@param item table? Item, or nil to leave the button clean
---@param inset boolean? inset beside the icon instead of overlaid on it
---@param big boolean? larger font (paperdoll panels)
function ns.UpdateButton(button, item, inset, big)
    -- A slot button can have several item loads in flight during rapid bag churn
    -- (vendoring/looting): a later refresh that resolves synchronously (cached item)
    -- can be clobbered by an earlier callback for the old item firing late. Stamp the
    -- button and let only the newest callback paint. Bump before the early-return so an
    -- emptying slot also invalidates a prior in-flight paint.
    local token = (button.soiToken or 0) + 1
    button.soiToken = token
    if not item or item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        if button.soiToken ~= token then return end
        local ilvl, quality, track = ns.ItemDetails(item)
        if not ilvl then return ns.CleanButton(button) end
        if inset then
            ensureInset(button)
            applyInset(button, ilvl, quality, track)
        else
            ensureOverlay(button, big)
            applyOverlay(button, ilvl, quality, track)
        end
    end)
end
