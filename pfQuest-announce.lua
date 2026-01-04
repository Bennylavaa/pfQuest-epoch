local questAnnounceFrame = CreateFrame("Frame", "pfQuestEpochAnnounce")
questAnnounceFrame:RegisterEvent("UI_INFO_MESSAGE")
questAnnounceFrame:SetScript("OnEvent", function(self, event, message)
  if event == "UI_INFO_MESSAGE" and message then
    pfQuestEpoch_OnQuestUpdate(message)
  end
end)

local objectiveState = {}

function pfQuestEpoch_OnQuestUpdate(message)
  if GetNumPartyMembers() == 0 then
    return
  end

  if not message or type(message) ~= "string" then
    return
  end

  local itemName, numItems, numNeeded = string.match(message, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$")

  if itemName and numItems and numNeeded then
    local iNumItems = tonumber(numItems)
    local iNumNeeded = tonumber(numNeeded)
    local stillNeeded = iNumNeeded - iNumItems

    if not objectiveState[itemName] then
      objectiveState[itemName] = {lastCount = 0, announced = false}
    end

    if objectiveState[itemName].lastCount == iNumItems then
      return
    end

    objectiveState[itemName].lastCount = iNumItems

    local questName = pfQuestEpoch_GetQuestNameForObjective(itemName)
    local itemId = pfQuestEpoch_GetItemIdForObjective(itemName)
    local itemLink = nil

    if itemId then
      local name, link = GetItemInfo(itemId)
      if link then
        itemLink = link
      end
    end

    local outMessage

    if stillNeeded < 1 then
      if pfQuest_config["epochannounceFinished"] == "1" then
        if not objectiveState[itemName].announced then
          objectiveState[itemName].announced = true

          if pfQuest_config["epochannounceShowItem"] == "1" and itemLink then
            if questName then
              outMessage = "Finished " .. itemLink .. " for " .. questName .. "."
            else
              outMessage = "I have finished collecting " .. itemLink .. "."
            end
          else
            if questName then
              outMessage = "Finished " .. questName .. "."
            else
              outMessage = "I have finished " .. itemName .. "."
            end
          end
        end
      end
    else
      objectiveState[itemName].announced = false

      if pfQuest_config["epochannounceRemaining"] == "1" then
        local displayItem = itemLink or itemName

        if questName then
          outMessage = "" .. displayItem .. " for " .. questName .. " (" .. stillNeeded .. " left)"
        else
          outMessage = "" .. displayItem .. " (" .. stillNeeded .. " left)"
        end
      end
    end

    if outMessage and outMessage ~= "" then
      SendChatMessage(outMessage, "PARTY")
    end
  end
end

function pfQuestEpoch_GetQuestNameForObjective(objectiveName)
  local numQuestLogEntries = GetNumQuestLogEntries()

  for i = 1, numQuestLogEntries do
    local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)

    if not isHeader and questTitle then
      SelectQuestLogEntry(i)
      local numObjectives = GetNumQuestLeaderBoards()

      for j = 1, numObjectives do
        local description, type, finished = GetQuestLogLeaderBoard(j)

        if description then
          local objName = string.match(description, "(.*):%s*[-%d]+%s*/%s*[-%d]+%s*$")

          if objName and string.find(string.lower(objName), string.lower(objectiveName), 1, true) then
            return GetQuestLink(i)
          end
        end
      end
    end
  end

  return nil
end

function pfQuestEpoch_GetItemIdForObjective(objectiveName)
  local questId = pfQuestEpoch_GetQuestIdForObjective(objectiveName)

  if questId and pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
    local questData = pfDB["quests"]["data"][questId]

    if questData and questData["obj"] and questData["obj"]["I"] then
      for _, itemId in pairs(questData["obj"]["I"]) do
        local itemName = GetItemInfo(itemId)

        if itemName and string.find(string.lower(objectiveName), string.lower(itemName), 1, true) then
          return itemId
        end
      end
    end
  end

  local numQuestLogEntries = GetNumQuestLogEntries()
  for i = 1, numQuestLogEntries do
    local questTitle, level, questTag, suggestedGroup, isHeader = GetQuestLogTitle(i)

    if not isHeader and questTitle then
      SelectQuestLogEntry(i)
      local numObjectives = GetNumQuestLeaderBoards()

      for j = 1, numObjectives do
        local description, type, finished = GetQuestLogLeaderBoard(j)
        if description then
          local objName = string.match(description, "(.*):%s*[-%d]+%s*/%s*[-%d]+%s*$")
          if objName and string.find(string.lower(objName), string.lower(objectiveName), 1, true) then
            local questText = GetQuestLogQuestText()
            if questText then
              local _, _, itemId = string.find(questText, "item:(%d+)")
              if itemId then
                return tonumber(itemId)
              end
            end
          end
        end
      end
    end
  end

  return nil
end

function pfQuestEpoch_GetQuestIdForObjective(objectiveName)
  local numQuestLogEntries = GetNumQuestLogEntries()

  for i = 1, numQuestLogEntries do
    local questTitle, level, questTag, suggestedGroup, isHeader = GetQuestLogTitle(i)

    if not isHeader and questTitle then
      SelectQuestLogEntry(i)
      local numObjectives = GetNumQuestLeaderBoards()

      for j = 1, numObjectives do
        local description, type, finished = GetQuestLogLeaderBoard(j)

        if description then
          local objName = string.match(description, "(.*):%s*[-%d]+%s*/%s*[-%d]+%s*$")

          if objName and string.find(string.lower(objName), string.lower(objectiveName), 1, true) then
            return pfQuestEpoch_GetQuestIdFromLink(GetQuestLink(i))
          end
        end
      end
    end
  end

  return nil
end

function pfQuestEpoch_GetQuestIdFromLink(questLink)
  if not questLink then return nil end
  local _, _, questId = string.find(questLink, "quest:(%d+)")
  return tonumber(questId)
end

local function ExtendPfQuestConfig()
  if not pfQuest_defconfig or not pfQuestConfig then
    return false
  end

  local foundHeader, foundFinished, foundRemaining, foundShowItem = false, false, false, false
  for _, entry in pairs(pfQuest_defconfig) do
    if entry.text == "Announce" and entry.type == "header" then
      foundHeader = true
    elseif entry.config == "epochannounceFinished" then
      foundFinished = true
    elseif entry.config == "epochannounceRemaining" then
      foundRemaining = true
    elseif entry.config == "epochannounceShowItem" then
      foundShowItem = true
    end
  end

  if foundHeader and foundFinished and foundRemaining and foundShowItem then
    return true
  end

  if not foundHeader then
    table.insert(pfQuest_defconfig, {
      text = "Announce",
      default = nil,
      type = "header"
    })
  end

  if not foundFinished then
    table.insert(pfQuest_defconfig, {
      text = "Announce Finished Quest Objectives",
      default = "0",
      type = "checkbox",
      config = "epochannounceFinished"
    })
  end

  if not foundRemaining then
    table.insert(pfQuest_defconfig, {
      text = "Announce Remaining Quest Objectives",
      default = "0",
      type = "checkbox",
      config = "epochannounceRemaining"
    })
  end

  if not foundShowItem then
    table.insert(pfQuest_defconfig, {
      text = "Show Item Link in Finished Announcement",
      default = "0",
      type = "checkbox",
      config = "epochannounceShowItem"
    })
  end

  if not pfQuest_config["epochannounceFinished"] then
    pfQuest_config["epochannounceFinished"] = "0"
  end
  if not pfQuest_config["epochannounceRemaining"] then
    pfQuest_config["epochannounceRemaining"] = "0"
  end
  if not pfQuest_config["epochannounceShowItem"] then
    pfQuest_config["epochannounceShowItem"] = "1"
  end

  return true
end

local function CheckAndHandleVersionUpdate()
  -- Only disable on version 2.22.1, one time only
  local currentVersion = GetAddOnMetadata("pfQuest-epoch", "Version") or "0.0.0"

  if currentVersion == "2.22.1" and not pfQuest_config["epochannounceForcedDisableOnce"] then
    pfQuest_config["epochannounceFinished"] = "0"
    pfQuest_config["epochannounceRemaining"] = "0"
    pfQuest_config["epochannounceForcedDisableOnce"] = "1"
    return true
  end

  return false
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("ADDON_LOADED")
configExtenderFrame:SetScript("OnEvent", function(self, event, addonName)
  if addonName == "pfQuest-epoch" then
    local timer = 0
    self:SetScript("OnUpdate", function()
      timer = timer + 1
      if timer > 10 then
        if ExtendPfQuestConfig() then
          local versionUpdated = CheckAndHandleVersionUpdate()
          if versionUpdated then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Updated - Finished quest announcements have been disabled. Re-enable manually if desired.")
          end
          self:SetScript("OnUpdate", nil)
          self:UnregisterAllEvents()
        elseif timer > 300 then
          self:SetScript("OnUpdate", nil)
          self:UnregisterAllEvents()
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Config integration failed")
        end
      end
    end)
  end
end)

local function SetupAnnounceCommands()
  local currentHandler = SlashCmdList["PFDB"]

  SlashCmdList["PFDB"] = function(input, editbox)
    local commandlist = {}
    local command

    local compat = pfQuestCompat
    if compat and compat.gfind then
      for command in compat.gfind(input, "[^ ]+") do
        table.insert(commandlist, command)
      end
    else
      for word in string.gmatch(input, "[^%s]+") do
        table.insert(commandlist, word)
      end
    end

    local arg1 = commandlist[1] and string.lower(commandlist[1])
    local arg2 = commandlist[2] and string.lower(commandlist[2])
    local arg3 = commandlist[3] and string.lower(commandlist[3])

    if arg1 == "announce" then
      if arg2 == "finished" then
        if arg3 == "on" then
          pfQuest_config["epochannounceFinished"] = "1"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Finished quest announcements enabled")
          return
        elseif arg3 == "off" then
          pfQuest_config["epochannounceFinished"] = "0"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Finished quest announcements disabled")
          return
        end
      elseif arg2 == "remaining" then
        if arg3 == "on" then
          pfQuest_config["epochannounceRemaining"] = "1"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Remaining quest announcements enabled")
          return
        elseif arg3 == "off" then
          pfQuest_config["epochannounceRemaining"] = "0"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Remaining quest announcements disabled")
          return
        end
      elseif arg2 == "item" then
        if arg3 == "on" then
          pfQuest_config["epochannounceShowItem"] = "1"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Item links in announcements enabled")
          return
        elseif arg3 == "off" then
          pfQuest_config["epochannounceShowItem"] = "0"
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Item links in announcements disabled")
          return
        end
      end
    end

    if currentHandler then
      currentHandler(input, editbox)
    end
  end
end

local commandSetupFrame = CreateFrame("Frame")
commandSetupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commandSetupFrame:SetScript("OnEvent", function()
  local timer = 0
  this:SetScript("OnUpdate", function()
    timer = timer + 1
    if timer > 60 then
      SetupAnnounceCommands()
      this:SetScript("OnUpdate", nil)
      this:UnregisterAllEvents()
    end
  end)
end)