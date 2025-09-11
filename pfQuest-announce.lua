local questAnnounceFrame = CreateFrame("Frame", "pfQuestEpochAnnounce")
questAnnounceFrame:RegisterEvent("UI_INFO_MESSAGE")
questAnnounceFrame:SetScript("OnEvent", function(self, event, message)
  if event == "UI_INFO_MESSAGE" and message then
    pfQuestEpoch_OnQuestUpdate(message)
  end
end)

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
    local questName = pfQuestEpoch_GetQuestNameForObjective(itemName)
    local outMessage

    if stillNeeded < 1 then
      if pfQuest_config["epochannounceFinished"] == "1" then
        if questName then
          outMessage = "[pfQuest] I have finished " .. itemName .. " for quest: " .. questName .. ". " .. iNumItems .. "/" .. iNumNeeded
        else
          outMessage = "[pfQuest] I have finished " .. itemName .. ". " .. iNumItems .. "/" .. iNumNeeded
        end
      end
    else
      if pfQuest_config["epochannounceRemaining"] == "1" then
        if questName then
          outMessage = "[pfQuest] " .. itemName .. " for " .. questName .. ": (" .. iNumItems .. "/" .. iNumNeeded .. "). " .. stillNeeded .. " Remaining."
        else
          outMessage = "[pfQuest] " .. itemName .. ": (" .. iNumItems .. "/" .. iNumNeeded .. "). " .. stillNeeded .. " Remaining."
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
            return questTitle
          end
        end
      end
    end
  end

  return nil
end

local function ExtendPfQuestConfig()
  if not pfQuest_defconfig or not pfQuestConfig then
    return false
  end

  local foundHeader, foundFinished, foundRemaining = false, false, false
  for _, entry in pairs(pfQuest_defconfig) do
    if entry.text == "Announce" and entry.type == "header" then
      foundHeader = true
    elseif entry.config == "epochannounceFinished" then
      foundFinished = true
    elseif entry.config == "epochannounceRemaining" then
      foundRemaining = true
    end
  end

  if foundHeader and foundFinished and foundRemaining then
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
      default = "1",
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

  if not pfQuest_config["epochannounceFinished"] then
    pfQuest_config["epochannounceFinished"] = "1"
  end
  if not pfQuest_config["epochannounceRemaining"] then
    pfQuest_config["epochannounceRemaining"] = "0"
  end

  if pfQuestConfig.CreateConfigEntries then
    for i = 1, 50 do
      local frame = getglobal("pfQuestConfig" .. i)
      if frame then
        frame:Hide()
        frame:SetParent(nil)
      else
        break
      end
    end

    pfQuestConfig.vpos = 40

    pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
  end

  return true
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