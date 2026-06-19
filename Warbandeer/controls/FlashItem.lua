---@type Warbandeer
local ns = select(2, ...)

local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetContainerItemInfo = C_Container.GetContainerItemInfo

-- Self-contained "flash find": pulse every on-screen bag/bank slot that holds the
-- item, matched by itemID (a soulbound vs warbound copy share the id — the goal is
-- to *locate* the item, not single out one stack). Mirrors Bagnon's alt-click flash:
-- one broadcast, every matching slot pulses at once. Drives the Detail view's
-- click-an-upgrade-to-find-it interaction (see Layout.attachItemTip / SuggestedBox).
--
-- Adapts to whichever bag UI is active:
--   • Bagnon loaded → fire its own FLASH_ITEM signal so its frames pulse natively (it
--     replaces the default bag UI, hiding the Blizzard frames below). The WildAddon
--     signal is namespaced by the *front-end* addon that owns the live buttons —
--     "Bagnon." — not the shared BagBrother engine the classes are defined in.
--   • Blizzard default bags / bank → walk the shown container + bank buttons and play
--     a private overlay pulse on each match. Blizzard's own flashAnim can't be reused:
--     the new-item OnUpdate stops it the next frame for an item that isn't flagged new.

-- Lazily build (and cache on the button) a private additive border-glow texture with
-- a 3-cycle alpha pulse, then play it. The overlay is ours, so nothing in Blizzard's
-- new-item bookkeeping interferes with it.
local function pulse(button)
  local fx = button.__wbFlash
  if not fx then
    local tex = button:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface/Buttons/UI-ActionButton-Border")
    tex:SetBlendMode("ADD")
    tex:SetPoint("CENTER")
    local s = (button:GetWidth() or 37) * 1.8
    tex:SetSize(s, s)
    tex:SetAlpha(0)

    local ag = tex:CreateAnimationGroup()
    for i = 1, 3 do
      local up = ag:CreateAnimation("Alpha")
      up:SetOrder(i * 2 - 1); up:SetDuration(0.4); up:SetFromAlpha(0); up:SetToAlpha(1)
      local down = ag:CreateAnimation("Alpha")
      down:SetOrder(i * 2); down:SetDuration(0.4); down:SetFromAlpha(1); down:SetToAlpha(0)
    end
    ag:SetScript("OnFinished", function() tex:SetAlpha(0) end)

    fx = { tex = tex, ag = ag }
    button.__wbFlash = fx
  end
  fx.ag:Stop()
  fx.tex:SetAlpha(0)
  fx.ag:Play()
end

-- Walk the Blizzard default bag frames + the bank panel, pulsing every shown slot
-- whose itemID matches. No-ops when those frames are hidden (e.g. Bagnon in front).
local function flashBlizzard(itemID)
  local enum = ContainerFrameUtil_EnumerateContainerFrames
  if enum then
    for _, frame in enum() do
      if frame.EnumerateValidItems then
        for _, btn in frame:EnumerateValidItems() do
          local info = GetContainerItemInfo(btn:GetBagID(), btn:GetID())
          if info and info.itemID == itemID then pulse(btn) end
        end
      end
    end
  end

  local panel = BankPanel
  if panel and panel:IsShown() and panel.itemButtonPool then
    for btn in panel.itemButtonPool:EnumerateActive() do
      local info = GetContainerItemInfo(btn:GetBankTabID(), btn:GetContainerSlotID())
      if info and info.itemID == itemID then pulse(btn) end
    end
  end
end

-- Flash every visible copy of `link`'s item across the open bags / bank. Opens the
-- bags first so there's something to flash (the bank only exists at a banker — we
-- can't force it open, so a bank-only item flashes only while the bank is up).
---@param link string? item hyperlink
function ns.FlashItem(link)
  if not link then return end
  local itemID = GetItemInfoInstant(link)
  if not itemID then return end

  if OpenAllBags then OpenAllBags() end

  -- Bagnon / BagBrother: let it pulse its own slots via its internal signal bus.
  if LibStub then
    local wild = LibStub("WildAddon-1.1", true)
    if wild and wild.Calls then wild.Calls:Fire("Bagnon.FLASH_ITEM", itemID) end
  end

  flashBlizzard(itemID)
end
