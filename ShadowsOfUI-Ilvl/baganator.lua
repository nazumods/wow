---@type ShadowsOfUI_Ilvl
local ns = select(2, ...)

-- Baganator drives its own item buttons, so instead of overlaying we register a
-- "corner widget" the user can position/enable from Baganator's own UI. Baganator
-- already ships an item-level widget, so we only add the upgrade-track badge; our
-- `baganator` setting gates whether it renders. The onUpdate gets Baganator's
-- pre-resolved item `details` (full `itemLink`, `quality`, `itemID`).

local function textInit(itemButton)
    local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text.sizeFont = true -- adopt Baganator's configured corner-text size
    return text
end

EventUtil.ContinueOnAddOnLoaded("Baganator", function()
    if not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then return end

    Baganator.API.RegisterCornerWidget("Upgrade Track (ShadowsOfUI)", "shadowsofui-track",
        function(cornerFrame, details)
            if not (ns.db and ns.db.baganator) or not details.itemLink then return false end
            if not ns.WantGear(details.itemID or details.itemLink, details.quality) then return false end
            local track = ns.TrackFromLink(details.itemLink)
            if not track then return false end
            cornerFrame:SetText(track)
            cornerFrame:SetTextColor(1, 0.82, 0)
            return true
        end,
        textInit, { corner = "bottom_left", priority = 1 }
    )
end)
