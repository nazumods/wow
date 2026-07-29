local TableFrame  = LibNUI.TableFrame
local ScrollFrame = LibNUI.ScrollFrame
local Button      = LibNUI.Button
local Label       = LibNUI.Label
local Texture     = LibNUI.Texture
local window      = LibNUITest.window
local toggling    = LibNUITest.toggling

-- Viewport virtualisation (#843). A static TableFrame builds one cell frame per (row, column) of
-- its data regardless of how many fit on screen; `virtual = true` builds only enough to cover the
-- viewport and re-binds them as it scrolls.
--
-- The two buttons build the SAME data both ways and report the wall-clock cost, because the whole
-- point of the option is a number — a screenshot can't show it. Expect the static build to hang the
-- client for roughly a second: that stall is the bug being fixed, not a fault in the test.
--
-- Correctness is the other half: scroll the virtual table and every row must show ITS own data,
-- with the first column's "Row N" matching the values beside it. A window that binds wrong reads as
-- rows jumping or repeating as you drag.
--
-- The gold dot on every fifth row (Row 5, 10, 15, …) tests `onRebind` specifically. It is an overlay
-- keyed by the cell's DATA row, not part of the cell's data — the same shape as Collected's ★/rank
-- marks — so `Cell:update` alone doesn't maintain it; only the `onRebind` hook re-deriving it per
-- bind does. If the dots ever cling to a screen position instead of following "Row 5/10/15…" as you
-- scroll, the hook has regressed. The readout counts how many times it fired.
--
-- EXPECT the static build to paint faint vertical bands down the screen below the window. That is
-- not a fault in this test: `addRow` grows the TABLE's height per row and `TableCol` anchors its
-- Bottom to the table, so 500 static rows make ~10,000px-tall columns whose backdrops draw well past
-- the viewport. Pre-existing on any large static table — you just never see it behind an opaque
-- window at normal sizes. Virtual mode sizes the table to the viewport, so it doesn't do this.

local ROWS, COLS = 500, 12
local CELL_H, HEADER_H, VIEW_H = 20, 22, 300
local NAME_W, COL_W = 80, 44
local PAD, TITLE_H, BTN_H = 8, 38, 22

local function buildData()
  local out = {}
  for r = 1, ROWS do
    local row = { "Row " .. r }
    for c = 2, COLS do row[c] = tostring((r * c) % 97) end
    out[r] = row
  end
  return out
end

local function buildColInfo()
  local out = { { name = "Name", width = NAME_W } }
  for c = 2, COLS do out[c] = { name = "C" .. c, width = COL_W } end
  return out
end

local GRID_W = NAME_W + COL_W * (COLS - 1)

---@return TitleFrame
local function makeVirtual()
  local f = window("Table: virtual", GRID_W + PAD * 2 + 24, TITLE_H + BTN_H + 8 + HEADER_H + VIEW_H + PAD * 2)

  local readout = Label:new{
    parent = f, color = "muted",
    position = { TopLeft = { PAD, -(TITLE_H + BTN_H + 4) }, Width = GRID_W, Height = 16 },
    text = "Pick a build mode.",
  }

  local grid, scroll
  local rebinds = 0

  -- Re-stamp the "every fifth row" marker onto whichever cells are resident now, reading each Name
  -- cell's own data to decide — exactly how a real consumer (Collected's marks) re-derives overlays
  -- after a bind. The marker is a child of the cell, created once and reused, shown/hidden per row.
  -- `first`/`last` are the data indices now resident — slot k holds row `first + k - 1`. Keyed off
  -- that rather than off the cell's text on purpose: it's the harder half of the contract to get right,
  -- so this is what exercises it.
  --
  -- Mismatches are REPORTED, not asserted: this runs on the scroll path, and a hard error there would
  -- spam the error frame once per frame while dragging — which buries the one message you wanted. The
  -- readout naming the bad slot is louder in practice and doesn't fight the thing it's diagnosing.
  local function restampMarkers(g, first, last)
    rebinds = rebinds + 1
    local bad
    for k, row in ipairs(g.cells) do
      local nameCell = row[1]
      if nameCell then
        local dataRow = first + k - 1
        local live = dataRow <= last
        if live and tostring(nameCell.data) ~= "Row " .. dataRow then
          bad = bad or ("slot %d holds %q, expected \"Row %d\""):format(k, tostring(nameCell.data), dataRow)
        end
        if not nameCell._mark then
          nameCell._mark = Texture:new{
            parent = nameCell, layer = LibNUI.layer.Overlay,
            color = "header", position = { TopLeft = { 2, -2 }, Size = { 6, 6 } },
          }
        end
        nameCell._mark:SetShown(live and dataRow % 5 == 0)
      end
    end
    if bad then
      readout:Text("|cffff4444onRebind WINDOW MISMATCH: " .. bad .. "|r")
      return
    end
    readout:Text(("virtual: rows %d-%d resident, onRebind fired %d times (gold dot follows Row 5/10/15…)")
      :format(first, last, rebinds))
  end

  local function build(virtual)
    if grid then grid:Hide() end
    if scroll then scroll:Hide() end
    rebinds = 0

    local t0 = GetTimePreciseSec()
    grid = TableFrame:new{
      parent       = f,
      colInfo      = buildColInfo(),
      cellWidth    = COL_W,
      cellHeight   = CELL_H,
      headerHeight = HEADER_H,
      virtual      = virtual,
      onRebind     = virtual and restampMarkers or nil,
      position     = { TopLeft = { PAD, -(TITLE_H + BTN_H + 8 + 16) } },
    }
    scroll = ScrollFrame:new{
      parent   = f,
      position = {
        TopLeft     = { PAD, -(TITLE_H + BTN_H + 8 + 16 + HEADER_H) },
        Width       = GRID_W,
        Height      = VIEW_H,
      },
    }
    -- Bind BEFORE the data lands: a virtual table derives its resident count from the viewport's
    -- height, so it has to know the viewport before it decides how many rows to build.
    if virtual then grid:BindViewport(scroll) end
    grid.data = buildData()
    grid:update()
    scroll:Child(grid.rowArea)
    scroll:Refresh()
    local ms = (GetTimePreciseSec() - t0) * 1000

    local cells = 0
    for _, r in ipairs(grid.cells) do
      for _ in pairs(r) do cells = cells + 1 end
    end
    readout:Text(("%s: %.0f ms, %d cell frames for %d rows x %d cols")
      :format(virtual and "virtual" or "static", ms, cells, ROWS, COLS))
  end

  Button:new{
    parent     = f,
    background = "backdrop",
    position   = { TopLeft = { PAD, -TITLE_H }, Size = { GRID_W / 2 - 2, BTN_H } },
    onClick    = function() build(true) end,
  }:Text("Build virtual")

  Button:new{
    parent     = f,
    background = "backdrop",
    position   = { TopLeft = { PAD + GRID_W / 2 + 2, -TITLE_H }, Size = { GRID_W / 2 - 2, BTN_H } },
    onClick    = function() build(false) end,
  }:Text("Build static (slow)")

  return f
end

table.insert(LibNUITest.tests, {
  key  = "tablevirtual",
  name = "Table: viewport virtualisation",
  desc = "Build 500x12 virtual vs static, comparing time + frame count; static's column bands are expected (#843)",
  run  = toggling(makeVirtual),
})
