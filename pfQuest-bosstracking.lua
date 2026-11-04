-- pfQuest-epoch: "World Bosses" and "Dungeon Bosses" tracking lists
--
-- The lists themselves live in pfDB["meta"] (see db/meta-epoch.lua), so
-- "/db track worldbosses" and "/db track dungeonbosses" (plus "/db track clean")
-- work through the regular pfQuest code.

local ICON_PATH = "Interface\\AddOns\\pfQuest-epoch\\img\\tracking\\"

local lists = {
  { "worldbosses", "World Bosses" },
  { "dungeonbosses", "Dungeon Bosses" },
}

local isBossList = {}
for _, entry in ipairs(lists) do isBossList[entry[1]] = true end

-- use the epoch icons for our lists (TrackMeta points to the wotlk icon folder)
local SearchMetaRelation = pfDatabase.SearchMetaRelation
function pfDatabase:SearchMetaRelation(query, meta, show)
  if query and isBossList[query.name] and meta then
    meta.icon = ICON_PATH .. query.name
  end
  return SearchMetaRelation(self, query, meta, show)
end

-- Enabling "Dungeon Bosses" also toggles on "Show Pins on Dungeon Map/Minimap",
-- because without it the pins are not shown inside dungeons. The option is
-- only switched on, never switched off again when the list is toggled off.
-- This wraps TrackMeta, so it covers the menu button and "/db track dungeonbosses"
local TrackMeta = pfDatabase.TrackMeta
function pfDatabase:TrackMeta(list, state)
  if list == "dungeonbosses" and state and pfQuest_config and pfQuest_config["epochDungeonPins"] ~= "1" then
    pfQuest_config["epochDungeonPins"] = "1"
    if pfQuestConfig and pfQuestConfig.UpdateConfigEntries then
      pfQuestConfig:UpdateConfigEntries() -- refresh the checkbox in the settings window
    end
    pfQuest:ResetAll() -- same refresh the settings checkbox triggers
  end
  return TrackMeta(self, list, state)
end

-- add the menu entries below "Rare Mobs"
local function AddMenuEntries()
  local menu = pfQuestMenu
  if not menu or menu.pfEpochBosses then return end

  local rares = menu.rares
  if not rares or not rares.GetPoint then return end

  local _, _, _, _, raresY = rares:GetPoint(1)
  if not raresY then return end

  local count = table.getn(lists)
  local shift = 16 * count

  -- move everything below "Rare Mobs" (buttons and separator lines) further down
  local function Shift(object)
    local numPoints = object:GetNumPoints()
    if numPoints == 0 then return end

    local points = {}
    for i = 1, numPoints do
      local point, relTo, relPoint, x, y = object:GetPoint(i)
      points[i] = { point, relTo, relPoint, x, y }
    end

    if not points[1][5] or points[1][5] >= raresY - 1 then return end

    object:ClearAllPoints()
    for i = 1, numPoints do
      local p = points[i]
      object:SetPoint(p[1], p[2], p[3], p[4], p[5] - shift)
    end
  end

  for _, child in ipairs({ menu:GetChildren() }) do
    if child.name and child ~= rares then Shift(child) end
  end

  for _, region in ipairs({ menu:GetRegions() }) do
    Shift(region)
  end

  -- create the new buttons by reusing the scripts of the "Rare Mobs" button
  for i, entry in ipairs(lists) do
    local name, title = entry[1], entry[2]
    local locale = rawget(pfQuest_Loc, title)
    if locale then title = locale end

    local button = CreateFrame("Button", nil, menu)
    button:SetPoint("TOPLEFT", 0, raresY - 16 * i)
    button:SetPoint("TOPRIGHT", 0, raresY - 16 * i)
    button:SetHeight(16)
    button:SetScript("OnEnter", rares:GetScript("OnEnter"))
    button:SetScript("OnLeave", rares:GetScript("OnLeave"))
    button:SetScript("OnClick", rares:GetScript("OnClick"))
    button.onclick = pfDatabase.TrackMeta
    button.name = name

    button.title = button:CreateFontString(nil, "NORMAL", "GameFontWhite")
    button.title:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
    button.title:SetPoint("LEFT", 22, 0)
    button.title:SetJustifyH("LEFT")
    button.title:SetText(title)

    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetWidth(14)
    button.icon:SetHeight(14)
    button.icon:SetPoint("RIGHT", -8, 0)
    button.icon:SetTexture(ICON_PATH .. name)

    button.highlight = button:CreateTexture(nil, "OVERLAY")
    button.highlight:SetPoint("TOPLEFT", 4, 0)
    button.highlight:SetPoint("BOTTOMRIGHT", -4, 0)
    button.highlight:SetTexture(1, 1, 1, .1)
    button.highlight:Hide()

    button.check = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
    button.check:SetNormalTexture("")
    button.check:SetPushedTexture("")
    button.check:SetHighlightTexture("")
    button.check:SetPoint("LEFT", 10, 0)
    button.check:SetWidth(20)
    button.check:SetHeight(20)
    button.check:SetScale(.6)
    button.check:EnableMouse(false)
    pfUI.api.CreateBackdrop(button.check, nil, true)

    menu[name] = button
  end

  menu:SetHeight(menu:GetHeight() + shift)

  -- keep the checkboxes in sync with /db track
  local OnShow = menu:GetScript("OnShow")
  menu:SetScript("OnShow", function()
    if OnShow then OnShow() end
    for _, entry in ipairs(lists) do
      local button = menu[entry[1]]
      if button and button.check then
        button.check:SetChecked(pfQuest_track and pfQuest_track[entry[1]] and true or false)
      end
    end
  end)

  menu.pfEpochBosses = true
end

AddMenuEntries()
