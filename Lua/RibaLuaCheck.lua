---@diagnostic disable: undefined-global, undefined-field
--[[
    Есть ли Lua на обоих концах.

    Вся логика мода - лимиты, книги, блокировка откреплённых шкафов - живёт
    в Lua. Если её нет на одной из сторон, половина мода молча не работает,
    и человек об этом никак не узнаёт. Значит надо сказать вслух.

    Пинг-понг: клиент шлёт пинг, сервер отвечает понгом.
      не пришёл понг  ->  Lua нет на сервере, показываем окно сами;
      не пришёл пинг  ->  Lua нет у клиента, просим ваниль показать окно ему -
                          ChatMessageType.MessageBox доходит и без Lua.

    Оба конца показывают одно и то же ванильное GUIMessageBox: в сообщении
    четыре строки и ссылка, всплывашка GUI.AddMessage такое не вытянет -
    она живёт максимум 10 секунд и не переносит строки.

    Полностью ванильную связку (Lua нет нигде) не поймать: там выполнять
    эту проверку просто некому.

    Тот же приём в воркшоп-моде LuaCsClientSideEnforced (3088784724), только
    там клиента без Lua кикают, а не предупреждают.
]]

local PING  = "RIBALuaPing"
local PONG  = "RIBALuaPong"
local GRACE = 30000 -- мс на ответ: клиенту хватит докачать моды и войти в раунд

if CLIENT then
    local answered = false
    local told     = false -- одного раза на подключение хватит

    Networking.Receive(PONG, function() answered = true end)

    Hook.Add("roundStart", "RIBA.LuaCheck", function()
        if Game.IsSingleplayer or told then return end
        answered = false
        Networking.Send(Networking.Start(PING))

        Timer.Wait(function()
            if answered or told then return end
            told = true
            -- GUI.MessageBox - это конструктор Barotrauma.GUIMessageBox, у него
            -- есть кнопка ОК. Если апи вдруг переедет, лучше кривое сообщение,
            -- чем никакого.
            local ok = pcall(function() GUI.MessageBox("", RibaPI.Text("noserverlua")) end)
            if not ok then GUI.AddMessage(RibaPI.Text("noserverlua"), Color.Yellow, 15) end
        end, GRACE)
    end)
end

if SERVER then
    local hasLua = {} -- SessionId -> клиент отозвался
    local told   = {} -- SessionId -> уже предупреждён

    Networking.Receive(PING, function(_, client)
        hasLua[client.SessionId] = true
        Networking.Send(Networking.Start(PONG), client.Connection)
    end)

    Hook.Add("client.disconnected", "RIBA.LuaCheck", function(client)
        -- SessionId выдаются заново, чужие отметки новому клиенту ни к чему
        hasLua[client.SessionId] = nil
        told[client.SessionId] = nil
    end)

    -- Молчунов ищем по живому списку: так не останется ссылок на отвалившихся.
    -- Ещё не вошедших в раунд пропускаем - они могут качать моды, а не сидеть
    -- без Lua; их поймает следующий обход.
    local function sweep()
        for _, client in pairs(Client.ClientList) do
            local id = client.SessionId
            if client.InGame and not hasLua[id] and not told[id] then
                told[id] = true
                -- MessageBox, а не Error: сообщения типа Error клиент прогоняет
                -- через ServerMsgLString, а тот режет строку по "/" и собирает
                -- обратно без них - ссылка бы развалилась.
                Game.SendDirectChatMessage("", RibaPI.Text("noclientlua", tostring(client.Language.Value)),
                    nil, ChatMessageType.MessageBox, client)
            end
        end
    end

    Hook.Add("roundStart", "RIBA.LuaCheck", function() Timer.Wait(sweep, GRACE) end)
    Hook.Add("client.connected", "RIBA.LuaCheck", function() Timer.Wait(sweep, GRACE) end)
end
