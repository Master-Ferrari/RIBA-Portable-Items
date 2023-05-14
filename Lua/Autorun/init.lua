if not CLIENT then return end

local BibaTable = {
    ["RIBAbunkcabinet1"] = "BIBAbunkcabinet",
    ["RIBAbunkcabinet2"] = "BIBAbunkcabinet"
}

function GetBibaName(name)
    return BibaTable[name] or nil
end



Hook.Patch("ololo","Barotrauma.Items.Components.Holdable", "Use", function(instance, ptable)
-- предупреждалку для всех предметов риба и не риба

    -- ptable.PreventExecution = true
    -- local maxItems = ptable["character"].info.SavedStatValues
    -- print(ptable["character"].Name)
    -- print(  instance.LimitedAttachable  )

    -- local attachSubmarine =  Structure.GetAttachTarget(GetAttachPosition(character, true)).Submarine
    -- if attachSubmarine == nil then
    --     attachSubmarine = instance.item.Submarine
    -- end


    local nPs = GetBibaName(instance.item.Name)
    if nPs ~= nil then

        instance.LimitedAttachable = false

        -- local maxItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, instance.item.Prefab.Identifier)
        -- print(maxItems)

        local maxBItems = ptable["character"].info.GetSavedStatValue(StatTypes.MaxAttachableCount, nPs)


        -- local CurrentItems = 0
        local CurrentPseudonymItems = 0
        for _, i in ipairs(Item.ItemList) do
            local holdableComponent = i.GetComponent(Components.Holdable)
            if holdableComponent ~= nil and holdableComponent.Attached then

                -- if i.Name==instance.item.Name then
                --     CurrentItems = CurrentItems + 1
                -- end

                local iPs = GetBibaName(i.Name)

                if iPs~=nil and iPs==nPs then
                    CurrentPseudonymItems = CurrentPseudonymItems + 1
                end

            end
        end
        
        print("  -  ")
        -- print("         CurrentItems: " .. CurrentItems)
        print("Current PseudonymItems: " .. CurrentPseudonymItems)
        print("Max     PseudonymItems: " .. maxBItems)
        print(" ")
        print("         Name: " .. instance.item.Name)
        print("PseudonymName: " .. GetBibaName(instance.item.Name) )
        print("  -  ")

        if maxBItems >= CurrentPseudonymItems+1 then
            instance.LimitedAttachable = true
        end
        else
            instance.LimitedAttachable = false
        end


        if maxBItems == CurrentPseudonymItems+2 then
            ptable["character"].AddMessage("Это был предпоследний доступный предмет такого типа!", Color.Red, true, "ribames1", 5)
        end

    end

end, Hook.HookMethodType.Before)
