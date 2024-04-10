local loc = GetLocale()
local dbs = { "items", "quests", "quests-itemreq", "objects", "units", "zones", "professions", "areatrigger", "refloot" }
local noloc = { "items", "quests", "objects", "units" }

-- Patch databases to merge ProjectEpoch data
local function patchtable(base, diff)
  for k, v in pairs(diff) do
    if base[k] and type(v) == "table" then
      patchtable(base[k], v)
    elseif type(v) == "string" and v == "_" then
      base[k] = nil
    else
      base[k] = v
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

-- Reload all pfQuest internal database shortcuts
pfDatabase:Reload()

function hcstrsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local major, minor, fix = hcstrsplit(".", tostring(GetAddOnMetadata("pfQuest-epoch", "Version")))
fix = fix or 0 -- Set fix to 0 if it is nil

local alreadyshown = false
local localversion  = tonumber(major*10000 + minor*100 + fix)
local remoteversion = tonumber(gpiupdateavailable) or 0
local loginchannels = { "BATTLEGROUND", "RAID", "GUILD", "PARTY" }
local groupchannels = { "BATTLEGROUND", "RAID", "PARTY" }
  
gpiupdater = CreateFrame("Frame")
gpiupdater:RegisterEvent("CHAT_MSG_ADDON")
gpiupdater:RegisterEvent("PLAYER_ENTERING_WORLD")
gpiupdater:RegisterEvent("PARTY_MEMBERS_CHANGED")
gpiupdater:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local arg1, arg2 = ...
        if arg1 == "pfqe" then
            local v, remoteversion = hcstrsplit(":", arg2)
            remoteversion = tonumber(remoteversion)
            if v == "VERSION" and remoteversion then
                if remoteversion > localversion then
                    gpiupdateavailable = remoteversion
                    if not alreadyshown then
                        print("|cff6699ffG|cff66aaffu|cff66bbffi|cff66ccffl|cff66ddffd|cff66eeffP|cff77ffffa|cff88ffffr|cff99fffft|cffaaffffy|cffbbffffI|cffccffffn|cffddffffv|cffffffffite|r New version available! |cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
                        alreadyshown = true
                    end
                end
            end
            --This is a little check that I can use to see if people are actually using the addon.
            if v == "PING?" then
                for _, chan in ipairs(loginchannels) do
                    SendAddonMessage("pfqe", "PONG!:"..GetAddOnMetadata("GuildPartyInvite", "Version"), chan)
                end
            end
            if v == "PONG!" then
                --print(arg1 .." "..arg2.." "..arg3.." "..arg4)
            end
        end

        if event == "PARTY_MEMBERS_CHANGED" then
            local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
            if (this.group or 0) < groupsize then
                for _, chan in ipairs(groupchannels) do
                    SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
                end
            end
            this.group = groupsize
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not alreadyshown and localversion < remoteversion then
            print("|cff6699ffG|cff66aaffu|cff66bbffi|cff66ccffl|cff66ddffd|cff66eeffP|cff77ffffa|cff88ffffr|cff99fffft|cffaaffffy|cffbbffffI|cffccffffn|cffddffffv|cffffffffite|r New version available! |cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
            gpiupdateavailable = localversion
            alreadyshown = true
        end

        for _, chan in ipairs(loginchannels) do
            SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
        end
    end
end)