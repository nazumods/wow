---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Left = ui.justify.Left

-- Titles: each character's current (featured) title — the one shown after its name in-game (data
-- from the Warbandeer_Characters `titles` broker; last-seen, logged-in char only). Long titles
-- truncate in the cell (wordWrap = false) and the hover shows the full title plus how many titles
-- the character has earned. Blank for an alt not seen since the titles broker landed, and for a
-- character with no title selected. (The full earned/earnable browser is a separate Titles view.)

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "titles", label = "Titles",
    name = "Titles",
    width = 140,
    justifyH = Left,
    tooltip = {
      "Titles",
      "Each character's current (featured) title. Hover a cell for the full title and how many"
        .. " titles that character has earned. Only readable while a character is logged in, so an"
        .. " alt shows its last-seen title.",
    },
    getData = function(toon)
      local t = toon.titles
      -- Always return a table (never a bare string) carrying wordWrap = false, so every cell in
      -- this column is created non-wrapping — re-sorts remap characters across cells, and a cell
      -- first built empty must still truncate a long title that later lands in it.
      local cell = { text = (t and t.currentName) or "", justifyH = Left, wordWrap = false }
      if t and t.known then
        local n = #t.known
        cell.onEnter = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine(t.currentName or "|cff808080No title selected|r")
          ui.tip:AddLine(("|cffffffff%d|r title%s earned"):format(n, n == 1 and "" or "s"))
          ui.tip:Show()
        end
        cell.onLeave = function() ui.tip:Hide() end
      end
      return cell
    end,
  }
)
