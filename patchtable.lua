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
pfQuest.dburl = "https://epochhead.com/?quest="

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

function pfDatabase:QueryServer()
  if not QueryQuestsCompleted then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Option is not available on your server.")
    return
  end
  QueryQuestsCompleted()
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("QUEST_QUERY_COMPLETE")
  local function OnQuestQueryComplete()
    frame:UnregisterEvent("QUEST_QUERY_COMPLETE")
    local completedQuests = GetQuestsCompleted()
    if type(completedQuests) == "table" then
      local count = 0
      for questID, _ in pairs(completedQuests) do
        pfQuest_history[questID] = { time(), UnitLevel("player") }
        count = count + 1
      end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Found " .. count .. " completed quests.")
      pfQuest:ResetAll()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Query Complete. Please /reload to save the changes.")
    elseif completedQuests == nil then
      print("Error: GetQuestsCompleted() returned nil.")
    else
      print("Error: GetQuestsCompleted() did not return a valid table. Value: ", completedQuests)
    end
  end
  frame:SetScript("OnEvent", OnQuestQueryComplete)
end

function pfDatabase:PrintQuestData()
  local completedQuests = GetQuestsCompleted()
  if completedQuests then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Raw quest data:")
    for questID, data in pairs(completedQuests) do
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuestID: " .. questID .. " = " .. tostring(data))
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: No quest data available. Try running QueryQuestsCompleted() first.")
  end
end

pfQuest_CompletedQuestData = pfQuest_CompletedQuestData or {}

function pfDatabase:SaveCompletedQuests()
  if not QueryQuestsCompleted then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Option is not available on your server.")
    return
  end

  QueryQuestsCompleted()
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("QUEST_QUERY_COMPLETE")

  local function OnQuestQueryComplete()
    frame:UnregisterEvent("QUEST_QUERY_COMPLETE")

    local completedQuests = GetQuestsCompleted()
    if type(completedQuests) == "table" then
      pfQuest_CompletedQuestData = {
        data = completedQuests,
        timestamp = time(),
        characterName = UnitName("player"),
        realm = GetRealmName()
      }

      local count = 0
      for questID, _ in pairs(completedQuests) do
        count = count + 1
      end

      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Saved " .. count .. " completed quests to SavedVariables.")
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Data will persist between sessions.")
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Error - Could not retrieve quest data.")
    end
  end

  frame:SetScript("OnEvent", OnQuestQueryComplete)
end

-- Function to calculate gray level (no XP level) based on WoW's system
local function GetGrayLevel(charLevel)
  if charLevel <= 5 then
    return 0  -- all mobs give XP
  elseif charLevel <= 49 then
    return charLevel - math.floor(charLevel / 10) - 5
  elseif charLevel == 50 then
    return 40  -- charLevel - 10
  elseif charLevel <= 59 then
    return charLevel - math.floor(charLevel / 5) - 1
  else -- level 60-70
    return charLevel - 9
  end
end

function pfDatabase:QuestFilter(id, plevel, pclass, prace)
  -- hide active quest
  if pfQuest.questlog[id] then return end
  -- hide completed quests
  if pfQuest_history[id] then return end
  -- hide broken quests without names
  if not pfDB.quests.loc[id] or not pfDB.quests.loc[id].T then return end
  -- hide missing pre-quests
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["pre"] then
    -- check all pre-quests for one to be completed
    local one_complete = nil
    for _, prequest in pairs(pfDB["quests"]["data"][id]["pre"]) do
      if pfQuest_history[prequest] then
        one_complete = true
      end
    end
    -- hide if none of the pre-quests has been completed
    if not one_complete then return end
  end
  -- hide non-available quests for your race
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["race"] and not ( bit.band(pfDB["quests"]["data"][id]["race"], prace) == prace ) then return end
  -- hide non-available quests for your class
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["class"] and not ( bit.band(pfDB["quests"]["data"][id]["class"], pclass) == pclass ) then return end
  -- hide non-available quests for your profession
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["skill"] and not pfDatabase:GetPlayerSkill(pfDB["quests"]["data"][id]["skill"]) then return end
  -- hide lowlevel quests using WoW's gray level system
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["lvl"] and pfDB["quests"]["data"][id]["lvl"] <= GetGrayLevel(plevel) and pfQuest_config["showlowlevel"] == "0" then return end
  -- hide highlevel quests (or show those that are 3 levels above)
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["min"] and pfDB["quests"]["data"][id]["min"] > plevel + ( pfQuest_config["showhighlevel"] == "1" and 3 or 0 ) then return end
  -- hide event quests
  if pfDB["quests"]["data"][id] and pfDB["quests"]["data"][id]["event"] and pfQuest_config["showfestival"] == "0" then return end
  return true
end

-- fix wotlk linking from db menu
pfQuestCompat.InsertQuestLink = function(questid, name)
  local questid = questid or 0
  local fallback = name or UNKNOWN
  local level = pfDB["quests"]["data"][questid] and pfDB["quests"]["data"][questid]["lvl"] or 0
  local name = pfDB["quests"]["loc"][questid] and pfDB["quests"]["loc"][questid]["T"] or fallback
  local hex = pfUI.api.rgbhex(pfQuestCompat.GetDifficultyColor(level))

  -- Use the correct editbox for 3.3.5
  local editBox = ChatFrame1EditBox or ChatFrameEditBox

  if editBox then
    editBox:Show()
    if pfQuest_config["questlinks"] == "1" then
    -- seems server blocks the other method so I used this
      editBox:Insert("\124cffffff00\124Hquest:" .. questid .. ":" .. level .. "\124h[" .. name .. "]\124h\124r")
    else
      editBox:Insert("[" .. name .. "]")
    end
  end
end

local corpseMessage = ""
local wasDeadLastFrame = false

pfQuest.route.arrow:SetScript("OnUpdate", function()
  if not this.parent then return end

local isCurrentlyDead = UnitIsDead("player") or UnitIsGhost("player")

if isCurrentlyDead then
  if not wasDeadLastFrame then
    local corpseMessages = {
      "Skill Issue, have fun running back",
      "Git Gud Scrub",
      "You Died LOL",
      "Walk of Shame Initiated",
      "Corpse Run Express",
      "Better Luck Next Time",
      "RIP Your Repair Bill",
      "Death Tax Collector Awaits",
      "Your Body is Over There Dummy",
      "Congratulations, You're Dead",
      "Achievement Unlocked: Floor Tank",
      "Press F to Pay Respects",
      "This is Why We Can't Have Nice Things",
      "Maybe Try Reading the Tactics Next Time",
      "Outstanding Move, Chief",
      "Welcome to the Spirit World",
      "Ghost Mode: ACTIVATED",
      "That Went Well",
      "Professional Grave Digger",
      "Another Happy Landing",
      "Task Failed Successfully",
      "Speedrun: Any% Death Category",
      "You've Been Disconnected from Life",
      "Error 404: HP Not Found",
      "Critical Hit: Your Pride",
      "Respawn Timer: Your Dignity",
      "New Personal Best: Worst Decision",
      "Plot Twist: You're the Bad Guy",
      "Congratulations, You Played Yourself",
      "Tutorial Complete: How to Die",
      "Achievement: First Time?",
      "Pro Tip: Don't Die Next Time",
      "Your Performance Review: Needs Improvement",
      "Status Update: Currently Deceased",
      "That's a Bold Strategy Cotton",
      "The Afterlife Called, They're Expecting You",
      "Death Certificate: Cause of Death - Bad Decision"
    }
    corpseMessage = corpseMessages[math.random(1, #corpseMessages)]
    wasDeadLastFrame = true
  end

  local cx, cy = GetCorpseMapPosition()
  -- corpse coords are 0–1; ignore if invalid (0,0)
  if cx and cy and (cx > 0 or cy > 0) then
    local xplayer, yplayer = GetPlayerMapPosition("player")
    local dx = (cx - xplayer) * 100 * 1.5
    local dy = (cy - yplayer) * 100

    -- Calculate distance to corpse
    local corpseDistance = ceil(math.sqrt(dx*dx + dy*dy)*100)/100

    local dir = atan2(dx, -dy)
    dir = dir > 0 and (2*math.pi) - dir or -dir
    if dir < 0 then dir = dir + 360 end
    local angle = math.rad(dir) - pfQuestCompat.GetPlayerFacing()

    -- rotate the arrow model to point at corpse
    local cell = modulo(floor(angle / (2*math.pi) * 108 + .5), 108)
    local col = modulo(cell, 9)
    local row = floor(cell / 9)
    this.model:SetTexCoord(
      (col    * 56)/512, ((col+1)*56)/512,
      (row    * 42)/512, ((row+1)*42)/512
    )

    this.title:SetText("Corpse")
    this.description:SetText("|cffff0000" .. corpseMessage .. "|r")
    this.distance:SetText("|cffaaaaaa" .. (pfQuest_Loc["Distance"] or "Distance") .. ": " .. string.format("%.1f", corpseDistance))

    this:Show()
    return
  end
else

  if wasDeadLastFrame then
    wasDeadLastFrame = false
    corpseMessage = ""
  end
end

  xplayer, yplayer = GetPlayerMapPosition("player")
  wrongmap = xplayer == 0 and yplayer == 0 and true or nil
  target = this.parent.coords and this.parent.coords[1] and this.parent.coords[1][4] and this.parent.coords[1] or nil

  if not target or wrongmap or pfQuest_config["arrow"] == "0" then
    if invalid and invalid < GetTime() then
      this:Hide()
    elseif not invalid then
      invalid = GetTime() + 1
    end

    return
  else
    invalid = nil
  end

  xDelta = (target[1] - xplayer*100)*1.5
  yDelta = (target[2] - yplayer*100)
  dir = atan2(xDelta, -(yDelta))
  dir = dir > 0 and (math.pi*2) - dir or -dir
  if dir < 0 then dir = dir + 360 end
  angle = math.rad(dir)

  player = pfQuestCompat.GetPlayerFacing()
  angle = angle - player
  perc = math.abs(((math.pi - math.abs(angle)) / math.pi))
  r, g, b = pfUI.api.GetColorGradient(floor(perc*100)/100)
  cell = modulo(floor(angle / (math.pi*2) * 108 + 0.5), 108)
  column = modulo(cell, 9)
  row = floor(cell / 9)
  xstart = (column * 56) / 512
  ystart = (row * 42) / 512
  xend = ((column + 1) * 56) / 512
  yend = ((row + 1) * 42) / 512

  area = target[3].priority and target[3].priority or 1
  area = max(1, area)
  area = min(20, area)
  area = (area / 10) + 1

  alpha = target[4] - area
  alpha = alpha > 1 and 1 or alpha
  alpha = alpha < .5 and .5 or alpha

  texalpha = (1 - alpha) * 2
  texalpha = texalpha > 1 and 1 or texalpha
  texalpha = texalpha < 0 and 0 or texalpha

  r, g, b = r + texalpha, g + texalpha, b + texalpha

  this.model:SetTexCoord(xstart,xend,ystart,yend)
  this.model:SetVertexColor(r,g,b)

  if target ~= lasttarget then
    color = defcolor
    if tonumber(target[3]["qlvl"]) then
      color = pfMap:HexDifficultyColor(tonumber(target[3]["qlvl"]))
    end

    if target[3].texture then
      this.texture:SetTexture(target[3].texture)

      if target[3].vertex and ( target[3].vertex[1] > 0
        or target[3].vertex[2] > 0
        or target[3].vertex[3] > 0 )
      then
        this.texture:SetVertexColor(unpack(target[3].vertex))
      else
        this.texture:SetVertexColor(1,1,1,1)
      end
    else
      this.texture:SetTexture(pfQuestConfig.path.."\\img\\node")
      this.texture:SetVertexColor(pfMap.str2rgb(target[3].title))
    end

    local level = target[3].qlvl and "[" .. target[3].qlvl .. "] " or ""
    this.title:SetText(color..level..target[3].title.."|r")
    local desc = target[3].description or ""
    if not pfUI or not pfUI.uf then
      this.description:SetTextColor(1,.9,.7,1)
      desc = string.gsub(desc, "ff33ffcc", "ffffffff")
    end
    this.description:SetText(desc.."|r.")
  end

  local distance = floor(target[4]*10)/10
  if distance ~= this.distance.number then
    this.distance:SetText("|cffaaaaaa" .. pfQuest_Loc["Distance"] .. ": "..string.format("%.1f", distance))
    this.distance.number = distance
  end

  this.texture:SetAlpha(texalpha)
  this.model:SetAlpha(alpha)
end)
