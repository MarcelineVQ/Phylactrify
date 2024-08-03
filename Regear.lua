-- Name: Regear
-- License: LGPL v2.1

local DEBUG_MODE = false

local success = true
local failure = nil

local function amprint(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(text)
    if DEBUG_MODE == true then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

-- taken from supermacros
local function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

local function FindInvItemSlot(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	for i = 1,23 do
		link = GetInventoryItemLink("player",i);
		if ( link ) then
			if ( item == string.lower(ItemLinkToName(link)) )then
				return i
			end
		end
	end
end

-- adapted from supermacros
local function FindBagItem(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	local count, bag, slot, texture;
	local totalcount = 0;
	for i = 0,NUM_BAG_FRAMES do
		for j = 1,MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i,j);
			if ( link ) then
				if ( item == string.lower(ItemLinkToName(link))) then
					bag, slot = i, j;
					texture, count = GetContainerItemInfo(i,j);
					totalcount = totalcount + count;
				end
			end
		end
	end
	return bag, slot, texture, totalcount;
end


local function FindItem(item)
	if ( not item ) then return; end
	item = string.lower(ItemLinkToName(item));
	local link;
	for i = 1,23 do
		link = GetInventoryItemLink("player",i);
		if ( link ) then
			if ( item == string.lower(ItemLinkToName(link)) )then
				return i, nil, GetInventoryItemTexture('player', i), GetInventoryItemCount('player', i);
			end
		end
	end
	local count, bag, slot, texture;
	local totalcount = 0;
	for i = 0,NUM_BAG_FRAMES do
		for j = 1,MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i,j);
			if ( link ) then
				if ( item == string.lower(ItemLinkToName(link))) then
					bag, slot = i, j;
					texture, count = GetContainerItemInfo(i,j);
					totalcount = totalcount + count;
				end
			end
		end
	end
	return bag, slot, texture, totalcount;
end

-------------------------------------------------

-- User Options
local defaults =
{
  enabled = true,
  naxx_only = false,
  do_toggle = false,
  item_slot = 13,
  announce = true,
  item_link = "|cffa335ee|Hitem:23206:0:0:0:0:0:0:0:0|h[Mark of the Champion]|h|r",
}

local function checkItemSlot(slot,item)
  local slot_link = GetInventoryItemLink("player",slot)
  if slot_link then
    local _,_,slotItem,_ = string.find(slot_link,"|h%[?([^%[%]]*)%]|h")
    local s1,s2 = string.lower(ItemLinkToName(slotItem)),string.lower(ItemLinkToName(item))
    debug_print("checkItemSlot:"..s1)
    debug_print("checkItemSlot:"..s2)
    if s1 == s2 then return slot end
  end
end

local function checkNaxx()
  if RegearSettings.naxx_only then
    return GetZoneText() == "Naxxramas" or GetZoneText() == "The Upper Necropolis"
  else
    return true
  end
end

local Regear = CreateFrame("FRAME")

local function OnEvent()
  if RegearSettings.do_toggle
      and checkNaxx()
      and not UnitIsDeadOrGhost("player")
      and event == "BAG_UPDATE" then
    debug_print("player inv changed")
    local b,s,_ = FindItem(RegearSettings.item_link)
    if b and s then
      PickupContainerItem(b,s)
      EquipCursorItem(RegearSettings.item_slot)
    end
    RegearSettings.do_toggle = false
    if RegearSettings.announce then
      amprint(RegearSettings.item_link .. " cycled off and on.")
    end
  elseif event == "PLAYER_DEAD" then
    debug_print("player dead")
    local slot,in_bag,_ = FindItem(RegearSettings.item_link)
    debug_print(RegearSettings.item_slot)
    if slot and not in_bag then
      RegearSettings.item_slot = slot
      local link = GetInventoryItemLink("player",RegearSettings.item_slot)
      RegearSettings.item_link = link
      RegearSettings.do_toggle = true
      debug_print(RegearSettings.item_slot)
    end
  elseif RegearSettings.do_toggle
      and checkNaxx()
      and (event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE")
      and not UnitIsDeadOrGhost("player") then
    debug_print("player not dead")
    PickupInventoryItem(RegearSettings.item_slot)
    PutItemInBackpack()
  end
end

local function Init()
  if event == "ADDON_LOADED" and arg1 == "Regear" then
    Regear:UnregisterEvent("ADDON_LOADED")
    if not RegearSettings
      then RegearSettings = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          if RegearSettings[k] == nil -- specifically nil
            then s[k] = defaults[k]
            else s[k] = RegearSettings[k] end
        end
        -- is the above just: s[k] = ((AutoManaSettings[k] == nil) and defaults[k]) or AutoManaSettings[k]
        RegearSettings = s
      end
  end
  Regear:SetScript("OnEvent", OnEvent)
end

Regear:RegisterEvent("BAG_UPDATE")
Regear:RegisterEvent("PLAYER_DEAD")
-- Regear:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
Regear:RegisterEvent("PLAYER_UNGHOST") -- literally unghosting, so becoming alive again by any means after being a ghost
Regear:RegisterEvent("PLAYER_ALIVE") -- when you release to ghost, or are rezzed. in othe words, when you were dead but have control again
Regear:RegisterEvent("ADDON_LOADED")
Regear:SetScript("OnEvent", Init)

local function showOnOff(setting)
  return setting and "True" or "False"
end

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end
  if args[1] == "naxx" or args[1] == "naxxramas" then
    RegearSettings.naxx_only = not RegearSettings.naxx_only
    amprint("Use in Naxxramas Only: "..showOnOff(RegearSettings.naxx_only))
  elseif args[1] == "enabled" or args[1] == "enable" or args[1] == "toggle" then
    RegearSettings.enabled = not RegearSettings.enabled
    amprint("Addon enabled: "..showOnOff(RegearSettings.enabled))
  elseif args[1] == "announce" then
    RegearSettings.announce = not RegearSettings.announce
    amprint("Addon enabled: "..showOnOff(RegearSettings.enabled))
  elseif args[1] == "item" and args[2] then
    -- This needs to immediately scan for the item otherwise player might have typod
    table.remove(args,1)
    local item = table.concat(args, " ")
    debug_print(item)

    local slot,in_bag,_ = FindItem(item)
    local link
    if slot then 
      if in_bag then
        link = GetContainerItemLink(slot,in_bag)
      else
        link = GetInventoryItemLink("player",slot)
      end
      RegearSettings.item_link = link
      amprint("Tracking enabled for: "..RegearSettings.item_link)
    else
      amprint("Item not found on character or in bags, did you mis-spell?")
    end
  else
    amprint('Regear: Automatically re-equip '..RegearSettings.item_link..' on death.')
    amprint('- Addon [enabled]: ' .. showOnOff(RegearSettings.enabled))
    amprint('- Active only in [naxx]ramas: ' .. showOnOff(RegearSettings.naxx_only))
    amprint('- [announce] the swap: ' .. showOnOff(RegearSettings.announce))
    amprint('- Custom [item] to track (via name or link): ' .. RegearSettings.item_link)
  end
end

SLASH_REGEAR1 = "/regear";
SlashCmdList["REGEAR"] = handleCommands
