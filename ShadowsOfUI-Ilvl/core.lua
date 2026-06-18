---@class ShadowsOfUI_Ilvl: AddOn
local ns = LibNAddOn(...)

-- Minimum-quality dropdown: option index i tags quality >= (i - 1), i.e. the
-- index lines up with Enum.ItemQuality + 1 (1=Poor … 5=Epic).
local QUALITY_OPTIONS = { "Poor", "Common", "Uncommon", "Rare", "Epic" }

-- Saved settings. Every surface is independently toggleable; the character and
-- inspect panels additionally choose inset (label beside the icon, toward the
-- panel centre) vs overlay (on top of the icon).
local Defaults = {
    bags = true,
    bank = true,
    loot = true,
    guildbank = true,
    baganator = true,
    bagnon = true,
    character = true,
    characterInset = true,
    inspect = true,
    inspectInset = true,
    minQuality = 3, -- Uncommon
}

function ns:MigrateDB()
    local db = self.db
    for k, v in pairs(Defaults) do
        if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
    end
    db.version = 2
end

-- Re-tag every currently-visible surface. Surfaces register a refresher here so
-- a settings change takes effect immediately on anything already on screen.
ns._refreshers = {}
function ns.AddRefresher(fn)
    table.insert(ns._refreshers, fn)
end
function ns.Refresh()
    for _, fn in ipairs(ns._refreshers) do fn() end
end
function ns:settingChanged()
    ns.Refresh()
end

local function dbTable(db) return db end
ns:RegisterSettings{
    {
        title = ns._TITLE,
        parent = "Shadows of UI",
        fields = {
            { typ = "dropdown", key = "minQuality", default = 3, options = QUALITY_OPTIONS,
              name = "Minimum quality", label = "minimum quality", table = dbTable,
              tooltip = "Only tag gear of this quality or better." },
            { typ = "checkbox", key = "bags", default = true, name = "Bags",
              label = "bags", table = dbTable, tooltip = "Show on bag item icons." },
            { typ = "checkbox", key = "bank", default = true, name = "Bank",
              label = "bank", table = dbTable, tooltip = "Show on bank item icons." },
            { typ = "checkbox", key = "loot", default = true, name = "Loot",
              label = "loot", table = dbTable, tooltip = "Show on loot-window icons." },
            { typ = "checkbox", key = "guildbank", default = true, name = "Guild bank",
              label = "guild bank", table = dbTable, tooltip = "Show on guild-bank icons." },
            { typ = "checkbox", key = "baganator", default = true, name = "Baganator",
              label = "Baganator", table = dbTable, tooltip = "Show the upgrade-track badge as a Baganator corner widget (if installed)." },
            { typ = "checkbox", key = "bagnon", default = true, name = "Bagnon",
              label = "Bagnon", table = dbTable, tooltip = "Show on Bagnon / Bagnonium item icons (if installed)." },
            { typ = "checkbox", key = "character", default = true, name = "Character pane",
              label = "character pane", table = dbTable, tooltip = "Show on the character paperdoll." },
            { typ = "checkbox", key = "characterInset", default = true, name = "Character: inset",
              label = "character inset", table = dbTable,
              tooltip = "Place the label beside each slot (toward the centre) instead of over the icon." },
            { typ = "checkbox", key = "inspect", default = true, name = "Inspect pane",
              label = "inspect pane", table = dbTable, tooltip = "Show on the inspect paperdoll." },
            { typ = "checkbox", key = "inspectInset", default = true, name = "Inspect: inset",
              label = "inspect inset", table = dbTable,
              tooltip = "Place the label beside each slot (toward the centre) instead of over the icon." },
        },
    },
}

-- /silvl <itemID|link>: dump ilvl/quality/track for an item (dev helper)
SLASH_SUI_ILVL1 = "/silvl"
SlashCmdList["SUI_ILVL"] = function(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    local id = tonumber(msg)
    local item = id and Item:CreateFromItemID(id) or (msg ~= "" and Item:CreateFromItemLink(msg)) or nil
    if not item or item:IsItemEmpty() then
        return ns:Print("Usage: /silvl <itemID or item link>")
    end
    item:ContinueOnItemLoad(function()
        local ilvl, quality, track = ns.ItemDetails(item)
        ns:Print(item:GetItemLink() or msg, "→ ilvl", ilvl or "?", "· track", track or "-", "· quality", quality or "?")
    end)
end
