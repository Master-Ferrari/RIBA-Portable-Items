RIBA = {}
RIBA.Path = table.pack(...)[1]
RIBA.Bibs = json.parse(File.Read(RIBA.Path .. "/lua/data.json"))

RIBA.Language = function()
    local lang = tostring(GameSettings.CurrentConfig.Language.Value)
    if RIBA.Bibs["Text"][lang] ~= nil then
        return lang
    end
    return "English"
end

RIBA.Text = function(text)
    return RIBA.Bibs["Text"][RIBA.Language()][text]
end

RIBA.Biba = function(item)
    return RIBA.Bibs["Bibs"][item]
end

local timers = {}                       -- таблица для хранения таймеров
RIBA.isTimerExpired = function(name)
    local currentTime = os.time()       -- получаем текущее время
    local expirationTime = timers[name] -- получаем время окончания таймера
    if expirationTime and currentTime >= expirationTime then
        return true  -- таймер истек
    else
        return false -- таймер не истек или не существует
    end
end
RIBA.setTimer = function(name, duration)
    timers[name] = os.time() + duration -- сохраняем время окончания таймера
    print("os.time()")
end

RIBA.BigMessage = {}
RIBA.BigMessage.Next = { "", Color.Red }
RIBA.BigMessage.Last = { "", Color.Red }
RIBA.BigMessage.SetNext = function(msg, clr, timer)
    print("SetNext1")
    if RIBA.isTimerExpired("BigMessage") then
        print("SetNext2")
        RIBA.setTimer("BigMessage", timer)
    end
    RIBA.BigMessage.Next = { msg, clr }
end
RIBA.BigMessage.Print = function()
    local success, result = pcall(function()
        local msg, clr = RIBA.BigMessage.Next[1], RIBA.BigMessage.Next[2]
        if RIBA.isTimerExpired("BigMessage") then
            print("isTimerExpired1")
            if msg ~= RIBA.BigMessage.Last[1] or clr ~= RIBA.BigMessage.Last[2] then
                print("isTimerExpired2")
                RIBA.BigMessage.Last = {msg, clr}
                GUI.ClearMessages()
                GUI.AddMessage(msg, clr)
            end
        end
    end)
end

RIBA.Component = function(item, name)
    for _, component in ipairs(item.Components) do
        if component.Name == name then
            return component
        end
    end
end

RIBA.removePrefixAndSuffix = function(input, prefix, suffix)
    local success, result = pcall(function()
        local startIdx = string.find(input, prefix)
        if startIdx then
            startIdx = startIdx + string.len(prefix)
            local endIdx = string.find(input, suffix, startIdx)
            if endIdx then
                return string.sub(input, startIdx, endIdx - 1)
            end
        end
        return nil
    end)
    if success then
        return result
    else
        return nil
    end
end

RIBA.GetAttributeValueFromInstance = function(instance, targetElement, targetAttribute)
    local success, result = pcall(function()
        local isCostylElementString = tostring(instance.originalElement.GetChildElement(tostring(targetElement))
            .GetAttribute(tostring(targetAttribute)))
        return RIBA.removePrefixAndSuffix(isCostylElementString, '"', '"')
    end)
    local isCostylElement = success and result or nil
    return isCostylElement
end

-- RIBA.GetElementFromItem = function(item, targetElement)
--     local success, result = pcall(function()
--         return tostring(item.GetComponent(Components.Holdable))
--     end)
--     local isCostylElement = success and result or nil
--     return isCostylElement
-- end

RIBA.splitStringByComma = function(inputString)
    local success, result = pcall(function()
        local result = {}
        local startIndex = 1
        for i = 1, #inputString do
            local char = inputString:sub(i, i)
            if char == "," then
                local substring = inputString:sub(startIndex, i - 1)
                substring = substring:gsub("%s", "")
                table.insert(result, substring)
                startIndex = i + 1
            end
        end
        local lastSubstring = inputString:sub(startIndex)
        lastSubstring = lastSubstring:gsub("%s", "")
        table.insert(result, lastSubstring)
        return result
    end)
    if success then
        return result
    else
        return nil
    end
end

RIBA.hasMatchingString = function(strings, condition)
    local success, result = pcall(function()
        for _, str in pairs(strings) do
            if condition(str) then
                return true
            end
        end
        return false
    end)
    if success then
        return result
    else
        return false
    end
end

RIBA.idcardSearch = function(strings, character) -- ввод типа RibaRequiredItemsTable
    local success, result = pcall(function()
        local idcardTags = {                     --какие теги будут искаться в айдикартах игроков
            { "medic",     { "id_medic", "medic", "med", "doc", "id_medical", "jobid:medicaldoctor" } },
            { "captain",   { "id_captain", "captain", "cap", "com", "commander", "jobid:captain" } },
            { "security",  { "id_security", "security", "sec", "officer", "jobid:securityofficer" } },
            { "assistant", { "id_assistant", "assistant", "ass", "jobid:assistant" } },
            { "engineer",  { "id_engineer", "engineer", "engi", "jobid:engineer" } },
            { "mechanic",  { "id_mechanic", "mechanic", "mech", "jobid:mechanic" } }
        }
        local name = ""
        local param = ""
        for i, str in ipairs(strings) do
            local splitIndex = string.find(str, ":")
            if splitIndex then --если :
                name = string.sub(str, 1, splitIndex - 1)
                param = string.sub(str, splitIndex + 1)
                if name == "idcard" then                      --если idcard
                    for _, pair in ipairs(idcardTags) do
                        local key = pair[1]                   --профессия
                        if param == key then                  --требуемая професссия зарегана
                            local values = pair[2]            --синонимы
                            for _, value in ipairs(values) do --поиск синонимов в персонаже
                                local idcard = character.Inventory.FindItemByTag(value, false)
                                if idcard ~= nil then
                                    print("idcard4")
                                    if idcard.GetComponent(Components.IdCard)~= nil then
                                        print("GetChildElement")
                                        -- table.remove(strings, i)
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end)
    if success then
        return result
    else
        return false
    end
end

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
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

        if not hasMatch then
            print("нет ключа - закрываем")
            ptable.PreventExecution = true -- нет ключа - закрываем
            RIBA.BigMessage.SetNext(RIBA.Text("blocked"), Color.Red, 5)
            return false
        end
    end

    if isBlockWhenDeattached then
        local attached = RIBA.Component(instance.Item, "Holdable").Attached
        if not attached then
            print("контейнер не на стене - закрываем")
            ptable.PreventExecution = true --контейнер не на стене - закрываем
            RIBA.BigMessage.SetNext(RIBA.Text("deattachedBlockMessage"), Color.Red, 5)
            return false
        else
            print("контейнер на стене - открываем")
            ptable.PreventExecution = true --контейнер на стене - открываем
            return true
        end
    end
end, Hook.HookMethodType.Before)

if not CLIENT then return end

Hook.Patch("ololo", "Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
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
                    RIBA.BigMessage.SetNext(RIBA.Text("books"), Color.Red, 5)
                else
                    RIBA.BigMessage.SetNext(RIBA.Text("cantattach") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Red, 5)
                end
            else
                instance.LimitedAttachable = false
            end
            if CurrentPseudonymItems + 1 == maxBItems then
                RIBA.BigMessage.SetNext(
                RIBA.Text("cantattachwarning") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Yellow, 5)
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

Hook.Patch("ololo", "Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    RIBA.BigMessage.Print()
end, Hook.HookMethodType.After)
