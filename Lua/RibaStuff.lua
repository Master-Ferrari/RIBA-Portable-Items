
RIBA.Bibs = json.parse(File.Read(RIBA.Path .. "/Lua/data.json"))

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
    similarNameCooldownDuration = 15,
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
        local isCostylElementString = tostring(instance.originalElement.GetChildElement(tostring(targetElement)).GetAttribute(tostring(targetAttribute)))
        return RIBA.removePrefixAndSuffix(isCostylElementString, '"', '"')
    end)
    local isCostylElement = success and result or nil
    return isCostylElement
end

RIBA.GetAttributeValueFromItem = function(item, targetElement, targetAttribute)
    local success, result = pcall(function()
        local AttributeString = tostring(RIBA.Component(item,targetElement).originalElement.GetAttribute(tostring(targetAttribute)))
        return RIBA.removePrefixAndSuffix(AttributeString, '"', '"')
    end)
    return success and result or nil
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