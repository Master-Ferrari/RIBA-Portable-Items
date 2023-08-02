RIBA.BigMessage = {
    maxQueueSize = 4, -- Максимальный размер очереди
    Categories = {}
    
}

function RIBA.BigMessage.CreateCategory(category, cooldown)
    if not CLIENT then return end
    local nextTime = 0 -- момент когда можно добавлять очередное сообщение
    RIBA.BigMessage.Categories[category]={cooldown,nextTime}
end

function RIBA.BigMessage.SetNext(msg, clr, category, cooldown) -- добавение сообщения
    if cooldown == nil then
        cooldown = 20
    end
    if not CLIENT then return end
    local lifetime = RIBA.clamp(#msg/7,3,10) -- время жизни текста - пропорция от длины
    if (RIBA.BigMessage.Categories[category]==nil) then
        RIBA.BigMessage.CreateCategory(category, cooldown)
    end
    if (RIBA.BigMessage.Categories[category][2]<=os.time()) then -- если уже можно добавлять сообщение этого типа 
        print("добавляем   -----  "..category..RIBA.BigMessage.Categories[category][1])
        GUI.AddMessage(msg, clr, lifetime) -- добавляем
        RIBA.BigMessage.Categories[category][2] = os.time()+RIBA.BigMessage.Categories[category][1] -- обновляем момент когда можно добавлять
    end
end

function RIBA.BigMessage.Print()
    -- if not CLIENT then return end
    -- print("\"if not CLIENT\" singleplayer??")
    -- local currentTime = os.time()

    -- if RIBA.BigMessage.queue[1]~=nil then
    --     local nextMessage = RIBA.BigMessage.queue[1]
    --     if math.floor(nextMessage.time-currentTime) <= 0 then --время прило (и есть куда)
    --         GUI.ClearMessages()
    --         GUI.AddMessage(nextMessage.msg, nextMessage.clr)
    --         RIBA.BigMessage.actualCoolDown = nextMessage.time
    --         table.remove(RIBA.BigMessage.queue, 1)
    --     end
    -- end
end




-- Hook.Patch("Gui", "DrawMessages", function(instance, ptable)
--     print(2)
--     -- print(#messages)
--     -- RIBA.BigMessage.Print()
-- end, Hook.HookMethodType.After)

function RIBA.BigMessage.ClCall(character, msg, clr, category, cooldown)
    
    if cooldown==nil then
        cooldown = 20
    end
    local netMsg = Networking.Start("BigMessage");

    netMsg.WriteString(character.Name)

    netMsg.WriteString(msg)
    --clr
    netMsg.WriteString(category)
    netMsg.WriteInt16(cooldown)
    Networking.Send(netMsg)
end

if CLIENT then
    Networking.Receive("BigMessage", function(netMsg, sender)
        if netMsg.ReadString() == Character.Controlled.Name then
            local msg = netMsg.ReadString()
            local clr =  Color.Red
            local category = netMsg.ReadString()
            local cooldown = netMsg.ReadInt16()

            RIBA.BigMessage.SetNext(msg, clr, category, cooldown)
        end
    end)
end