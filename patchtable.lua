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

SlashCmdList["PFDB"] = originalSlashHandler

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
      local closed = 0

      -- First pass: mark all completed quests
      for questID, _ in pairs(completedQuests) do
        pfQuest_history[questID] = { time(), UnitLevel("player") }
        count = count + 1
      end

      -- Second pass: auto-close mutually exclusive quests
      for questID, _ in pairs(pfQuest_history) do
        local questData = pfDB["quests"]["data"][questID]
        if questData and questData["close"] then
          for _, closedQuestID in pairs(questData["close"]) do
            if not pfQuest_history[closedQuestID] then
              pfQuest_history[closedQuestID] = { time(), UnitLevel("player") }
              closed = closed + 1
            end
          end
        end
      end

      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Found " .. count .. " completed quests.")
      if closed > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest: Auto-closed " .. closed .. " mutually exclusive quests.")
      end
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

  -- Cache quest data lookups
  local questLoc = pfDB.quests.loc[id]

  -- hide broken quests without names
  if not questLoc or not questLoc.T then return end

  local quest = pfDB["quests"]["data"][id]
  if not quest then return end

  -- hide missing pre-quests
  if quest["pre"] then
    -- check all pre-quests for one to be completed
    local one_complete = nil
    for _, prequest in pairs(quest["pre"]) do
      if pfQuest_history[prequest] then
        one_complete = true
        break
      end
    end
    -- hide if none of the pre-quests has been completed
    if not one_complete then return end
  end

  -- hide non-available quests for your race
  if quest["race"] and not ( bit.band(quest["race"], prace) == prace ) then return end
  -- hide non-available quests for your class
  if quest["class"] and not ( bit.band(quest["class"], pclass) == pclass ) then return end
  -- hide non-available quests for your profession
  if quest["skill"] then
    local playerSkillLevel = pfDatabase:GetPlayerSkill(quest["skill"])
    if not playerSkillLevel or quest["skillmin"] and playerSkillLevel < quest["skillmin"] then return end
  end
  -- hide lowlevel quests using WoW's gray level system
  if quest["lvl"] and quest["lvl"] <= GetGrayLevel(plevel) and pfQuest_config["showlowlevel"] == "0" then return end
  -- hide highlevel quests (or show those that are 3 levels above)
  if quest["min"] and quest["min"] > plevel + ( pfQuest_config["showhighlevel"] == "1" and 3 or 0 ) then return end
  -- hide event quests
  if quest["event"] and pfQuest_config["showfestival"] == "0" then return end

  -- Cache title
  local title = questLoc.T

  -- hide PvP quests
  if pfQuest_config["epochHidePvPQuests"] == "1" then
    if string.find(title, "Warsong") or
       string.find(title, "Arathi") or
       string.find(title, "Alterac") or
       string.find(title, "Battleground") or
       string.find(title, "Call to Skirmish") then
      return
    end
  end

  -- hide Commission quests
  if pfQuest_config["epochHideCommissionQuests"] == "1" then
    if string.find(title, "Commission for") then
      return
    end
  end

  -- hide chicken quests
  if pfQuest_config["epochHideChickenQuests"] == "1" then
    if string.find(title, "CLUCK!") then
      return
    end
  end

  -- hide Felwood flowers
  if pfQuest_config["epochHideFelwoodFlowers"] == "1" then
    if title == "Corrupted Windblossom" or
       title == "Corrupted Whipper Root" or
       title == "Corrupted Songflower" or
       title == "Corrupted Night Dragon" then
      return
    end
  end

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

-- Item Drop System
local originalSearchQuestID = pfDatabase.SearchQuestID
pfDatabase.SearchQuestID = function(self, id, meta, maps)

  maps = originalSearchQuestID(self, id, meta, maps)

  local quests = pfDB["quests"]["data"]
  local items = pfDB["items"]["data"]
  local units = pfDB["units"]["data"]
  local objects = pfDB["objects"]["data"]
  local refloot = pfDB["refloot"]["data"]

  if not quests[id] then return maps end

  if pfQuest_config["currentquestgivers"] == "1" then
    if quests[id]["start"] and not meta["qlogid"] then
      if quests[id]["start"]["I"] then
        for _, item in pairs(quests[id]["start"]["I"]) do
          if items[item] then
            local drop_sources = {}
            local sources_with_levels = {}

            if items[item]["U"] then
              for unit, chance in pairs(items[item]["U"]) do
                local unit_name = pfDB["units"]["loc"][unit]
                if unit_name and not drop_sources[unit_name] then
                  drop_sources[unit_name] = true
                  local unit_level = units[unit] and units[unit]["lvl"] or "?"
                  sources_with_levels[unit_name] = {level = unit_level, chance = chance}
                end
              end
            end

            if items[item]["O"] then
              for object, chance in pairs(items[item]["O"]) do
                local obj_name = pfDB["objects"]["loc"][object]
                if obj_name and not drop_sources[obj_name] then
                  drop_sources[obj_name] = true
                  sources_with_levels[obj_name] = {level = "Object", chance = chance}
                end
              end
            end

            if items[item]["R"] then
              for ref, chance in pairs(items[item]["R"]) do
                if refloot[ref] then
                  if refloot[ref]["U"] then
                    for unit in pairs(refloot[ref]["U"]) do
                      local unit_name = pfDB["units"]["loc"][unit]
                      if unit_name and not drop_sources[unit_name] then
                        drop_sources[unit_name] = true
                        local unit_level = units[unit] and units[unit]["lvl"] or "?"
                        sources_with_levels[unit_name] = {level = unit_level, chance = chance}
                      end
                    end
                  end

                  if refloot[ref]["O"] then
                    for object in pairs(refloot[ref]["O"]) do
                      local obj_name = pfDB["objects"]["loc"][object]
                      if obj_name and not drop_sources[obj_name] then
                        drop_sources[obj_name] = true
                        sources_with_levels[obj_name] = {level = "Object", chance = chance}
                      end
                    end
                  end
                end
              end
            end

            local sources_text = ""
            local source_count = 0
            local display_count = 0
            for source_name in pairs(drop_sources) do
              source_count = source_count + 1
            end

            for source_name in pairs(drop_sources) do
              display_count = display_count + 1
              if display_count > 1 then sources_text = sources_text .. ", " end
              sources_text = sources_text .. source_name
              if display_count >= 3 then
                if source_count > 3 then
                  sources_text = sources_text .. " (+" .. (source_count - 3) .. " more)"
                end
                break
              end
            end

            local best_source = nil
            local best_count = 0

            if items[item]["U"] then
              for unit, chance in pairs(items[item]["U"]) do
                if units[unit] and units[unit]["coords"] then
                  local count = table.getn(units[unit]["coords"])
                  if count > best_count then
                    best_count = count
                    best_source = {type = "unit", id = unit}
                  end
                end
              end
            end

            if items[item]["O"] then
              for object, chance in pairs(items[item]["O"]) do
                if objects[object] and objects[object]["coords"] then
                  local count = table.getn(objects[object]["coords"])
                  if count > best_count then
                    best_count = count
                    best_source = {type = "object", id = object}
                  end
                end
              end
            end

            if items[item]["R"] then
              for ref, chance in pairs(items[item]["R"]) do
                if refloot[ref] then
                  if refloot[ref]["U"] then
                    for unit in pairs(refloot[ref]["U"]) do
                      if units[unit] and units[unit]["coords"] then
                        local count = table.getn(units[unit]["coords"])
                        if count > best_count then
                          best_count = count
                          best_source = {type = "unit", id = unit}
                        end
                      end
                    end
                  end

                  if refloot[ref]["O"] then
                    for object in pairs(refloot[ref]["O"]) do
                      if objects[object] and objects[object]["coords"] then
                        local count = table.getn(objects[object]["coords"])
                        if count > best_count then
                          best_count = count
                          best_source = {type = "object", id = object}
                        end
                      end
                    end
                  end
                end
              end
            end

            if best_source then
              local coords_table = best_source.type == "unit" and units[best_source.id]["coords"] or objects[best_source.id]["coords"]

              local zones_coords = {}
              for _, data in pairs(coords_table) do
                local x, y, zone = unpack(data)
                if zone > 0 and not zones_coords[zone] then
                  zones_coords[zone] = {x, y}
                end
              end

              for zone, coords in pairs(zones_coords) do
                local item_meta = {}
                for k, v in pairs(meta or {}) do item_meta[k] = v end

                item_meta["QTYPE"] = "ITEM_START"
                item_meta["layer"] = 4
                item_meta["texture"] = pfQuestConfig.path.."\\img\\available"
                --item_meta["vertex"] = { 0.7, 0.4, 1 }
                local plevel = UnitLevel("player")
                if quests[id]["min"] and quests[id]["min"] > plevel then
                  item_meta["vertex"] = { 1, .6, .6 }
                  item_meta["layer"] = 2
                elseif quests[id]["lvl"] and quests[id]["lvl"] <= GetGrayLevel(plevel) then
                  item_meta["vertex"] = { 1, 1, 1 }
                  item_meta["layer"] = 2
                elseif quests[id]["event"] then
                  item_meta["vertex"] = { .2, .8, 1 }
                  item_meta["layer"] = 2
                end

                item_meta["spawn"] = pfDB["items"]["loc"][item] or UNKNOWN
                item_meta["spawnid"] = item
                item_meta["item"] = pfDB["items"]["loc"][item]
                item_meta["dropsources"] = sources_text
                item_meta["dropsources_levels"] = sources_with_levels
                item_meta["title"] = item_meta["quest"] or item_meta["spawn"]
                item_meta["zone"] = zone
                item_meta["x"] = coords[1]
                item_meta["y"] = coords[2]
                item_meta["level"] = pfQuest_Loc["N/A"]
                item_meta["spawntype"] = pfQuest_Loc["Item Drop"]
                item_meta["respawn"] = pfQuest_Loc["N/A"]
                item_meta["description"] = pfDatabase:BuildQuestDescription(item_meta)

                maps = maps or {}
                maps[zone] = maps[zone] and maps[zone] + 0 or 0
                pfMap:AddNode(item_meta)
              end
            end
          end
        end
      end
    end
  end

  return maps
end

local originalSearchQuests = pfDatabase.SearchQuests
pfDatabase.SearchQuests = function(self, meta, maps)
  maps = originalSearchQuests(self, meta, maps)

  local quests = pfDB["quests"]["data"]
  local items = pfDB["items"]["data"]
  local units = pfDB["units"]["data"]
  local objects = pfDB["objects"]["data"]
  local refloot = pfDB["refloot"]["data"]

  local plevel = UnitLevel("player")
  local pfaction = UnitFactionGroup("player")
  pfaction = pfaction == "Horde" and "H" or pfaction == "Alliance" and "A" or "GM"

  local _, race = UnitRace("player")
  local prace = pfDatabase:GetBitByRace(race)
  local _, class = UnitClass("player")
  local pclass = pfDatabase:GetBitByClass(class)

  for id in pairs(quests) do
    if pfDatabase:QuestFilter(id, plevel, pclass, prace) then
      -- Additional faction check for quest enders
      local validFaction = true
      if quests[id]["end"] and quests[id]["end"]["U"] then
        validFaction = false
        for _, unit in pairs(quests[id]["end"]["U"]) do
          if pfDatabase:IsFriendly(unit) then
            validFaction = true
            break
          end
        end
      end

      if validFaction and quests[id]["start"] and quests[id]["start"]["I"] then
        for _, item in pairs(quests[id]["start"]["I"]) do
          if items[item] then
            local drop_sources = {}
            local sources_with_levels = {}

            if items[item]["U"] then
              for unit, chance in pairs(items[item]["U"]) do
                local unit_name = pfDB["units"]["loc"][unit]
                if unit_name and not drop_sources[unit_name] then
                  drop_sources[unit_name] = true
                  local unit_level = units[unit] and units[unit]["lvl"] or "?"
                  sources_with_levels[unit_name] = {level = unit_level, chance = chance}
                end
              end
            end

            if items[item]["O"] then
              for object, chance in pairs(items[item]["O"]) do
                local obj_name = pfDB["objects"]["loc"][object]
                if obj_name and not drop_sources[obj_name] then
                  drop_sources[obj_name] = true
                  sources_with_levels[obj_name] = {level = "Object", chance = chance}
                end
              end
            end

            if items[item]["R"] then
              for ref, chance in pairs(items[item]["R"]) do
                if refloot[ref] then
                  if refloot[ref]["U"] then
                    for unit in pairs(refloot[ref]["U"]) do
                      local unit_name = pfDB["units"]["loc"][unit]
                      if unit_name and not drop_sources[unit_name] then
                        drop_sources[unit_name] = true
                        local unit_level = units[unit] and units[unit]["lvl"] or "?"
                        sources_with_levels[unit_name] = {level = unit_level, chance = chance}
                      end
                    end
                  end

                  if refloot[ref]["O"] then
                    for object in pairs(refloot[ref]["O"]) do
                      local obj_name = pfDB["objects"]["loc"][object]
                      if obj_name and not drop_sources[obj_name] then
                        drop_sources[obj_name] = true
                        sources_with_levels[obj_name] = {level = "Object", chance = chance}
                      end
                    end
                  end
                end
              end
            end

            local sources_text = ""
            local source_count = 0
            local display_count = 0
            for source_name in pairs(drop_sources) do
              source_count = source_count + 1
            end

            for source_name in pairs(drop_sources) do
              display_count = display_count + 1
              if display_count > 1 then sources_text = sources_text .. ", " end
              sources_text = sources_text .. source_name
              if display_count >= 3 then
                if source_count > 3 then
                  sources_text = sources_text .. " (+" .. (source_count - 3) .. " more)"
                end
                break
              end
            end

            local best_source = nil
            local best_count = 0

            if items[item]["U"] then
              for unit, chance in pairs(items[item]["U"]) do
                if units[unit] and units[unit]["coords"] then
                  local count = table.getn(units[unit]["coords"])
                  if count > best_count then
                    best_count = count
                    best_source = {type = "unit", id = unit}
                  end
                end
              end
            end

            if items[item]["O"] then
              for object, chance in pairs(items[item]["O"]) do
                if objects[object] and objects[object]["coords"] then
                  local count = table.getn(objects[object]["coords"])
                  if count > best_count then
                    best_count = count
                    best_source = {type = "object", id = object}
                  end
                end
              end
            end

            if items[item]["R"] then
              for ref, chance in pairs(items[item]["R"]) do
                if refloot[ref] then
                  if refloot[ref]["U"] then
                    for unit in pairs(refloot[ref]["U"]) do
                      if units[unit] and units[unit]["coords"] then
                        local count = table.getn(units[unit]["coords"])
                        if count > best_count then
                          best_count = count
                          best_source = {type = "unit", id = unit}
                        end
                      end
                    end
                  end

                  if refloot[ref]["O"] then
                    for object in pairs(refloot[ref]["O"]) do
                      if objects[object] and objects[object]["coords"] then
                        local count = table.getn(objects[object]["coords"])
                        if count > best_count then
                          best_count = count
                          best_source = {type = "object", id = object}
                        end
                      end
                    end
                  end
                end
              end
            end

            if best_source then
              local coords_table = best_source.type == "unit" and units[best_source.id]["coords"] or objects[best_source.id]["coords"]

              local zones_coords = {}
              for _, data in pairs(coords_table) do
                local x, y, zone = unpack(data)
                if zone > 0 and not zones_coords[zone] then
                  zones_coords[zone] = {x, y}
                end
              end

              for zone, coords in pairs(zones_coords) do
                local item_meta = {}
                for k, v in pairs(meta or {}) do item_meta[k] = v end

                item_meta["quest"] = pfDB["quests"]["loc"][id] and pfDB["quests"]["loc"][id].T or UNKNOWN
                item_meta["questid"] = id
                item_meta["QTYPE"] = "ITEM_START"
                item_meta["layer"] = 3
                item_meta["texture"] = pfQuestConfig.path.."\\img\\available"
                --item_meta["vertex"] = { 0.7, 0.4, 1 }
                item_meta["spawn"] = pfDB["items"]["loc"][item] or UNKNOWN
                item_meta["spawnid"] = item
                item_meta["item"] = pfDB["items"]["loc"][item]
                item_meta["dropsources"] = sources_text
                item_meta["dropsources_levels"] = sources_with_levels
                item_meta["title"] = item_meta["quest"]
                item_meta["zone"] = zone
                item_meta["x"] = coords[1]
                item_meta["y"] = coords[2]
                item_meta["level"] = pfQuest_Loc["N/A"]
                item_meta["spawntype"] = pfQuest_Loc["Item Drop"]
                item_meta["respawn"] = pfQuest_Loc["N/A"]
                item_meta["qlvl"] = quests[id]["lvl"]
                item_meta["qmin"] = quests[id]["min"]

                if quests[id]["min"] and quests[id]["min"] > plevel then
                  item_meta["vertex"] = { 1, .6, .6 }
                  item_meta["layer"] = 2
                elseif quests[id]["lvl"] and quests[id]["lvl"] <= GetGrayLevel(plevel) then
                  item_meta["vertex"] = { 1, 1, 1 }
                  item_meta["layer"] = 2
                elseif quests[id]["event"] then
                  item_meta["vertex"] = { .2, .8, 1 }
                  item_meta["layer"] = 2
                end

                item_meta["description"] = pfDatabase:BuildQuestDescription(item_meta)

                maps = maps or {}
                maps[zone] = maps[zone] and maps[zone] + 1 or 1
                pfMap:AddNode(item_meta)
              end
            end
          end
        end
      end
    end
  end

  return maps
end

local originalNodeEnter = pfMap.NodeEnter
pfMap.NodeEnter = function()
  if not this or not this.node then
    if originalNodeEnter then originalNodeEnter() end
    return
  end

  local hasItemStart = false
  local itemStartMeta = nil
  for title, meta in pairs(this.node) do
    if meta.QTYPE == "ITEM_START" and meta.dropsources_levels then
      hasItemStart = true
      itemStartMeta = meta
      break
    end
  end

  if hasItemStart and itemStartMeta then
    if pfQuestCompat and pfQuestCompat.client and pfQuestCompat.client >= 30300 then
      WorldMapPOIFrame.allowBlobTooltip = false
    end

    local tooltip = this:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
    tooltip:SetOwner(this, "ANCHOR_LEFT")
    this.spawn = this.spawn or UNKNOWN
    tooltip:SetText(this.spawn..(pfQuest_config.showids == "1" and " |cffcccccc("..this.spawnid..")|r" or ""), .3, 1, .8)
    tooltip:AddDoubleLine(pfQuest_Loc["Type"] .. ":", (this.spawntype or UNKNOWN), .8,.8,.8, 1,1,1)

    if itemStartMeta.dropsources_levels then
      tooltip:AddLine(" ")
      tooltip:AddLine("Drops from:", .8,.8,.8)

      local sorted_sources = {}
      for source_name, data in pairs(itemStartMeta.dropsources_levels) do
        table.insert(sorted_sources, {name = source_name, level = data.level, chance = data.chance or 0})
      end

      table.sort(sorted_sources, function(a, b)
        return a.chance > b.chance
      end)

      local count = 0
      for _, source in ipairs(sorted_sources) do
        count = count + 1
        if count <= 5 then
          tooltip:AddLine("  " .. source.name .. " (" .. source.level .. ") - " .. source.chance .. "%", 1,1,1)
        end
      end

      if table.getn(sorted_sources) > 5 then
        tooltip:AddLine("  (+" .. (table.getn(sorted_sources) - 5) .. " more)", .7,.7,.7)
      end
    end

    tooltip:AddLine(" ")

    for title, meta in pairs(this.node) do
      pfMap:ShowTooltip(meta, tooltip)
    end

    if pfQuest_config["tooltiphelp"] == "1" then
      local text = pfQuest_Loc["Use <Shift>-Click To Mark Quest As Done"]
      tooltip:AddLine(text, .6, .6, .6)
      tooltip:Show()
    end

    pfMap.highlight = pfQuest_config["mouseover"] == "1" and this.title
  else
    if originalNodeEnter then
      originalNodeEnter()
    end
  end
end

function pfDatabase:BuildQuestDescription(meta)
  if not meta.title or not meta.quest or not meta.QTYPE then return meta.description end

  if meta.QTYPE == "NPC_START" then
    return string.format(pfQuest_Loc["Speak with |cff33ffcc%s|r to obtain |cffffcc00[!]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
  elseif meta.QTYPE == "OBJECT_START" then
    return string.format(pfQuest_Loc["Interact with |cff33ffcc%s|r to obtain |cff66ff66[!]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
  elseif meta.QTYPE == "ITEM_START" then
    if meta.dropsources and meta.dropsources ~= "" then
      return string.format(pfQuest_Loc["Loot |cff33ffcc[%s]|r from |cff33ffcc%s|r to obtain |cff66ff66[!]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), meta.dropsources, (meta.quest or UNKNOWN))
    else
      return string.format(pfQuest_Loc["Loot |cff33ffcc[%s]|r to obtain |cff66ff66[!]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
    end
  elseif meta.QTYPE == "NPC_END" then
    return string.format(pfQuest_Loc["Speak with |cff33ffcc%s|r to complete |cffffcc00[?]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
  elseif meta.QTYPE == "OBJECT_END" then
    return string.format(pfQuest_Loc["Interact with |cff33ffcc%s|r to complete |cffffcc00[?]|cff33ffcc %s|r"], (meta.spawn or UNKNOWN), (meta.quest or UNKNOWN))
  elseif meta.QTYPE == "UNIT_OBJECTIVE" then
    if pfDatabase:IsFriendly(meta.spawnid) then
      return string.format(pfQuest_Loc["Talk to |cff33ffcc%s|r"], (meta.spawn or UNKNOWN))
    else
      return string.format(pfQuest_Loc["Kill |cff33ffcc%s|r"], (meta.spawn or UNKNOWN))
    end
  elseif meta.QTYPE == "UNIT_OBJECTIVE_ITEMREQ" then
    return string.format(pfQuest_Loc["Use |cff33ffcc%s|r on |cff33ffcc%s|r"], (meta.itemreq or UNKNOWN), (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "OBJECT_OBJECTIVE" then
    return string.format(pfQuest_Loc["Interact with |cff33ffcc%s|r"], (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "OBJECT_OBJECTIVE_ITEMREQ" then
    return string.format(pfQuest_Loc["Use |cff33ffcc%s|r at |cff33ffcc%s|r"], (meta.itemreq or UNKNOWN), (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "ITEM_OBJECTIVE_LOOT" then
    return string.format(pfQuest_Loc["Loot |cff33ffcc[%s]|r from |cff33ffcc%s|r"], (meta.item or UNKNOWN), (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "ITEM_OBJECTIVE_USE" then
    return string.format(pfQuest_Loc["Loot and/or Use |cff33ffcc[%s]|r from |cff33ffcc%s|r"], (meta.item or UNKNOWN), (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "AREATRIGGER_OBJECTIVE" then
    return string.format(pfQuest_Loc["Explore |cff33ffcc%s|r"], (meta.spawn or UNKNOWN))
  elseif meta.QTYPE == "ZONE_OBJECTIVE" then
    return string.format(pfQuest_Loc["Use Quest Item at |cff33ffcc%s|r"], (meta.spawn or UNKNOWN))
  end
end
