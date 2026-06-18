---@type ShadowsOfUI_Ilvl
local ns = select(2, ...)

local UpdateButton = ns.UpdateButton
local CleanButton  = ns.CleanButton
local AddRefresher = ns.AddRefresher

local function db(key) return ns.db and ns.db[key] end

-- Bagnon / Bagnonium item buttons are the Wildpants `Item` class. The front-end
-- addon `<Include>`s BagBrother's shared source into its OWN namespace, so the
-- class lives on the front-end's global (`Bagnon.Item`, `Bagnonium.Item`) -- there
-- is no `_G.BagBrother` (its own .toc loads no files). `Item:Update` runs
-- `UpdateSecondary` (a `nop` "backwards support" extension point) at the end of
-- every refresh with `self.info` (itemID / hyperlink / quality) populated, so we
-- chain it there. The bag buttons are a `ContainerItem` subclass whose own
-- `UpdateSecondary` Super-calls the base, so hooking the base reaches them.
--
-- The front-end Mixin-copies the class method list onto each secure button at bind
-- time (`Item:Bind`), so we override before the first button is bound:
-- ContinueOnAddOnLoaded fires at the front-end's ADDON_LOADED, before its bag
-- frames (and their buttons) are first built.
local function hook(addon)
    if not (addon and addon.Item) then return end

    local original = addon.Item.UpdateSecondary
    function addon.Item.UpdateSecondary(button)
        if original then original(button) end
        CleanButton(button)
        local info = button.info
        if not (db("bagnon") and info and info.hyperlink) then return end
        if not ns.WantGear(info.itemID or info.hyperlink, info.quality) then return end
        UpdateButton(button, Item:CreateFromItemLink(info.hyperlink), false)
    end

    -- A settings change re-lays-out every shown frame, re-running our hook.
    AddRefresher(function()
        if addon.Frames then addon.Frames:Update() end
    end)
end

-- Hook every Wildpants front-end that's present (each carries its own class copy).
for _, name in ipairs({ "Bagnon", "Bagnonium" }) do
    EventUtil.ContinueOnAddOnLoaded(name, function() hook(_G[name]) end)
end
