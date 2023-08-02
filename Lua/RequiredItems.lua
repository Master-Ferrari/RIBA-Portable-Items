---@diagnostic disable: undefined-field, redundant-parameter, return-type-mismatch

-- RIBA.isSelected = function(item, character)

--     local success, result = pcall(function()
--         local selectedItem = character.SelectedItem.Prefab.Identifier.Value

--         if not CLIENT then
--             print("(((((")
--         end

--         if item == character.SelectedItem then
--             -- print("урааа")
--             return true
--         end
--         return false
--     end)

--     if success then
--         return result
--     else
--         if not CLIENT then
--             print("RIBA: "..item.Prefab.Identifier.Value)
--             print("Selected: "..character.SelectedItem.Prefab.Identifier.Value)
--         end
--         return false
--     end
-- end

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)

    local itemName = instance.Item.Prefab.Identifier.Value

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
                RIBA.BigMessage.SetNext(RIBA.Text("blocked"), Color.Red, "blocked"..itemName)
            end

            if not CLIENT then --для моментов когда прикреплён и пытается открыться
                print("Кастуем "..itemName.." !!!!!!!!!")
                RIBA.BigMessage.ClCall(ptable["character"], RIBA.Text("blocked"), Color.Red, "blockedAndAttached"..itemName, 3)
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

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
    -- print(#"(GUI.messages)")
    -- print((GUI.IsFourByThree()))
    RIBA.BigMessage.Print()
end, Hook.HookMethodType.After)

Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    -- предупреждалку для всех предметов риба и не риба
    local itemName = instance.Item.Prefab.Identifier.Value
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
                if maxBItems == 0 then
                    RIBA.BigMessage.SetNext(RIBA.Text("books"), Color.Red, "books"..itemName)
                else
                    RIBA.BigMessage.SetNext(RIBA.Text("cantattach") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Red, "cantattach"..itemName)
                end
            else
                instance.LimitedAttachable = false
            end
            if CurrentPseudonymItems + 1 == maxBItems then
                RIBA.BigMessage.SetNext(RIBA.Text("cantattachwarning") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Yellow, "cantattachwarning"..itemName)
            end
            if CurrentPseudonymItems + 1 == maxBItems then
                ptable["character"].AddMessage("(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Yellow, true, "ribamessage1", 3)
            end
            if CurrentPseudonymItems + 1 < maxBItems then
                ptable["character"].AddMessage("(" .. (CurrentPseudonymItems + 1) .. "/" .. maxBItems .. ")", Color.Green, true, "ribamessage1", 3)
            end
        end
    end
end, Hook.HookMethodType.Before)

-- Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
--     print(#"(GUI.messages)")
--     print(#(GUI.messages))
--     RIBA.BigMessage.Print()
-- end, Hook.HookMethodType.After)
