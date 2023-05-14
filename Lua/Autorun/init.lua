if not CLIENT then return end

local BibaTable = {
    ["RIBAbunkcabinet1"] = "BIBAbunkcabinet",
    ["RIBAbunkcabinet2"] = "BIBAbunkcabinet",

    ["RIBAControlMonitor"] = "BIBAControlMonitor",
    ["RIBABuyableControlMonitor"] = "BIBAControlMonitor",

    ["RIBAControlCamera"] = "BIBAControlCamera",
    ["RIBABuyableControlCamera"] = "BIBAControlCamera",

    ["RIBAStatusMonitor"] = "BIBAStatusMonitor",
    ["RIBABuyableStatusMonitor"] = "BIBAStatusMonitor",

    ["RIBAJunctionBox"] = "BIBAJunctionBox",
    ["RIBABuyableJunctionBox"] = "BIBAJunctionBox",

    ["RIBALamp"] = "BIBALamp",
    ["RIBABuyableLamp"] = "BIBALamp",

    ["RIBAbattery"] = "BIBAbattery",
    ["RIBABuyablebattery"] = "BIBAbattery",

    ["RIBAchargingdock"] = "BIBAchargingdock",
    ["RIBABuyablechargingdock"] = "BIBAchargingdock",

    ["RIBAbigpump"] = "BIBAbigpump",
    ["RIBABuyablebigpump"] = "BIBAbigpump",

    ["RIBAsmallpump"] = "BIBAsmallpump",
    ["RIBABuyablesmallpump"] = "BIBAsmallpump",

    ["RIBAfabricator"] = "BIBAfabricator",
    ["RIBABuyablefabricator"] = "BIBAfabricator",

    ["RIBAdeconstructor"] = "BIBAdeconstructor",
    ["RIBABuyabledeconstructor"] = "BIBAdeconstructor",

    ["RIBAmedfabricator"] = "BIBAmedfabricator",
    ["RIBABuyablemedfabricator"] = "BIBAmedfabricator",

    ["RIBABunk1"] = "BIBAbunk",
    ["RIBABuyableBunk1"] = "BIBAbunk",
    ["RIBABuyableBunk2"] = "BIBAbunk",
    ["RIBABuyableBunk3"] = "BIBAbunk",

    ["RIBAChair1"] = "BIBAChair",
    ["RIBABuyableChair1"] = "BIBAChair",
    ["RIBABuyableChair2"] = "BIBAChair",
    ["RIBABuyableChair3"] = "BIBAChair",

    ["RIBAMedCurtain"] = "BIBAMedCurtain",
    ["RIBABuyableMedCurtain"] = "BIBAMedCurtain",

    ["RIBAcrateshelf2"] = "BIBAcrateshelf_4slots",
    ["RIBABuyablecrateshelf"] = "BIBAcrateshelf_4slots",
    ["RIBAcrateshelf"] = "BIBAcrateshelf_4slots",

    ["RIBAcrateshelf3"] = "BIBAcrateshelf_1slot",

    ["RIBAsuppliescabinet"] = "BIBAsuppliescabinet",
    ["RIBABuyablesuppliescabinet"] = "BIBAsuppliescabinet",

    ["RIBAmediumsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBABuyablemediumsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBAmediumwindowedsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBABuyablemediumwindowedsteelcabinet"] = "BIBAmediumsteelcabinet",

    ["RIBAsteelcabinet"] = "BIBAsteelcabinet",
    ["RIBABuyablesteelcabinet"] = "BIBAsteelcabinet",
    ["RIBAbigsteelcabinet"] = "BIBAsteelcabinet",
    ["RIBAmedcabinet"] = "BIBAsteelcabinet",
    ["RIBABuyablemedcabinet"] = "BIBAsteelcabinet",

    ["RIBAdivingsuitlocker"] = "BIBAdivingsuitlocker",
    ["RIBABuyabledivingsuitlocker"] = "BIBAdivingsuitlocker",

    ["RIBArailgunshellrack"] = "BIBArailgunshellrack",
    ["RIBABuyablerailgunshellrack"] = "BIBArailgunshellrack",

    ["RIBAcoilgunammoshelf"] = "BIBAcoilgunammoshelf",
    ["RIBABuyablecoilgunammoshelf"] = "BIBAcoilgunammoshelf",

    ["RIBAtoxcabinet"] = "BIBAtoxcabinet",
    ["RIBABuyabletoxcabinet"] = "BIBAtoxcabinet",

    ["RIBAoxygentankshelf"] = "BIBAoxygentankshelf",
    ["RIBABuyableoxygentankshelf"] = "BIBAoxygentankshelf",

    ["RIBAweaponholder"] = "BIBAweaponholder",
    ["RIBABuyableweaponholder"] = "BIBAweaponholder",

    ["RIBAextinguisherbracket"] = "BIBAextinguisherbracket",
    ["RIBABuyableextinguisherbracket"] = "BIBAextinguisherbracket",
      
    ["RIBAsecuresteelcabinet"] = "BIBAsecuresteelcabinet",
    ["RIBABuyablesecuresteelcabinet"] = "BIBAsecuresteelcabinet",

}

function GetBibaName(name)
    return BibaTable[name] or nil
end



local NextMessage = ""
local NextMessageColor = Color.Red


Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
-- предупреждалку для всех предметов риба и не риба

    local nPs = GetBibaName(instance.item.Name)
    if nPs ~= nil then

        instance.LimitedAttachable = false

        local maxBItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, nPs)

        local CurrentPseudonymItems = 0
        for _, i in ipairs(Item.ItemList) do
            local holdableComponent = i.GetComponent(Components.Holdable)
            if holdableComponent ~= nil and holdableComponent.Attached then

                local iPs = GetBibaName(i.Name)

                if iPs~=nil and iPs==nPs then
                    CurrentPseudonymItems = CurrentPseudonymItems + 1
                end
            end
        end
        
        print("  -  ")
        print("Current PseudonymItems: " .. CurrentPseudonymItems)
        print("Max     PseudonymItems: " .. maxBItems)
        print(" ")
        print("         Name: " .. instance.item.Name)
        print("PseudonymName: " .. GetBibaName(instance.item.Name) )
        print("  -  ")

        local holdableComponent = item.GetComponent(Components.Holdable)

        if CurrentPseudonymItems >= maxBItems  then
            instance.LimitedAttachable = true
            if maxBItems == 0 then
                NextMessage="Книжки читать надо!"
            else
                NextMessage="Больше ставить нельзя! ("..maxBItems.."/"..maxBItems..")"
            end
            NextMessageColor=Color.Red
        else
            instance.LimitedAttachable = false
        end

        if CurrentPseudonymItems+1 == maxBItems then
            NextMessage="Это был последний предмет такого типа! Больше ставить нельзя! ("..maxBItems.."/"..maxBItems..")"
            NextMessageColor=Color.Yellow
        end

        if CurrentPseudonymItems+1 < maxBItems then
            ptable["character"].AddMessage("("..(CurrentPseudonymItems+1).."/"..maxBItems..")", Color.GreenYellow, true, "ribames1", 3)
        end
    
    end
end, Hook.HookMethodType.Before)

Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    if NextMessage ~= "" then
        GUI.ClearMessages()
        GUI.AddMessage(NextMessage, NextMessageColor)
        NextMessage = ""
    end
    end, Hook.HookMethodType.After)