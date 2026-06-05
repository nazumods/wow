local _, ns = ...
local ui = ns.ui

local WIN_W = 700
local WIN_H = 520
local LIST_W = 180
local PAD    = 8
local ROW_H  = 22
local BTN_H  = 22

local window = nil

local function CreateWindow()
  local f = ui.TitleFrame:new{
    name     = "WarbandeerBarsRGSWindow",
    title    = "Warbandeer Bars RGS",
    special  = true,
    level    = 600,
    position = { Center = {}, Width = WIN_W, Height = WIN_H },
  }

  -- ── Left panel (profile list) ────────────────────────────────────────────
  local listPanel = ui.CleanFrame:new{
    parent   = f,
    position = {
      TopLeft = { f.titlebar, ui.edge.BottomLeft, PAD, -PAD },
      Width   = LIST_W,
      Bottom  = { f, ui.edge.Bottom, 0, PAD + BTN_H + PAD + ROW_H + PAD },
    },
  }

  local function OnSelect(i)
    local p = ns.db.profiles[i]
    if p then f._textbox:Text(p.encoded or "") end
  end

  local _, refreshList, getSelected = ns.BuildProfileList(listPanel, OnSelect)
  f._refreshList = refreshList

  -- ── Right panel (text area) ──────────────────────────────────────────────
  local textScroll = ui.ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = { f.titlebar, ui.edge.BottomLeft,  PAD + LIST_W + PAD, -PAD },
      BottomRight = { f, ui.edge.BottomRight, -PAD, PAD + BTN_H + PAD + ROW_H + PAD },
    },
  }

  local textW = WIN_W - LIST_W - PAD * 3 - 20
  local eb = ui.EditBox:new{
    parent    = textScroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = { Width = textW },
    OnEscapePressed = function(self) f:Hide() end,
    OnMouseUp       = function(self) self._widget:HighlightText(0, -1) end,
  }
  textScroll:Child(eb)
  f._textbox = eb

  -- ── Checkbox row ────────────────────────────────────────────────────────
  local checkDefs = {
    { key = "bars",     label = "Action Bars" },
    { key = "bindings", label = "Bindings"    },
    { key = "macros",   label = "Macros"      },
    { key = "outfits",  label = "Outfits"     },
    { key = "petbar",   label = "Pet Bar"     },
  }
  local checkX = PAD + LIST_W + PAD
  for _, def in ipairs(checkDefs) do
    local cb = ui.CheckButton:new{
      parent   = f,
      text     = def.label,
      position = {
        Left   = { f, ui.edge.Left,   checkX, 0 },
        Bottom = { f, ui.edge.Bottom, 0, PAD + BTN_H + PAD },
        Height = ROW_H,
        Width  = 90,
      },
      OnToggle = function(self)
        ns.settings.include[def.key] = self:Checked()
      end,
    }
    cb:Checked(ns.settings.include[def.key])
    checkX = checkX + 96
  end

  -- ── Bottom buttons ───────────────────────────────────────────────────────
  local btnDefs = {
    {
      label = "Export",
      x     = PAD + LIST_W + PAD,
      fn    = function()
        local profile = ns.Capture(ns.settings.include, ns.settings.accountMacros, ns.settings.charMacros)
        local encoded = ns.Encode(profile)
        eb:Text(encoded)
        eb._widget:HighlightText(0, -1)
      end,
    },
    {
      label = "Import",
      x     = PAD + LIST_W + PAD + 90,
      fn    = function()
        local text = eb._widget:GetText()
        local profile, err = ns.Decode(text)
        if not profile then
          ns.Print("Import failed: " .. (err or "unknown error"))
          return
        end
        f._pendingProfile = profile
        StaticPopup_Show("WBARSRGS_CONFIRM_IMPORT", profile.char .. " / " .. profile.spec)
      end,
    },
    {
      label = "Save",
      x     = PAD,
      fn    = function()
        StaticPopup_Show("WBARSRGS_SAVE_NAME")
      end,
    },
    {
      label = "Load",
      x     = PAD + 64,
      fn    = function()
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        local p = ns.db.profiles[i]
        local profile, err = ns.Decode(p.encoded or "")
        if not profile then ns.Print("Load failed: " .. (err or "?")); return end
        f._pendingProfile = profile
        StaticPopup_Show("WBARSRGS_CONFIRM_IMPORT", p.name)
      end,
    },
    {
      label = "Delete",
      x     = PAD + 128,
      fn    = function()
        local i = getSelected()
        if not i then ns.Print("Select a profile first."); return end
        table.remove(ns.db.profiles, i)
        refreshList()
        eb:Text("")
      end,
    },
  }

  for _, def in ipairs(btnDefs) do
    ui.Button:new{
      parent  = f,
      onClick = def.fn,
      position = {
        Left   = { f, ui.edge.Left,   def.x, 0   },
        Bottom = { f, ui.edge.Bottom, 0,     PAD  },
        Width  = 60,
        Height = BTN_H,
      },
    }
    ui.Label:new{
      parent   = f,
      text     = def.label,
      position = {
        Left   = { f, ui.edge.Left,   def.x + 4, 0   },
        Bottom = { f, ui.edge.Bottom, 0,          PAD },
        Width  = 60,
        Height = BTN_H,
      },
    }
  end

  -- StaticPopup callbacks reference f and eb via upvalue closure
  StaticPopupDialogs["WBARSRGS_CONFIRM_IMPORT"] = {
    text         = "Restore bars from '%s'?",
    button1      = ACCEPT,
    button2      = CANCEL,
    timeout      = 0,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
      if f._pendingProfile then
        ns.Restore(f._pendingProfile, ns.settings.include)
        f._pendingProfile = nil
      end
    end,
  }

  StaticPopupDialogs["WBARSRGS_SAVE_NAME"] = {
    text         = "Profile name:",
    button1      = ACCEPT,
    button2      = CANCEL,
    hasEditBox   = true,
    timeout      = 0,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
      local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
      local name = editBox:GetText()
      if name == "" then return end
      local profile = ns.Capture(ns.settings.include, ns.settings.accountMacros, ns.settings.charMacros)
      local encoded = ns.Encode(profile)
      eb:Text(encoded)
      table.insert(ns.db.profiles, {
        name = name, char = profile.char, class = profile.class,
        spec = profile.spec, encoded = encoded,
      })
      refreshList()
    end,
  }

  return f
end

function ns:Open()
  if not window then window = CreateWindow() end
  window._refreshList()
  window:Show()
end

ns:registerCommand("", nil, function(self) self:Open() end, "Open Warbandeer Bars RGS")
