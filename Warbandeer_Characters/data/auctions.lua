---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, sort = table.insert, table.sort
local C_AuctionHouse = C_AuctionHouse
local GetServerTime = GetServerTime
local ACTIVE = Enum.AuctionStatus and Enum.AuctionStatus.Active or 0

---@class AuctionData
---@field scannedAt integer server time of the last scan
---@field count integer active owned auctions at scan time
---@field expiries integer[] absolute server-time expiry stamps, ascending (active auctions only)
---@field value integer total gold tied up (buyout, else bid), copper
---@field bids integer number of auctions the character is bidding on

---@class Character
---@field auctions AuctionData?

-- Owned-auction data is only readable while the auction house is open. Scan on
-- OWNED_AUCTIONS_UPDATED (fired after QueryOwnedAuctions, which we kick off on AH open)
-- into a last-seen cache, mirroring the bank/mail scanners. `timeLeftSeconds` is a retail
-- field, so we store an absolute expiry — auctions run <=48h, so the consumer treats an
-- expiry already in the past as resolved rather than trusting a stale count.
local function scan()
  local toon = ns.currentData
  if not toon then return end
  local now = GetServerTime()
  local num = (C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetNumOwnedAuctions()) or 0
  local expiries, value, count = {}, 0, 0
  for i = 1, num do
    local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
    if info and info.status == ACTIVE then
      count = count + 1
      if info.timeLeftSeconds then insert(expiries, now + info.timeLeftSeconds) end
      value = value + (info.buyoutAmount or info.bidAmount or 0)
    end
  end
  sort(expiries)
  local bids = (C_AuctionHouse.GetNumBids and C_AuctionHouse.GetNumBids()) or 0
  toon.auctions = { scannedAt = now, count = count, expiries = expiries, value = value, bids = bids }
end

ns:registerEvent("AUCTION_HOUSE_SHOW", function()
  if C_AuctionHouse.QueryOwnedAuctions then C_AuctionHouse.QueryOwnedAuctions() end
end)
ns:registerEvent("OWNED_AUCTIONS_UPDATED", scan)
