local loc = GetLocale()
local dbs = { "items", "quests", "quests-itemreq", "objects", "units", "zones", "professions", "areatrigger", "refloot" }
local noloc = { "items", "quests", "objects", "units" }

-- Patch databases to merge ProjectEpoch data
local function patchtable(base, diff)
  for k, v in pairs(diff) do
    if type(v) == "string" and v == "_" then
      base[k] = nil
    else
      base[k] = v
    end
  end
end

-- fix map-id 139 spawns [EPL]
for _, obj in pairs(pfDB["objects"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 139 then -- map
        tbl[1] = tbl[1] + -5.3 -- x
        tbl[2] = tbl[2] + -4.9 -- y
      end
    end
  end
end
-- fix map-id 139 spawns [EPL]
for _, obj in pairs(pfDB["units"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 139 then -- map
        tbl[1] = tbl[1] + -5.3 -- x
        tbl[2] = tbl[2] + -4.9 -- y
      end
    end
  end
end
-- fix map-id 139 spawns [EPL]
for _, obj in pairs(pfDB["areatrigger"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 139 then -- map
        tbl[1] = tbl[1] + -5.3 -- x
        tbl[2] = tbl[2] + -4.9 -- y
      end
    end
  end
end
-- fix map-id 1519 spawns [Stormwind]
for _, obj in pairs(pfDB["objects"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 1519 then -- map
        tbl[1] = tbl[1] + 6.8 -- x
        tbl[2] = tbl[2] + 10.1 -- y
      end
    end
  end
end
-- fix map-id 1519 spawns [Stormwind]
for _, obj in pairs(pfDB["units"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 1519 then -- map
        tbl[1] = tbl[1] + 6.8 -- x
        tbl[2] = tbl[2] + 10.1 -- y
      end
    end
  end
end
-- fix map-id 1519 spawns [Stormwind]
for _, obj in pairs(pfDB["areatrigger"]["data"]) do
  if obj.coords then
    for num, tbl in pairs(obj.coords) do
      if tbl[3] == 1519 then -- map
        tbl[1] = tbl[1] + 6.8 -- x
        tbl[2] = tbl[2] + 10.1 -- y
      end
    end
  end
end

local loc_core, loc_update
for _, db in pairs(dbs) do
  if pfDB[db]["data-epoch"] then
    patchtable(pfDB[db]["data"], pfDB[db]["data-epoch"])
  end

  for loc, _ in pairs(pfDB.locales) do
    if pfDB[db][loc] and pfDB[db][loc.."-epoch"] then
      loc_update = pfDB[db][loc.."-epoch"] or pfDB[db]["enUS-epoch"]
      patchtable(pfDB[db][loc], loc_update)
    end
  end
end

loc_core = pfDB["professions"][loc] or pfDB["professions"]["enUS"]
loc_update = pfDB["professions"][loc.."-epoch"] or pfDB["professions"]["enUS-epoch"]
if loc_update then patchtable(loc_core, loc_update) end

if pfDB["minimap-epoch"] then patchtable(pfDB["minimap"], pfDB["minimap-epoch"]) end
if pfDB["meta-epoch"] then patchtable(pfDB["meta"], pfDB["meta-epoch"]) end

-- Update bitmasks to include custom races if needed
-- if pfDB.bitraces then
  -- pfDB.bitraces[256] = "Goblin"
  -- pfDB.bitraces[512] = "BloodElf"
-- end

-- Use wowhead database url for now
pfQuest.dburl = "https://www.wowhead.com/tbc/quest="

-- Disable Minimap in custom dungeon maps
function pfMap:HasMinimap(map_id)
  -- disable dungeon minimap
  local has_minimap = not IsInInstance()

  -- enable dungeon minimap if continent is less then 3 (e.g AV)
  if IsInInstance() and GetCurrentMapContinent() < 3 then
    has_minimap = true
  end

  return has_minimap
end

-- Reload all pfQuest internal database shortcuts
pfDatabase:Reload()

-- Automatically clear quest cache if new quests have been found
local updatecheck = CreateFrame("Frame")
updatecheck:RegisterEvent("PLAYER_ENTERING_WORLD")
updatecheck:SetScript("OnEvent", function()
  if pfDB["quests"]["data-epoch"] then
    -- count all known epoch quests
    local count = 0
    for k, v in pairs(pfDB["quests"]["data-epoch"]) do
      count = count + 1
    end

    pfQuest:Debug("Project Epoch loaded with |cff33ffcc" .. count .. "|r quests.")

    -- check if the last count differs to the current amount of quests
    if not pfQuest_epochcount or pfQuest_epochcount ~= count then
      -- remove quest cache to force reinitialisation of all quests.
      pfQuest:Debug("New quests found. Reloading |cff33ffccCache|r")
      pfQuest_questcache = {}
    end

    -- write current count to the saved variable
    pfQuest_epochcount = count
  end
end)

local originalSlashHandler = SlashCmdList["PFDB"]

pfQuest_showingCoins = false

local coinObjects = {}
local coinQuests = {}

if pfDB["meta-epoch"] and pfDB["meta-epoch"]["coins"] then
  for objectId, _ in pairs(pfDB["meta-epoch"]["coins"] or {}) do
    coinObjects[math.abs(objectId)] = true
  end
end

if pfDB["quests"]["data-epoch"] then
  for questId, questData in pairs(pfDB["quests"]["data-epoch"]) do
    if questData["start"] and questData["start"]["O"] then
      for _, objectId in pairs(questData["start"]["O"]) do
        if coinObjects[objectId] then
          coinQuests[questId] = true
        end
      end
    end
  end
end

local function RefreshCoinsDisplay()
  if pfQuest_showingCoins then
    pfMap:DeleteNode("PFDB")
    local meta = { ["addon"] = "PFDB" }
    local query = { name = "coins" }
    meta["texture"] = "Interface\\MoneyFrame\\UI-GoldIcon"
    local maps = pfDatabase:SearchMetaRelation(query, meta)
    pfMap:UpdateNodes()
  end
end

local originalSearchObjectID = pfDatabase.SearchObjectID
pfDatabase.SearchObjectID = function(self, id, meta, maps, prio)
  if coinObjects[id] then
    if not pfQuest_showingCoins then
      return maps or {}
    end
    if pfQuest_showingCoins then
      for questId, questData in pairs(pfDB["quests"]["data"] or {}) do
        if questData["start"] and questData["start"]["O"] then
          for _, objectId in pairs(questData["start"]["O"]) do
            if objectId == id then
              if pfQuest_history[questId] then
                return maps or {}
              end
              if pfQuest.questlog[questId] then
                meta = meta or {}
                meta["texture"] = "Interface\\MoneyFrame\\UI-SilverIcon"
                meta["vertex"] = { 0.8, 0.8, 0.8 } -- Grey tint
              else
                meta = meta or {}
                meta["texture"] = "Interface\\MoneyFrame\\UI-GoldIcon"
                meta["vertex"] = nil -- No tint
              end
              break
            end
          end
        end
      end
    end
  end

  return originalSearchObjectID(self, id, meta, maps, prio)
end

local originalSearchQuestID = pfDatabase.SearchQuestID
pfDatabase.SearchQuestID = function(self, id, meta, maps)
  if coinQuests[id] and not pfQuest_showingCoins then
    return maps or {}
  end

  return originalSearchQuestID(self, id, meta, maps)
end

local originalQuestFilter = pfDatabase.QuestFilter
pfDatabase.QuestFilter = function(self, id, plevel, pclass, prace)
  local quest = pfDB["quests"]["data"][id]
  if coinQuests[id] and pfQuest_history[id] then
    return nil
  end

  if coinQuests[id] and not pfQuest_showingCoins then
    return nil
  end

  if quest and quest["skill"] then
    local playerSkillLevel = pfDatabase:GetPlayerSkill(quest["skill"])
    if not playerSkillLevel then return nil end

    if quest["skillmin"] and playerSkillLevel < quest["skillmin"] then
      return nil
    end
  end

  return originalQuestFilter(self, id, plevel, pclass, prace)
end

local coinEventFrame = CreateFrame("Frame")
coinEventFrame:RegisterEvent("QUEST_LOG_UPDATE")
coinEventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
coinEventFrame:RegisterEvent("QUEST_ABANDONED")
coinEventFrame:RegisterEvent("QUEST_COMPLETE")
coinEventFrame:RegisterEvent("UI_INFO_MESSAGE")
coinEventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "UI_INFO_MESSAGE" then
    local messageType = ...
    if messageType == 32 then
      RefreshCoinsDisplay()
    end
  elseif event == "QUEST_ABANDONED" then
    RefreshCoinsDisplay()
  elseif event == "QUEST_COMPLETE" then
    RefreshCoinsDisplay()
  else
    self.refreshTimer = GetTime() + 0.5
    self:Show()
  end
end)

coinEventFrame:SetScript("OnUpdate", function(self)
  if self.refreshTimer and GetTime() >= self.refreshTimer then
    self.refreshTimer = nil
    RefreshCoinsDisplay()
    self:Hide()
  end
end)

coinEventFrame:Hide()

SlashCmdList["PFDB"] = function(input, editbox)
  local params = {}
  local meta = { ["addon"] = "PFDB" }

  if (input == "" or input == nil) then
    -- Temporarily override AddMessage to filter out coins command
    local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, ...)
      if not string.find(msg, "coins") then
        originalAddMessage(self, msg, ...)
      end
    end

    -- Call original handler
    originalSlashHandler(input, editbox)

    -- Restore original AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
    return
  end

  local commandlist = { }
  local command

  local compat = pfQuestCompat
  for command in compat.gfind(input, "[^ ]+") do
    table.insert(commandlist, command)
  end

  local arg1 = commandlist[1]

  if (arg1 == "coins") then
    -- Set flag to allow coin content to be shown
    pfQuest_showingCoins = true

    local query = {
      name = "coins",
    }

    meta["texture"] = "Interface\\MoneyFrame\\UI-GoldIcon"
    local maps = pfDatabase:SearchMetaRelation(query, meta)
    pfMap:ShowMapID(pfDatabase:GetBestMap(maps))

    return
  end

  if pfQuest_showingCoins then
    pfQuest_showingCoins = false
    pfMap:DeleteNode("PFDB")
  end
  originalSlashHandler(input, editbox)
end