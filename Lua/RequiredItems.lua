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
        if submarine == nil or other.Submarine == submarine then
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

--[[ Лодка, к которой крепят. Ваниль берёт её от точки крепления
     (Holdable.cs:912), но саму точку считает приватный GetAttachPosition -
     из Lua его не видно. Ближайшее доступное - структура под курсором:
     крепить можно только туда, где она есть, это и проверяет CanBeAttached.

     character.Submarine как замена не годится: он равен nil у всех, кто вне
     корпуса, а снаружи к обшивке крепят регулярно. Получался бы подсчёт по
     «ничьим» предметам, то есть ноль, то есть лимита нет вообще. Поэтому
     последний запасной вариант - nil, а он означает «считать всё подряд»:
     ошибиться в строгую сторону лучше, чем раздать безлимит. ]]
local function attachTargetSub(character, item)
    local ok, sub = pcall(function()
        local target = Structure.GetAttachTarget(character.CursorWorldPosition)
        return target ~= nil and target.Submarine or nil
    end)
    if ok and sub ~= nil then return sub end
    return character.Submarine or item.Submarine
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

        local installed = countAttached(group, attachTargetSub(character, instance.Item))
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

     Два подвоха, из-за которых код выглядит сложнее, чем «подняли уровень».

     1. SecondaryUse зовётся КАЖДЫЙ КАДР, пока зажат Aim (Character.cs:2517,
        requireaimtosecondaryuse по умолчанию true). Удаление предмета при этом
        отложенное - очередь разбирается в MapEntity.UpdateAll. Ваниль в своих
        чертежах от повтора защищается сливом Condition; у нас такого нет,
        поэтому книга помечается израсходованной сразу, в spentBooks.
     2. Entity.Spawner.AddItemToRemoveQueue на клиенте не делает ничего вовсе
        (EntitySpawner.cs:383, ранний return при IsClient). То есть на клиенте
        книга не исчезнет и своей отметки ему тем более не хватает.

     Отсюда правило: состояние меняет только авторитетная сторона - сервер,
     а в сингле клиент, потому что сервера там нет. Клиент в сети лишь
     показывает сообщение, его CampaignMetadata приедет синхронизацией.
   ====================================================================== ]]

local BOOK_PREFIX = "RIBABook"

local spentBooks = {} -- Item.ID -> книга уже отдала свой уровень

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

        ptable.PreventExecution = true

        local msgCategory = "book" .. category .. character.Name

        -- Потолок: книга не тратится, её можно продать обратно. Повторные
        -- нажатия не страшны, от спама спасает кулдаун категории.
        if RibaPI.Levels.Get(category) >= RibaPI.Levels.Max then
            if CLIENT and character == Character.Controlled then
                RibaPI.ScreenMessage.Big(
                    (RibaPI.Text("bookmaxed") or "") ..
                    " [" .. RibaPI.Levels.Max .. "/" .. RibaPI.Levels.Max .. "]",
                    Color.Yellow, msgCategory, 5)
            end
            return
        end

        if spentBooks[instance.Item.ID] then return end
        spentBooks[instance.Item.ID] = true

        local level = RibaPI.Levels.Get(category) + 1 -- то, что увидит игрок

        if SERVER or Game.IsSingleplayer then
            level = RibaPI.Levels.Raise(category)
            for _, other in ipairs(Character.CharacterList) do
                RibaPI.Levels.SyncTalents(other)
            end
            Entity.Spawner.AddItemToRemoveQueue(instance.Item)
        end

        if CLIENT and character == Character.Controlled then
            RibaPI.ScreenMessage.Big(
                (RibaPI.Text("bookread") or "") ..
                " [" .. level .. "/" .. RibaPI.Levels.Max .. "]",
                Color.Green, msgCategory, 5)
        end
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
