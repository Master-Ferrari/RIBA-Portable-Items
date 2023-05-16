RIBA = {}
RIBA.Path = table.pack(...)[1]
RIBA.Bibs = json.parse(File.Read(RIBA.Path .. "/bibs.json"))
-- RIBA.Language = GameMain.Client.Language


RIBA.Language = function ()
    local lang = tostring(GameSettings.CurrentConfig.Language.Value)
    if RIBA.Bibs["Text"][lang]~=nil then
        return lang
    end
    return "English"
end
RIBA.Text = function (text)
    return RIBA.Bibs["Text"][RIBA.Language()][text]
end
RIBA.Biba = function (item)
    return RIBA.Bibs["Bibs"][item]
end

print(RIBA.Language())

if not CLIENT then return end


local NextMessage = ""
local NextMessageColor = Color.Red

Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
-- предупреждалку для всех предметов риба и не риба
    print("1")
    local itemName = instance.Item.Prefab.Identifier.Value
    print(itemName)
    
    local nPs = RIBA.Biba(itemName)
    print(nPs)
    
    print("2 ".. itemName)

    if nPs ~= nil then

        print("3")
        -- instance.LimitedAttachable = false

        local maxBItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, nPs)

        local CurrentPseudonymItems = 0
        for _, i in ipairs(Item.ItemList) do
            local holdableComponent = i.GetComponent(Components.Holdable)
            if holdableComponent ~= nil and holdableComponent.Attached then

                local iPs = RIBA.Biba(i.Prefab.Identifier.Value)

                if iPs~=nil and iPs==nPs then
                    CurrentPseudonymItems = CurrentPseudonymItems + 1
                end
            end
        end
        
        print("Current PseudonymItems:    " .. CurrentPseudonymItems)
        print("Max PseudonymItems:    " .. maxBItems)
        print("         Name:    " .. itemName)
        print("PseudonymName:    " .. RIBA.Biba(itemName) )
        print("  -  ")

        local attached = instance.Attached
        if instance.Attached == false then
            if CurrentPseudonymItems >= maxBItems  then
                instance.LimitedAttachable = true
                if maxBItems == 0 then
                    NextMessage=RIBA.Text("books")
                else
                    NextMessage=RIBA.Text("cantattach").." ("..maxBItems.."/"..maxBItems..")"
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
    end
end, Hook.HookMethodType.Before)

Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    if NextMessage ~= "" then
        GUI.ClearMessages()
        GUI.AddMessage(NextMessage, NextMessageColor)
        NextMessage = ""
    end
    
    print("4")
    end, Hook.HookMethodType.After)