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




--[[ ======================================================================
     Лимит установки. Модель: Docs/books-and-limits.md

     Кап = база группы x (1 + уровень категории). Уровень принадлежит
     кампании, а не персонажу, поэтому одинаков для всего экипажа.

     Считаем установленное ПО ЛОДКЕ, к которой крепим, как это делает ваниль
     (Holdable.cs:912), но по группе Bibs, а не по точному префабу.
   ====================================================================== ]]

local function countAttached(group, submarine)
    local n = 0
    for _, other in ipairs(Item.ItemList) do
        if other.Submarine == submarine then
            local holdable = other.GetComponent(Components.Holdable)
            if holdable ~= nil and holdable.Attached then
                if RibaPI.Biba(other.Prefab.Identifier.Value) == group then
                    n = n + 1
                end
            end
        end
    end
    return n
end

Hook.Patch("RIBA.AttachLimit", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    local ok, err = pcall(function()
        if instance.Attached then return end

        local character = ptable["character"]
        if character == nil then return end

        local group = RibaPI.Biba(instance.Item.Prefab.Identifier.Value)
        if group == nil then return end -- предмет вне системы лимитов

        local cap = RibaPI.Levels.Cap(group)
        if cap == nil then return end

        -- ваниль считает по своему капу на точный префаб; мы сами себе арбитр
        instance.LimitedAttachable = false

        local installed = countAttached(group, character.Submarine)
        if installed >= cap then
            ptable.PreventExecution = true
            if character == Character.Controlled then
                local category = RibaPI.CategoryOf(group)
                local level = RibaPI.Levels.Get(category)
                RibaPI.ScreenMessage.Big(
                    RibaPI.Text("cantattach") .. " (" .. installed .. "/" .. cap .. ")" ..
                    "  [" .. level .. "/" .. RibaPI.Levels.Max .. "]",
                    Color.Red, "cantattach" .. group .. character.Name)
            end
            return
        end

        if character == Character.Controlled then
            local left = cap - installed - 1
            local color = left > 0 and Color.Green or Color.Yellow
            RibaPI.ScreenMessage.Small(character, "(" .. (installed + 1) .. "/" .. cap .. ")",
                color, "limit" .. group .. character.Name, 2, nil, 4, false)
        end
    end)
    if not ok then printerror("RIBA.AttachLimit: " .. tostring(err)) end
end, Hook.HookMethodType.Before)

--[[ ======================================================================
     Чтение книги. XML книги логики не содержит - вся она здесь.
   ====================================================================== ]]

local BOOK_PREFIX = "RIBABook"

Hook.Patch("RIBA.ReadBook", "Barotrauma.Items.Components.Holdable", "SecondaryUse", function(instance, ptable)
    local ok, err = pcall(function()
        local character = ptable["character"]
        if character == nil then return end

        local identifier = instance.Item.Prefab.Identifier.Value
        if identifier:sub(1, #BOOK_PREFIX) ~= BOOK_PREFIX then return end

        local category = identifier:sub(#BOOK_PREFIX + 1)
        local known = false
        for _, c in ipairs(RibaPI.Categories) do
            if c == category then known = true break end
        end
        if not known then return end

        local level, raised = RibaPI.Levels.Raise(category)

        if character == Character.Controlled then
            local text = raised and RibaPI.Text("bookread") or RibaPI.Text("bookmaxed")
            RibaPI.ScreenMessage.Big(
                (text or "") .. " [" .. level .. "/" .. RibaPI.Levels.Max .. "]",
                raised and Color.Green or Color.Yellow,
                "book" .. category .. character.Name, 5)
        end

        if raised then
            -- книга одноразовая: израсходована
            for _, other in ipairs(Character.CharacterList) do
                RibaPI.Levels.SyncTalents(other)
            end
            Entity.Spawner.AddItemToRemoveQueue(instance.Item)
        end

        ptable.PreventExecution = true
    end)
    if not ok then printerror("RIBA.ReadBook: " .. tostring(err)) end
end, Hook.HookMethodType.Before)

--[[ Витрина: при старте раунда подтягиваем таланты по уровням кампании
     и разово мигрируем старые сейвы. ]]
Hook.Add("roundStart", "RIBA.SyncLevels", function()
    RibaPI.Levels.MigrateOnce()
    for _, character in ipairs(Character.CharacterList) do
        RibaPI.Levels.SyncTalents(character)
    end
end)

Hook.Add("character.created", "RIBA.SyncLevelsForNew", function(character)
    RibaPI.Levels.SyncTalents(character)
end)
