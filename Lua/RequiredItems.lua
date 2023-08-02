---@diagnostic disable: undefined-field, redundant-parameter, return-type-mismatch

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)

    local itemName = instance.Item.Prefab.Identifier.Value
    local chName = ptable["character"].Name

    local inInventory = RIBA.hasMatchingString({itemName}, function(str)
        return ptable["character"].Inventory.FindItemByIdentifier(str, false) ~= nil -- есть ли у игрока предмет
    end)
    local isSelected = true
    -- local isSelected = RIBA.isSelected(instance.Item,ptable["character"])


    -- print(ptable["character"].SelectedItem.Prefab.Identifier.Value)

    local hasMatch = false
    local RibaRequiredItems = RIBA.GetAttributeValueFromInstance(instance, "RequiredItem", "RIBA_RequiredItems")
    local isBlockWhenDeattached = RIBA.GetAttributeValueFromInstance(instance, "RequiredItem", "RIBA_blockUseWhenDeattached") == "true" and
    true or false

    if RibaRequiredItems ~= nil then
        local RibaRequiredItemsTable = RIBA.splitStringByComma(RibaRequiredItems)
        hasMatch = RIBA.idcardSearch(RibaRequiredItemsTable, ptable["character"]) -- есть ли у гирока карта
        if not hasMatch then
            hasMatch = RIBA.hasMatchingString(RibaRequiredItemsTable, function(str)
                return ptable["character"].Inventory.FindItemByIdentifier(str, false) ~= nil -- есть ли у игрока предмет
            end)
        end

        if not hasMatch then -- есть ли доступ крч
            -- print("нет ключа - закрываем")
            ptable.PreventExecution = true -- нет ключа - закрываем

            if inInventory then --для моментов когда находится в руках
                RIBA.ScreenMessage.Big(RIBA.Text("blocked"), Color.Red, "blocked"..itemName..chName)
            end

            if not CLIENT then --для моментов когда прикреплён и пытается открыться
                -- print("Кастуем "..itemName.." !!!!!!!!!")
                RIBA.ScreenMessage.ClCallBig(ptable["character"], RIBA.Text("blocked"), Color.Red, "blockedAndAttached"..itemName..chName, 3)
            end
            
            if Game.IsSingleplayer == true then
                -- print("EBZZ "..itemName.." !!!!!!!!!")
                RIBA.ScreenMessage.Big(RIBA.Text("blocked"), Color.Red, "blockedAndAttached"..itemName..chName, 20) --работает при наведении мышки((
            end

            return false
        end
    end

    if isBlockWhenDeattached then
        local attached = RIBA.Component(instance.Item, "Holdable").Attached
        if not attached then
            -- print("контейнер не на стене - закрываем")
            ptable.PreventExecution = true --контейнер не на стене - закрываем
            -- if inInventory then
            --     RIBA.BigMessage.SetNext(RIBA.Text("deattachedBlockMessage"), Color.Red, "deattachedBlockMessage"..itemName)
            -- end
            return false
        else
            -- print("контейнер на стене - открываем")
            ptable.PreventExecution = true --контейнер на стене - открываем
            return true
        end
    end
end, Hook.HookMethodType.Before)



if not CLIENT then return end

-- Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
--     RIBA.BigMessage.Print()
-- end, Hook.HookMethodType.After)

Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    -- предупреждалку для всех предметов риба и не риба
    -- print("ololo")
    local itemName = instance.Item.Prefab.Identifier.Value
    local chName = ptable["character"].Name
    local nPs = RIBA.Biba(itemName)
    if nPs ~= nil then
        local maxBItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, nPs)
        local CurrentPseudonymItems = 0
        for _, i in ipairs(Item.ItemList) do
            local holdableComponent = i.GetComponent(Components.Holdable)
            if holdableComponent ~= nil and holdableComponent.Attached then
                local iPs = RIBA.Biba(i.Prefab.Identifier.Value)
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
                        RIBA.ScreenMessage.Big(RIBA.Text("books"), Color.Red, "books"..itemName..chName)
                    else
                        RIBA.ScreenMessage.Big(RIBA.Text("cantattach") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Red, "cantattach"..itemName..chName)
                    end
                end

            else
                instance.LimitedAttachable = false
            end
            
            if ptable["character"]==Character.Controlled then
                if CurrentPseudonymItems + 1 == maxBItems then
                    RIBA.ScreenMessage.Big(RIBA.Text("cantattachwarning") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Yellow, "cantattachwarning"..itemName..chName)
                end
                if CurrentPseudonymItems + 1 == maxBItems then
                    RIBA.ScreenMessage.Small(ptable["character"], "(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Yellow, "Ylimit"..itemName..chName, 2, nil, 4, false)
                end
                if CurrentPseudonymItems + 1 < maxBItems then
                    RIBA.ScreenMessage.Small(ptable["character"], "(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Green, "Glimit"..itemName..chName, 2, nil, 4, false)
                end
            end

        end
    end
end, Hook.HookMethodType.Before)

-- Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
--     print(#"(GUI.messages)")
--     print(#(GUI.messages))
--     RIBA.BigMessage.Print()
-- end, Hook.HookMethodType.After)
