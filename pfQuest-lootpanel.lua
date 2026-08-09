local GRID_COLUMNS = 6
local ICON_SIZE = 26
local ICON_PADDING = 3
local PANEL_MARGIN = 8
local MAX_ICONS = 18
local MIN_CONTENT_WIDTH = 120

local RANK_INFO = {
  ["1"] = { text = "Elite",      r = 1, g = 0.5,  b = 0 },
  ["2"] = { text = "Rare Elite", r = 1, g = 0.42, b = 0.71 },
  ["3"] = { text = "Boss",       r = 1, g = 0,    b = 0 },
  ["4"] = { text = "Rare",       r = 1, g = 1,    b = 0 },
}

local unitDrops = {}

local function BuildUnitDropIndex()
  local items = pfDB["items"]["data"]
  local refloot = pfDB["refloot"]["data"]
  local seen = {}

  local function AddDrop(unitid, itemid, chance, isRef)
    seen[unitid] = seen[unitid] or {}
    if seen[unitid][itemid] then return end
    seen[unitid][itemid] = true

    unitDrops[unitid] = unitDrops[unitid] or {}
    table.insert(unitDrops[unitid], { item = itemid, chance = chance or 0, isRef = isRef })
  end

  for itemid, item in pairs(items) do
    if item["U"] then
      for unitid, chance in pairs(item["U"]) do
        AddDrop(unitid, itemid, chance, false)
      end
    end

    if item["R"] then
      for ref, chance in pairs(item["R"]) do
        local refdata = refloot[ref]
        if refdata and refdata["U"] then
          for unitid in pairs(refdata["U"]) do
            AddDrop(unitid, itemid, chance, true)
          end
        end
      end
    end
  end

  for _, list in pairs(unitDrops) do
    table.sort(list, function(a, b) return a.chance > b.chance end)
  end
end

BuildUnitDropIndex()

local function GetVisibleDrops(unitid)
  local drops = unitDrops[unitid]
  if not drops then return nil end

  local showReference = pfQuest_config and pfQuest_config["epochLootPanelShowReference"] == "1"
  local showUnknownChance = pfQuest_config and pfQuest_config["epochLootPanelShowUnknownChance"] == "1"

  local visible = {}
  for _, drop in ipairs(drops) do
    local passesRef = showReference or not drop.isRef
    local passesChance = showUnknownChance or (drop.chance and drop.chance > 0)
    if passesRef and passesChance then table.insert(visible, drop) end
  end
  return visible
end

local panel = CreateFrame("Frame", "pfQuestEpochLootPanel", UIParent)
panel:SetFrameStrata("TOOLTIP")
panel:SetClampedToScreen(true)
panel:Hide()

panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

panel:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0, 0, 0, 0.9)
panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

local closeButton = CreateFrame("Button", nil, panel)
closeButton:SetWidth(14)
closeButton:SetHeight(14)
closeButton:SetPoint("TOPRIGHT", -3, -3)
closeButton.text = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeButton.text:SetPoint("CENTER")
closeButton.text:SetText("x")
closeButton.text:SetTextColor(0.8, 0.3, 0.3)
closeButton:SetScript("OnEnter", function() closeButton.text:SetTextColor(1, 1, 1) end)
closeButton:SetScript("OnLeave", function() closeButton.text:SetTextColor(0.8, 0.3, 0.3) end)
closeButton:SetScript("OnClick", function() pfQuestEpochLoot.Hide() end)

panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_MARGIN, -PANEL_MARGIN)
panel.header:SetJustifyH("LEFT")
panel.header:Hide()

local buttonPool = {}

local function GetButton(index)
  local button = buttonPool[index]
  if button then return button end

  button = CreateFrame("Button", nil, panel)
  button:SetWidth(ICON_SIZE)
  button:SetHeight(ICON_SIZE)

  button.border = button:CreateTexture(nil, "BACKGROUND")
  button.border:SetPoint("TOPLEFT", -2, 2)
  button.border:SetPoint("BOTTOMRIGHT", 2, -2)
  button.border:SetTexture(1, 1, 1, 1)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)

  button.chanceText = button:CreateFontString(nil, "OVERLAY")
  button.chanceText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  button.chanceText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
  button.chanceText:SetTextColor(1, 1, 0)

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  button:SetScript("OnEnter", function()
    if not button.itemid then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. button.itemid .. (pfQuestCompat.itemsuffix or ""))
    if button.chance and button.chance > 0 then
      GameTooltip:AddLine(string.format("Drop chance: %.1f%%", button.chance), 0.6, 0.9, 1)
    end
    GameTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  buttonPool[index] = button
  return button
end

local function LayoutButton(button, index, topOffset)
  local col = (index - 1) - floor((index - 1) / GRID_COLUMNS) * GRID_COLUMNS
  local row = floor((index - 1) / GRID_COLUMNS)
  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", panel, "TOPLEFT",
    PANEL_MARGIN + col * (ICON_SIZE + ICON_PADDING),
    -topOffset - row * (ICON_SIZE + ICON_PADDING))
end

local function RankText(unitData)
  local info = unitData and unitData["rnk"] and RANK_INFO[tostring(unitData["rnk"])]
  if not info then return nil end
  return string.format("|cff%02x%02x%02xRank: %s|r", info.r * 255, info.g * 255, info.b * 255, info.text)
end

pfQuestEpochLoot = {}

local pinned = false
local pinnedUnitId = nil

function pfQuestEpochLoot.Hide()
  pinned = false
  pinnedUnitId = nil
  panel:Hide()
end

local function PopulateGrid(unitid, topOffset)
  local drops = GetVisibleDrops(unitid)
  local count = drops and min(table.getn(drops), MAX_ICONS) or 0

  for i = 1, count do
    local drop = drops[i]
    local button = GetButton(i)

    button.itemid = drop.item
    button.chance = drop.chance
    button.icon:SetTexture(GetItemIcon(drop.item))

    if drop.chance and drop.chance > 0 then
      button.chanceText:SetText(string.format("%.0f%%", drop.chance))
      button.chanceText:Show()
    else
      button.chanceText:Hide()
    end

    local _, _, quality = GetItemInfo(drop.item)
    if quality and ITEM_QUALITY_COLORS[quality] then
      local c = ITEM_QUALITY_COLORS[quality]
      button.border:SetVertexColor(c.r, c.g, c.b, 1)
    else
      button.border:SetVertexColor(0.4, 0.4, 0.4, 1)
    end

    LayoutButton(button, i, topOffset)
    button:Show()
  end

  for i = count + 1, table.getn(buttonPool) do
    buttonPool[i]:Hide()
  end

  if count == 0 then
    return false, 0, 0
  end

  local columns = min(count, GRID_COLUMNS)
  local rows = ceil(count / GRID_COLUMNS)
  local width = PANEL_MARGIN * 2 + columns * ICON_SIZE + (columns - 1) * ICON_PADDING
  local gridHeight = rows * ICON_SIZE + (rows - 1) * ICON_PADDING
  return true, width, gridHeight
end

function pfQuestEpochLoot.HasDrops(unitid)
  local drops = unitid and GetVisibleDrops(unitid)
  return drops ~= nil and table.getn(drops) > 0
end

function pfQuestEpochLoot.ShowPinned(nodeFrame)
  local unitid = nodeFrame and nodeFrame.spawnid
  if not unitid then return end

  if pinned and pinnedUnitId == unitid then
    pfQuestEpochLoot.Hide()
    return
  end

  local unitData = pfDB["units"]["data"][unitid]
  if not unitData or not unitData["rnk"] then return end

  local headerLines = {
    "|cff4dffcc" .. (nodeFrame.spawn or UNKNOWN) .. "|r",
    (pfQuest_Loc["Level"] or "Level") .. ": " .. (nodeFrame.level or UNKNOWN),
    (pfQuest_Loc["Type"] or "Type") .. ": " .. (nodeFrame.spawntype or UNKNOWN),
  }

  local rankText = RankText(unitData)
  if rankText then table.insert(headerLines, rankText) end

  table.insert(headerLines, (pfQuest_Loc["Respawn"] or "Respawn") .. ": " .. (nodeFrame.respawn or UNKNOWN))

  local drops = GetVisibleDrops(unitid)
  local dropCount = drops and min(table.getn(drops), MAX_ICONS) or 0
  local columns = min(dropCount, GRID_COLUMNS)
  local gridContentWidth = columns > 0 and (columns * ICON_SIZE + (columns - 1) * ICON_PADDING) or 0
  local contentWidth = max(gridContentWidth, MIN_CONTENT_WIDTH)

  panel.header:SetWidth(contentWidth)
  panel.header:SetText(table.concat(headerLines, "\n"))
  panel.header:Show()

  local headerHeight = panel.header:GetHeight() + 10
  local ok, _, gridHeight = PopulateGrid(unitid, headerHeight)

  pinned = true
  pinnedUnitId = unitid

  panel:SetWidth(contentWidth + PANEL_MARGIN * 2)
  panel:SetHeight(headerHeight + PANEL_MARGIN + (ok and gridHeight or 0))

  panel:ClearAllPoints()
  panel:SetFrameLevel((nodeFrame:GetFrameLevel() or 0) + 1)
  panel:SetPoint("TOPLEFT", nodeFrame, "BOTTOMLEFT", 0, -6)

  panel:Show()
end

local mapWatcher = CreateFrame("Frame")
mapWatcher:RegisterEvent("WORLD_MAP_UPDATE")
mapWatcher:SetScript("OnEvent", pfQuestEpochLoot.Hide)

if WorldMapFrame then
  WorldMapFrame:HookScript("OnHide", pfQuestEpochLoot.Hide)
end

local function ExtendPfQuestConfig()
  for _, entry in pairs(pfQuest_defconfig) do
    if entry.config == "epochLootPanelShowReference" then
      return true
    end
  end

  table.insert(pfQuest_defconfig, {
    text = "|cff33ffccRare Loot Panel|r",
    type = "header"
  })

  table.insert(pfQuest_defconfig, {
    text = "Include pooled loot",
    default = "0",
    type = "checkbox",
    config = "epochLootPanelShowReference"
  })

  table.insert(pfQuest_defconfig, {
    text = "Include unknown loot",
    default = "0",
    type = "checkbox",
    config = "epochLootPanelShowUnknownChance"
  })

  if not pfQuest_config["epochLootPanelShowReference"] then
    pfQuest_config["epochLootPanelShowReference"] = "0"
  end

  if not pfQuest_config["epochLootPanelShowUnknownChance"] then
    pfQuest_config["epochLootPanelShowUnknownChance"] = "0"
  end

  return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", ExtendPfQuestConfig)
