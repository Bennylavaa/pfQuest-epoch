# How to contribute
<!--toc:start-->
  - [Introduction](#introduction)
  - [Macros](#macros)
  - [Example](#example)
  - [Issue](#issue)
  - [Pull request](#pull-request)
<!--toc:end-->

---

## Introduction

To help include or improve data in this project you can either open an issue 
or create a pull request.

Gather as much data as you can about the thing you want to add.
For quests this will be, starting entity (npc, object or item), ending entity,
objectives, english quest text (see macros below).

[Zone IDs](https://github.com/Bennylavaa/wowchat-epoch/blob/main/src/main/resources/pre_cata_areas.csv)

## Macros

### Your Current Cords:
```lua
/run SetMapToCurrentZone()local x,y=GetPlayerMapPosition("player") print(format("%s, %s: { %.1f, %.1f, %s, 0 }",GetZoneText(),GetSubZoneText(),x*100,y*100,pfMap:GetMapID(GetCurrentMapContinent(),GetCurrentMapZone())or"nil"))
```

### Quick Target Coords: (ready to copy-paste)
```lua
/run local x,y=GetPlayerMapPosition("player")local g=UnitGUID("target")print(format("%s: { %.1f, %.1f, %s, 0 }",tonumber(strsub(g or"",8,12),16)or"nil",x*100,y*100,pfMap:GetMapID(GetCurrentMapContinent(),GetCurrentMapZone())or"nil"))
```
Format:
```lua
{TARGET_ID#}: { x, y, zoneid, 0 }
```

If `zoneid` returns `nil`, the current zone is not recognized. See [Custom Map IDs](#custom-map-ids) below.

### Targeted Unit Information:
```lua
/run local t="target" local g=UnitGUID(t) if g then print("\nUnit ID:",tonumber(strsub(g,8,12),16),"\nName:",UnitName(t),"\nLevel:",UnitLevel(t),"\nRank:",UnitClassification(t),"\n")end
```

### Selected QuestLog Data:
```lua
/run local t,l,_,_,_,_,_,_,i=GetQuestLogTitle(GetQuestLogSelection()) print("\nQuest ID: "..i.."\nLevel: "..l.."\n[\"T\"] = \""..t.."\"\n[\"O\"] = \""..QuestInfoObjectivesText:GetText().."\"\n[\"D\"] = \""..QuestInfoDescriptionText:GetText().."\"\n")
```

### Hover Over Item ID:
```lua
/run local _,l=GameTooltip:GetItem()local id=l and tonumber(l:match("item:(%d+):"))if id then print("\nItem ID:",id,"\nName:",l,"\n")end
```

### Object ID:
If you know of a way to extract this from the client make an issue

### Custom Map IDs:
Needed as the key for `epoch_customids` in `patchtable.lua` (`pfMap:GetMapID`),
since instances aren't reachable through the normal `GetMapZones()` zone list
(`GetCurrentMapContinent()` returns `-1` while inside one).
```lua
/run local c,z=GetCurrentMapContinent(),GetCurrentMapZone()print("\nMapInfo: "..tostring(GetMapInfo()).."\npfMapID: "..tostring(pfMap:GetMapID(c,z)).."\nContinent: "..c.."\nZone: "..z.."\nDungeonLevel: "..GetCurrentMapDungeonLevel())
```

## Example
Demo quest commit: [Do Slavers Keep Records?
](https://github.com/Bennylavaa/pfQuest-epoch/commit/39abc567413a0c004ea22ec38fed4eb2e486e9d6)

### Issue
First search in issues to see if there already is one for whatever addition you
want to report.
Gather as much information you can about what you want to add.
This can be npc names, items, quest objectives, coordinates, zone, and so on.
You can use the macros from the section above to help.
Make a issue over at [issues](https://github.com/Bennylavaa/pfQuest-epoch/issues)

### Pull request
If you have the technical knowhow to edit and make a pull request then please
checkout the [db spec](Db.md) to learn more about the structure of the addon.

Note that not all id's are included in this project. Try to make sure the
things you are adding like objects/items/npcs are not in the original pfquest adddon
since they exist in vanilla.
