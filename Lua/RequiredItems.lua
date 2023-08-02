---@diagnostic disable: undefined-field, redundant-parameter, return-type-mismatch

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)

    local itemName = instance.Item.Prefab.Identifier.Value
    local chName = ptable["character"].Name

    local inInventory = RibaPI.hasMatchingString({itemName}, function(str)
        return ptable["character"].Inventory.FindItemByIdentifier(str, false) ~= nil -- does the player have the item
    end)
    local hasMatch = false
    local RibaRequiredItems = RibaPI.GetAttributeValueFromInstance(instance, "RequiredItem", "RIBA_RequiredItems")
    local isBlockWhenDeattached = RibaPI.GetAttributeValueFromInstance(instance, "RequiredItem", "RIBA_blockUseWhenDeattached") == "true" and
    true or false

    if RibaRequiredItems ~= nil then
        local RibaRequiredItemsTable = RibaPI.splitStringByComma(RibaRequiredItems)
        hasMatch = RibaPI.idcardSearch(RibaRequiredItemsTable, ptable["character"]) -- does the player have an ID card
        if not hasMatch then
            hasMatch = RibaPI.hasMatchingString(RibaRequiredItemsTable, function(str)
                return ptable["character"].Inventory.FindItemByIdentifier(str, false) ~= nil -- does the player have the item
            end)
        end

        if not hasMatch then -- checking for access, you know
            ptable.PreventExecution = true -- if there is no key, we close it

            if inInventory then -- for moments when it is in the hands
                RibaPI.ScreenMessage.Big(RibaPI.Text("blocked"), Color.Red, "blocked"..itemName..chName)
            end

            if not CLIENT then -- for moments when attached and trying to open
                RibaPI.ScreenMessage.ClCallBig(ptable["character"], RibaPI.Text("blocked"), Color.Red, "blockedAndAttached"..itemName..chName, 3)
            end
            
            if Game.IsSingleplayer == true then
                RibaPI.ScreenMessage.Big(RibaPI.Text("blocked"), Color.Red, "blockedAndAttached"..itemName..chName, 20) -- works on hover ((
            end

            return false
        end
    end

    if isBlockWhenDeattached then
        local attached = RibaPI.Component(instance.Item, "Holdable").Attached
        if not attached then
            ptable.PreventExecution = true --the container is not on the wall - we close it
            return false
        else
            ptable.PreventExecution = true --the container is on the wall - open
            return true
        end
    end
end, Hook.HookMethodType.Before)



if not CLIENT then return end

Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    local itemName = instance.Item.Prefab.Identifier.Value
    local chName = ptable["character"].Name
    local nPs = RibaPI.Biba(itemName)
    if nPs ~= nil then
        local maxBItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, nPs)
        local CurrentPseudonymItems = 0
        for _, i in ipairs(Item.ItemList) do
            local holdableComponent = i.GetComponent(Components.Holdable)
            if holdableComponent ~= nil and holdableComponent.Attached then
                local iPs = RibaPI.Biba(i.Prefab.Identifier.Value)
                if iPs ~= nil and iPs == nPs then
                    CurrentPseudonymItems = CurrentPseudonymItems + 1
                end
            end
        end

        local attached = instance.Attached
        if instance.Attached == false then
            if CurrentPseudonymItems >= maxBItems then
                instance.LimitedAttachable = true

                if ptable["character"]==Character.Controlled then
                    if maxBItems == 0 then
                        RibaPI.ScreenMessage.Big(RibaPI.Text("books"), Color.Red, "books"..itemName..chName)
                    else
                        RibaPI.ScreenMessage.Big(RibaPI.Text("cantattach") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Red, "cantattach"..itemName..chName)
                    end
                end

            else
                instance.LimitedAttachable = false
            end
            
            if ptable["character"]==Character.Controlled then
                if CurrentPseudonymItems + 1 == maxBItems then
                    RibaPI.ScreenMessage.Big(RibaPI.Text("cantattachwarning") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Yellow, "cantattachwarning"..itemName..chName)
                end
                if CurrentPseudonymItems + 1 == maxBItems then
                    RibaPI.ScreenMessage.Small(ptable["character"], "(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Yellow, "Ylimit"..itemName..chName, 2, nil, 4, false)
                end
                if CurrentPseudonymItems + 1 < maxBItems then
                    RibaPI.ScreenMessage.Small(ptable["character"], "(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Green, "Glimit"..itemName..chName, 2, nil, 4, false)
                end
            end

        end
    end
end, Hook.HookMethodType.Before)
