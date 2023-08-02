RIBA.ScreenMessage = {
    maxQueueSize = 4, -- Максимальный размер очереди
    Categories = {}
    
}

function RIBA.ScreenMessage.CreateCategory(category, cooldown)
    if not CLIENT then return end
    local nextTime = 0 -- момент когда можно добавлять очередное сообщение
    RIBA.ScreenMessage.Categories[category]={cooldown,nextTime}
end

function RIBA.ScreenMessage.Big(msg, clr, category, cooldown) -- добавение сообщения
    if cooldown == nil then
        cooldown = 20
    end
    if not CLIENT then return end
    local lifetime = RIBA.clamp(#msg/7,3,10) -- время жизни текста - пропорция от длины
    if (RIBA.ScreenMessage.Categories[category]==nil) then
        RIBA.ScreenMessage.CreateCategory(category, cooldown)
    end
    if (RIBA.ScreenMessage.Categories[category][2]<=os.time()) then -- если уже можно добавлять сообщение этого типа 
        -- print("добавляем   -----  "..category..RIBA.BigMessage.Categories[category][1])
        GUI.AddMessage(msg, clr, lifetime) -- добавляем
        RIBA.ScreenMessage.Categories[category][2] = os.time()+RIBA.ScreenMessage.Categories[category][1] -- обновляем момент когда можно добавлять
    end
end

function RIBA.ScreenMessage.ClCallBig(character, msg, clr, category, cooldown)
    
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

            RIBA.ScreenMessage.Big(msg, clr, category, cooldown)
        end
    end)
end

function RIBA.ScreenMessage.Small(character, msg, clr, category, cooldown, value, lifetime, personal)

    
    if (RIBA.ScreenMessage.Categories[category]==nil) then
        RIBA.ScreenMessage.CreateCategory(category, cooldown)
    end

    if (RIBA.ScreenMessage.Categories[category][2]<=os.time()) then -- если уже можно добавлять сообщение этого типа 
        if not (personal==true and character~=Character.Controlled) then
            -- print("дывадыад   -----  "..category..RIBA.BigMessage.Categories[category][1])
            character.AddMessage(msg, clr, character==Character.Controlled, value, lifetime)
        end
        RIBA.ScreenMessage.Categories[category][2] = os.time()+RIBA.ScreenMessage.Categories[category][1] -- обновляем момент когда можно добавлять
    end

end

