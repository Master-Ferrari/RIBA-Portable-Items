RIBA = {}
RIBA.Path = table.pack(...)[1]
RIBA.Bibs = json.parse(File.Read(RIBA.Path .. "/lua/data.json"))
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

RIBA.BigMessageNext = {"", Color.Red}
RIBA.BigMessage = function ()
    if RIBA.BigMessageNext[1] ~= "" then
        GUI.ClearMessages()
        GUI.AddMessage(RIBA.BigMessageNext[1], RIBA.BigMessageNext[2])
        RIBA.BigMessageNext = {"", Color.Red}
    end
end

RIBA.Component = function (item, name)
    for _, component in ipairs(item.Components) do
        if component.Name == name then
            return component
        end
    end
end

RIBA.removePrefixAndSuffix = function (input, prefix, suffix)
    local success, result = pcall(function()
      local startIdx = string.find(input, prefix) -- Находим индекс начала префикса
      if startIdx then
        startIdx = startIdx + string.len(prefix) -- Смещаем начало на конец префикса
        local endIdx = string.find(input, suffix, startIdx) -- Находим индекс конца суффикса
        if endIdx then
          return string.sub(input, startIdx, endIdx - 1) -- Извлекаем подстроку между префиксом и суффиксом
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

-- print(RIBA.Language())

if not CLIENT then return end

Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
-- предупреждалку для всех предметов риба и не риба
-- отключать лишние предметы
-- пофиксить поднимание (ложится на кровать)
    -- print("1")
    local itemName = instance.Item.Prefab.Identifier.Value
    -- print(itemName)
    
    local nPs = RIBA.Biba(itemName)
    -- print(nPs)
    
    -- print("2 ".. itemName)

    if nPs ~= nil then

        -- print("3")
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
        
        -- print("Current PseudonymItems:    " .. CurrentPseudonymItems)
        -- print("Max PseudonymItems:    " .. maxBItems)
        -- print("         Name:    " .. itemName)
        -- print("PseudonymName:    " .. RIBA.Biba(itemName) )
        -- print("  -  ")

        local attached = instance.Attached
        if instance.Attached == false then
            if CurrentPseudonymItems >= maxBItems  then
                instance.LimitedAttachable = true
                if maxBItems == 0 then
                    RIBA.BigMessageNext = {RIBA.Text("books"), Color.Red}
                else
                    RIBA.BigMessageNext = {RIBA.Text("cantattach").." ("..maxBItems.."/"..maxBItems..")", Color.Red}
                end
            else
                instance.LimitedAttachable = false
            end

            if CurrentPseudonymItems+1 == maxBItems then
                RIBA.BigMessageNext = {RIBA.Text("cantattachwarning") .." ("..maxBItems.."/"..maxBItems..")", Color.Yellow}
            end

            if CurrentPseudonymItems+1 == maxBItems then
                ptable["character"].AddMessage("("..(CurrentPseudonymItems+1).."/"..maxBItems..")", Color.Yellow, true, "ribamessage1", 3)
            end

            if CurrentPseudonymItems+1 < maxBItems then
                ptable["character"].AddMessage("("..(CurrentPseudonymItems+1).."/"..maxBItems..")", Color.Green, true, "ribamessage1", 3)
            end
        end
    end
end, Hook.HookMethodType.Before)

Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
    
    -- instance.Item.Components.canbeselected = true
    -- print("Use. canbeselected = "..instance.Item.Components.Controller.canbeselected)
    -- print("4")

    
    RIBA.BigMessage()
end, Hook.HookMethodType.After)






Hook.Patch("ololo","Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
    -- print(ptable["msg"])
    -- if tostring(ptable["msg"])=="biba_riba" then

    -- local compName = tostring(instance.originalElement.GetAttribute("RIBA_Costyl"))
    -- local compName = tostring(instance.originalElement.Name)
    -- print(compName)
    -- print(compName)

    
    local success, result = pcall(function()
        local RIPCostyl = tostring(instance.originalElement.GetChildElement("RequiredItem").GetAttribute("RIBA_Costyl"))
        return RIBA.removePrefixAndSuffix(RIPCostyl, 'RIBA_Costyl="', '"')=="true"
    end)
    local RIPCostyl = success and result or false

    -- local RequiredItemElements = instance.Item.Prefab.ConfigElement.GetChildElements("RequiredItem")
    
    -- local RIPCostyl = tostring(instance.Item.Prefab.ConfigElement.GetAttribute("RIBA_Costyl"))
    -- print("1: "..RIPCostyl)
    -- print("2: "..RIPCostyl)

    if RIPCostyl then --RIP means RequiredItems Parent
        
        print(RIPCostyl)

        -- local itemName = instance.Item.Prefab.Identifier.Value
        -- print(itemName)
        

        -- if instance.Name == RIPCostyl then
        local attached = RIBA.Component(instance.Item, "Holdable").Attached

        if attached then
            -- RIBA.Component(instance.Item, "Deconstructor").IsActive = true;
            ptable.PreventExecution = true
            return true
        else
            RIBA.BigMessageNext = {RIBA.Text("cantusewhendeattached"), Color.Red}
            -- RIBA.Component(instance.Item, "Deconstructor").IsActive =false;
            -- RIBA.BigMessageNext = {"Без крепления к стене использовать невозможно!", Color.PaleVioletRed}
        end
        -- instance.Item.Components.canbeselected = false
        -- RIBA.BigMessage()
        -- print("DeattachFromWall. canbeselected = "..instance.Item.Components.Controller.canbeselected)
    end
    -- print("4")
end, Hook.HookMethodType.Before)


Hook.Patch("ololo","Barotrauma.Items.Components.ItemComponent", "HasRequiredItems", function(instance, ptable)
    -- RIBA.BigMessage()
end, Hook.HookMethodType.After)

