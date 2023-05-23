---@diagnostic disable: undefined-field, redundant-parameter, return-type-mismatch

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

local timers = {}                   
RIBA.isTimerExpired = function(name)
    print(math.floor(os.time()))
    return (not timers[name]) or (math.floor(os.time()) >= timers[name]) --(если таймер не установлен) или (сейчас больше чем время срок)
end
RIBA.setTimer = function(name, duration)
    timers[name] = math.floor(os.time()) + duration -- сохраняем время окончания таймера
end

RIBA.BigMessage = {
    maxQueueSize = 4, -- Максимальный размер очереди
    coolDownDuration = 1,
    similarNameCooldownDuration = 5,
    queue = {},              -- Очередь кулдаунов
    similarNameCooldowns = {},  -- Таблица разноимённых последних пройденных таймеров и времени их инициализации +30
    actualCoolDown = 0
}

function RIBA.BigMessage.SetNext(msg, clr, name)
    if not CLIENT then return end
    local currentTime = os.time()
    local nextTime = currentTime + RIBA.BigMessage.coolDownDuration
        -- Уходим, если доебались уже в край (в maxQueueSize)
    local queueSize = #RIBA.BigMessage.queue
    if queueSize >= RIBA.BigMessage.maxQueueSize then --есть ли места в очереди
        return
    end
        -- Если от прошлого одноимённого таймера прошло менее 30 секунд, то мы уходим 
    if RIBA.BigMessage.similarNameCooldowns[name]~=nil then
        if RIBA.BigMessage.similarNameCooldowns[name] > currentTime then
            return
        end
    end

    if queueSize > 0 then
        local lastTime = RIBA.BigMessage.queue[queueSize].time
        nextTime = lastTime + RIBA.BigMessage.coolDownDuration
    end

    table.insert(RIBA.BigMessage.queue, { msg = msg, clr = clr, name = name, time = nextTime })
    RIBA.BigMessage.similarNameCooldowns[name] = currentTime + RIBA.BigMessage.similarNameCooldownDuration

end

function RIBA.BigMessage.Print()
    if not CLIENT then return end
    local currentTime = os.time()
    if RIBA.BigMessage.queue[1]~=nil then
        local nextMessage = RIBA.BigMessage.queue[1]
        if math.floor(nextMessage.time-currentTime) <= 0 then --время прило (и есть куда)
            GUI.ClearMessages()
            GUI.AddMessage(nextMessage.msg, nextMessage.clr)
            RIBA.BigMessage.actualCoolDown = nextMessage.time
            table.remove(RIBA.BigMessage.queue, 1)
        end
    end
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
                                    if idcard.GetComponent(Components.IdCard)~= nil then
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
            -- print("нет ключа - закрываем")
            ptable.PreventExecution = true -- нет ключа - закрываем
            RIBA.BigMessage.SetNext(RIBA.Text("blocked"), Color.Red, "blocked")
            return false
        end
    end

    if isBlockWhenDeattached then
        local attached = RIBA.Component(instance.Item, "Holdable").Attached
        if not attached then
            -- print("контейнер не на стене - закрываем")
            ptable.PreventExecution = true --контейнер не на стене - закрываем
            RIBA.BigMessage.SetNext(RIBA.Text("deattachedBlockMessage"), Color.Red, "deattachedBlockMessage")
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
                    RIBA.BigMessage.SetNext(RIBA.Text("books"), Color.Red, "books")
                else
                    RIBA.BigMessage.SetNext(RIBA.Text("cantattach") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Red, "cantattach")
                end
            else
                instance.LimitedAttachable = false
            end
            if CurrentPseudonymItems + 1 == maxBItems then
                RIBA.BigMessage.SetNext(RIBA.Text("cantattachwarning") .. " (" .. maxBItems .. "/" .. maxBItems .. ")", Color.Yellow, "cantattachwarning")
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














FocusedItem = nil

-- our main frame where we will put our custom GUI
local frame = GUI.Frame(GUI.RectTransform(Vector2(1, 1)), nil)  --ваще весь экран
frame.CanBeFocused = false

RIBA.decoratorUI = function(sprite, depthInt)
    -- menu frame
    local menu = GUI.Frame(GUI.RectTransform(Vector2(1, 1), frame.RectTransform, GUI.Anchor.Center), nil)  --наш слой на экране
    menu.CanBeFocused = false
    menu.Visible = false

    -- put a button that goes behind the menu content, so we can close it when we click outside
    local closeButton = GUI.Button(GUI.RectTransform(Vector2(1, 1), menu.RectTransform, GUI.Anchor.Center), "", GUI.Alignment.Center, nil)  --кнопка закрыть всё
    closeButton.OnClicked = function ()
        menu.Visible = not menu.Visible
    end


    local menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.15, 0.1), menu.RectTransform, GUI.Anchor.BottomCenter)) -- основное окно
    menuContent.RectTransform.AbsoluteOffset = Point(0, 110)
    menuContent.Color = Color(112,150,124,255)
    menuContent.HoverColor = Color(0,0,0,0)

    local menuH = GUI.ListBox(GUI.RectTransform(Vector2(1, 1), menuContent.RectTransform, GUI.Anchor.BottomCenter), true) -- содержимое горизонталь

    local imageFrame = GUI.Frame(GUI.RectTransform(Point(93, 93), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), "GUITextBox", Color(0,0,0,0))  ---иконка
    local image = GUI.Image(GUI.RectTransform(Point(93, 93), imageFrame.RectTransform, GUI.Anchor.Center), sprite)
    imageFrame.CanBeFocused = false

    local menuV = GUI.ListBox(GUI.RectTransform(Vector2(0.665, 1), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), false) -- содержимое вертикаль
    menuV.Color = Color(0,0,0,0)
    menuV.HoverColor = Color(0,0,0,0)

    local numberInput = GUI.NumberInput(GUI.RectTransform(Vector2(1, 0.5), menuV.Content.RectTransform), NumberType.Int) -- крутилка
    numberInput.MinValueInt = 001
    numberInput.MaxValueInt = 900
    numberInput.valueStep = 10
    if depthInt ~= nil then
        numberInput.IntValue = depthInt
    end
    numberInput.OnValueChanged = function ()
        FocusedItem.SpriteDepth = math.round(numberInput.IntValue/1000.0, 3)
    end

    local someButton = GUI.Button(GUI.RectTransform(Vector2(1, 0.5), menuV.Content.RectTransform), "где детонатор???", GUI.Alignment.Center, "GUIButtonSmall")
    someButton.OnClicked = function ()
        RIBA.BigMessage.SetNext("Я НЕ ЗНАЮЮЮ!", Color.OrangeRed, "RibaDecorator")
        RIBA.BigMessage.Print()
    end

    menu.Visible = true
end

-- image.ToolTip = "Bandages are pretty cool"


Hook.Add("RibaDecorator", "RibaDecorator", function(statusEffect, delta, item)

    FocusedItem = Character.Controlled.FocusedItem
    
    -- local sprite = ItemPrefab.GetItemPrefab(FocusedItem.Name).InventoryIcon
    local sprite = FocusedItem.Prefab.InventoryIcon
    if sprite == nil then
        sprite = FocusedItem.Prefab.Sprite
    end 
    if sprite==nil then
        sprite = ItemPrefab.GetItemPrefab("poop").Sprite
    end

    local depthInt = math.floor(FocusedItem.SpriteDepth*1000.0)

    RIBA.decoratorUI(sprite, depthInt)
    

end)


Hook.Patch("Barotrauma.GameScreen", "AddToGUIUpdateList", function()
    frame.AddToGUIUpdateList()
end)