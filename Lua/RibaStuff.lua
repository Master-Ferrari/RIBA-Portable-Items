
RibaPI.Bibs = json.parse(File.Read(RibaPI.Path .. "/Lua/data.json"))

RibaPI.Language = function()
    local lang = tostring(GameSettings.CurrentConfig.Language.Value)
    if RibaPI.Bibs["Text"][lang] ~= nil then
        return lang
    end
    return "English"
end

RibaPI.Text = function(text)
    return RibaPI.Bibs["Text"][RibaPI.Language()][text]
end

RibaPI.Biba = function(item)
    return RibaPI.Bibs["Bibs"][item]
end

RibaPI.Component = function(item, name)
    for _, component in ipairs(item.Components) do
        if component.Name == name then
            return component
        end
    end
end

RibaPI.removePrefixAndSuffix = function(input, prefix, suffix)
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

RibaPI.GetAttributeValueFromInstance = function(instance, targetElement, targetAttribute)
    local success, result = pcall(function()
        local isCostylElementString = tostring(instance.originalElement.GetChildElement(tostring(targetElement)).GetAttribute(tostring(targetAttribute)))
        return RibaPI.removePrefixAndSuffix(isCostylElementString, '"', '"')
    end)
    local isCostylElement = success and result or nil
    return isCostylElement
end

RibaPI.GetAttributeValueFromItem = function(item, targetElement, targetAttribute)
    local success, result = pcall(function()
        local AttributeString = tostring(RibaPI.Component(item,targetElement).originalElement.GetAttribute(tostring(targetAttribute)))
        return RibaPI.removePrefixAndSuffix(AttributeString, '"', '"')
    end)
    return success and result or nil
end

RibaPI.splitStringByComma = function(inputString)
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

RibaPI.hasMatchingString = function(strings, condition)
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

RibaPI.idcardSearch = function(strings, character) -- output RibaRequiredItemsTable
    local success, result = pcall(function()
        local idcardTags = {                     -- tags for searching in id cards
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
            if splitIndex then --if :
                name = string.sub(str, 1, splitIndex - 1)
                param = string.sub(str, splitIndex + 1)
                if name == "idcard" then                      --if idcard
                    for _, pair in ipairs(idcardTags) do
                        local key = pair[1]                   --profession
                        if param == key then                  --required profession is registered
                            local values = pair[2]            --synonyms
                            for _, value in ipairs(values) do --search for synonyms in a character
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

RibaPI.clamp = function (value, min, max)
    return math.max(min, math.min(value, max))
end