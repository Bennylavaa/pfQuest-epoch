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
For quests this will be, starting entity(npc or object or item), ending entity
objectives, english quest text (see macros below).

[Zone IDs](https://github.com/Bennylavaa/wowchat-epoch/blob/main/src/main/resources/pre_cata_areas.csv)

## Macros

Your Current Cords:
```lua
/script SetMapToCurrentZone() local x,y=GetPlayerMapPosition("player") DEFAULT_CHAT_FRAME:AddMessage(format("%s, %s: %.1f, %.1f",GetZoneText(),GetSubZoneText(),x*100,y*100))
```


Targeted Unit Information:

```lua
/run local guid = UnitGUID("target"); local npcId = tonumber(string.sub(guid, 8, 12), 16); local npcName = UnitName("target"); print("NPC ID:", npcId, "NPC Name:", npcName)
```

Selected QuestLog Data:

```lua
/run local t, l, _, _, _, _, _, _, i = GetQuestLogTitle(GetQuestLogSelection()); print("\nID:"..i.."\nLevel:"..l.."\n[\"T\"] "..t.."\n[\"O\"] "..QuestInfoObjectivesText:GetText().."\n[\"D\"] "..QuestInfoDescriptionText:GetText())
```

Hover Over Item ID:
```lua
/run local _, link = GameTooltip:GetItem(); if link then local itemID = tonumber(link:match("item:(%d+):")); if itemID then print("Item ID:", itemID) end end
```

Object ID:
If you know of a way to extract this from the client make an issue

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

###  Pull request
If you have the technical knowhow to edit and make a pull request then please
checkout the [db spec](Db.md) to learn more about the structure of the addon.

Note that not all id's are included in this project. Try to make sure the
things you are adding like objects/items/npcs are not in the original pfquest adddon
since they exist in vanilla.
