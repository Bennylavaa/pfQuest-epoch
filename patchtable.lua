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
