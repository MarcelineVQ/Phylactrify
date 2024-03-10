-- Name: Phylactrify
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
function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

function FindInvItemSlot(item)
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

function checkItemSlot(slot,item)
  local slot_link = GetInventoryItemLink("player",slot)
  if slot_link then
    local _,_,slotItem,_ = string.find(slot_link,"|h%[?([^%[%]]*)%]|h")
    local s1,s2 = string.lower(ItemLinkToName(slotItem)),string.lower(ItemLinkToName(item))
    debug_print("checkItemSlot:"..s1)
    debug_print("checkItemSlot:"..s2)
    if s1 == s2 then return slot end
  end
end

function checkNaxx()
  if PhylactrifySettings.naxx_only then
    return GetZoneText() == "Naxxramas" or GetZoneText() == "The Upper Necropolis"
  else
    return true
  end
end

local Phylactrify = CreateFrame("FRAME")

local loaded = false

-- /run hadPhylactryAtDeath = true
local function OnEvent()
  if loaded then
    if PhylactrifySettings.do_toggle
        and checkNaxx()
        and not UnitIsDeadOrGhost("player")
        and event == "BAG_UPDATE" then
      debug_print("player inv changed")
      local b,s,_ = FindBagItem(PhylactrifySettings.item_link)
      if b and s then
        PickupContainerItem(b,s)
        EquipCursorItem(PhylactrifySettings.item_slot)
      end
      PhylactrifySettings.do_toggle = false
      if PhylactrifySettings.announce then
        amprint(PhylactrifySettings.item_link .. " cycled off and on.")
      end
    elseif event == "PLAYER_DEAD" then
      debug_print("player dead")
      local slot = FindInvItemSlot(PhylactrifySettings.item_link)
      debug_print(PhylactrifySettings.item_slot)
      if slot then -- PhylactrifySettings.item_slot then
        PhylactrifySettings.item_slot = slot
        local link = GetInventoryItemLink("player",PhylactrifySettings.item_slot)
        PhylactrifySettings.item_link = link
        PhylactrifySettings.do_toggle = true
        debug_print(PhylactrifySettings.item_slot)
      end
    elseif PhylactrifySettings.do_toggle
        and checkNaxx()
        and (event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE")
        and not UnitIsDeadOrGhost("player") then
      debug_print("player not dead")
      PickupInventoryItem(PhylactrifySettings.item_slot)
      PutItemInBackpack()
    end
  elseif event == "ADDON_LOADED" then
    Phylactrify:UnregisterEvent("ADDON_LOADED")
    if not PhylactrifySettings
      then PhylactrifySettings = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          if PhylactrifySettings[k] == nil -- specifically nil
            then s[k] = defaults[k]
            else s[k] = PhylactrifySettings[k] end
        end
        -- is the above just: s[k] = ((AutoManaSettings[k] == nil) and defaults[k]) or AutoManaSettings[k]
        PhylactrifySettings = s
      end
    loaded = true
  end
end

Phylactrify:RegisterEvent("BAG_UPDATE")
Phylactrify:RegisterEvent("PLAYER_DEAD")
-- Phylactrify:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
Phylactrify:RegisterEvent("PLAYER_UNGHOST") -- literally unghosting, so becoming alive again by any means after being a ghost
Phylactrify:RegisterEvent("PLAYER_ALIVE") -- when you release to ghost, or are rezzed. in othe words, when you were dead but have control again
Phylactrify:RegisterEvent("ADDON_LOADED")
Phylactrify:SetScript("OnEvent", OnEvent)

local function showOnOff(setting)
  return setting and "True" or "False"
end

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end
  if args[1] == "naxx" or args[1] == "naxxramas" then
    PhylactrifySettings.naxx_only = not PhylactrifySettings.naxx_only
    amprint("Use in Naxxramas Only: "..showOnOff(PhylactrifySettings.naxx_only))
  elseif args[1] == "enabled" or args[1] == "enable" or args[1] == "toggle" then
    PhylactrifySettings.enabled = not PhylactrifySettings.enabled
    amprint("Addon enabled: "..showOnOff(PhylactrifySettings.enabled))
  elseif args[1] == "announce" then
    PhylactrifySettings.announce = not PhylactrifySettings.announce
    amprint("Addon enabled: "..showOnOff(PhylactrifySettings.enabled))
  elseif args[1] == "item" and args[2] then
    -- This needs to immediately scan for the item otherwise player might have typod
    table.remove(args,1)
    local item = table.concat(args, " ")
    debug_print(item)

    local inv_slot = FindInvItemSlot(item)
    local b,s = FindBagItem(item)
    if inv_slot then 
      link = GetInventoryItemLink("player",inv_slot)
      PhylactrifySettings.item_link = link
      amprint("Tracking enabled for: "..PhylactrifySettings.item_link)
    elseif s and b then
      link = GetContainerItemLink(b,s)
      PhylactrifySettings.item_link = link
      amprint("Tracking enabled for: "..PhylactrifySettings.item_link)
    else
      amprint("Item not found on character or in bags, did you mis-spell?")
    end
  else
    amprint('Phylactrify: Automatically re-equip '..PhylactrifySettings.item_link..' on death.')
    amprint('- Addon [enabled]: ' .. showOnOff(PhylactrifySettings.enabled))
    amprint('- Active only in [naxx]ramas: ' .. showOnOff(PhylactrifySettings.naxx_only))
    amprint('- [announce] the swap: ' .. showOnOff(PhylactrifySettings.announce))
    amprint('- Custom [item] to track (via name or link): ' .. PhylactrifySettings.item_link)
  end
end

SLASH_PHYLACTRIFY1 = "/phylactrify";
SlashCmdList["PHYLACTRIFY"] = handleCommands
