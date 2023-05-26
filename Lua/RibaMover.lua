if SERVER then

    Hook.Add("loaded", "RIBAMove", function()
        Networking.Receive("MoveMSG", function(msg, sender)
            local Item = Entity.FindEntityByID(tonumber(msg.ReadString()))
            local H = msg.ReadInt16()
            local V = msg.ReadInt16()
            Item.Move(Vector2(H, V), false)
        end)
    end)

    Hook.Add("loaded", "RIBAFlip", function()
        Networking.Receive("FlipMSG", function(msg, sender)
            local Item = Entity.FindEntityByID(tonumber(msg.ReadString()))
            local X = msg.ReadBoolean()
            if X then
                Item.FlipX(false)
            else
                Item.FlipY(false)
            end
        end)
    end)

    Hook.Add("loaded", "RIBADepth", function()
        Networking.Receive("DepthMSG", function(msg, sender)
            local Item = Entity.FindEntityByID(tonumber(msg.ReadString()))
            local newSpriteDepth = msg.ReadInt16()
            Item.SpriteDepth = newSpriteDepth
        end)
    end)

    return
end

-- GetPositionUpdateInterval


RIBA.DepthAttached = function(value, Item)
    if true then
        local newSpriteDepth = math.round(value/1000.0, 3)
        if (not Game.IsSingleplayer) then
            local netMsg = Networking.Start("DepthMSG");
            netMsg.WriteString(tostring(Item.ID))
            netMsg.WriteInt16(newSpriteDepth)
            Networking.Send(netMsg)
        end
        FocusedItem.SpriteDepth = newSpriteDepth
    end
end

RIBA.moveAttached = function(H, V, Item)
    -- local attachable = RIBA.GetAttributeValueFromItem(Item, "Holdable", "attachable")=="true"
    -- if attachable then
    --     local attached = RIBA.Component(Item, "Holdable").Attached
    --     if attached then
            if (Game.IsSingleplayer) then
                Item.Move(Vector2(H, V), false)
            else
                local netMsg = Networking.Start("MoveMSG");
                netMsg.WriteString(tostring(Item.ID))
                netMsg.WriteInt16(H)
                netMsg.WriteInt16(V)
                Networking.Send(netMsg)
                Item.Move(Vector2(H, V), false)
            end
    --     end
    -- end
end

RIBA.flipAttached = function(X, Item)
    -- local attachable = RIBA.GetAttributeValueFromItem(Item, "Holdable", "attachable")=="true"
    -- if attachable then
    --     local attached = RIBA.Component(Item, "Holdable").Attached
    --     if attached then
            if (Game.IsSingleplayer) then
                if X then
                    Item.FlipX(false)
                else
                    Item.FlipY(false)
                end
            else
                local netMsg = Networking.Start("FlipMSG");
                netMsg.WriteString(tostring(Item.ID))
                netMsg.WriteBoolean(X)
                Networking.Send(netMsg)
                if X then
                    Item.FlipX(false)
                else
                    Item.FlipY(false)
                end
            end
    --     end
    -- end
end

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
        -- Item.PositionUpdateInterval = float.PositiveInfinity
    end


    local menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.18, 0.115), menu.RectTransform, GUI.Anchor.BottomCenter))

    -- local menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.15, 0.1), menu.RectTransform, GUI.Anchor.BottomCenter), "", Color(255,255,255,255)) -- основное окно
    -- menuContent.RectTransform.AbsoluteOffset = Point(0, 110)
    menuContent.RectTransform.RelativeOffset = Vector2(0, 0.1)
    -- menuContent.Color = Color(112,150,124,255)
    -- menuContent.Color = Color(0,0,0,0)
    -- menuContent.HoverColor = Color(0,0,0,0)

    local menuH = GUI.ListBox(GUI.RectTransform(Vector2(1, 1), menuContent.RectTransform, GUI.Anchor.BottomCenter), true, Color(0,0,0,0), nil) -- содержимое горизонталь

    local imageFrame = GUI.Frame(GUI.RectTransform(Point(100, 100), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), "GUITextBox", Color(0,0,0,0), "InnerFrame")  ---иконка
    imageFrame.RectTransform.RelativeOffset = Vector2(0.062, 0)
    local image = GUI.Image(GUI.RectTransform(Point(100, 100), imageFrame.RectTransform, GUI.Anchor.Center), sprite)
    imageFrame.CanBeFocused = false
    
    --правая часть
    local menuHV = GUI.ListBox(GUI.RectTransform(Vector2(0.6, 0.9), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), false, Color(0,0,0,150), "InnerFrame") -- содержимое вертикаль
    menuHV.Color = Color(0,0,0,0)
    menuHV.HoverColor = Color(0,0,0,0)
    menuHV.RectTransform.RelativeOffset = Vector2(0.058, 0)
    
    --Крутилки
    local menuHVH0 = GUI.ListBox(GUI.RectTransform(Vector2(1, 0.33), menuHV.Content.RectTransform, GUI.Anchor.TopCenter), true, Color(0,0,0,0), nil) -- содержимое вертикаль
    menuHVH0.RectTransform.RelativeOffset = Vector2(0.018, 0.06)
    -- menuHVH0.Color = Color(0,0,0,0)
    -- menuHVH0.HoverColor = Color(0,0,0,0)
    -- menuHVH0.OutlineColor = Color(0,0,0,0)
    menuHVH0.Padding = Vector4(0, 0, 0, 0)
    menuHVH0.Spacing = 3
    menuHVH0.PadBottom = false
    menuHVH0.CanBeFocused = false

    local depthInput = GUI.NumberInput(GUI.RectTransform(Vector2(0.46, 0.5), menuHVH0.Content.RectTransform), NumberType.Int) -- крутилка
    depthInput.MinValueInt = 001
    depthInput.MaxValueInt = 900
    depthInput.valueStep = 10
    if depthInt ~= nil then
        depthInput.IntValue = depthInt
    end
    depthInput.OnValueChanged = function ()
        RIBA.DepthAttached(depthInput.IntValue, FocusedItem)
    end

    local gradInput = GUI.NumberInput(GUI.RectTransform(Vector2(0.46, 0.4), menuHVH0.Content.RectTransform), NumberType.Int) -- крутилка
    gradInput.MinValueInt = 001
    gradInput.MaxValueInt = 900
    gradInput.valueStep = 10
    if depthInt ~= nil then
        gradInput.IntValue = depthInt
    end
    gradInput.OnValueChanged = function ()
        FocusedItem.SpriteDepth = math.round(gradInput.IntValue/1000.0, 3)
    end

    --Отражалки
    local menuHVH1 = GUI.ListBox(GUI.RectTransform(Vector2(0.95, 0.2), menuHV.Content.RectTransform, GUI.Anchor.TopCenter), true, Color(0,0,0,0), nil) -- содержимое вертикаль
    menuHVH1.Color = Color(0,0,0,0)
    menuHVH1.HoverColor = Color(0,0,0,0)
    menuHVH1.Padding = Vector4(0, 0, 0, 0)
    menuHVH1.CanBeFocused = false

    local FlipXButton = GUI.Button(GUI.RectTransform(Vector2(0.5, 1), menuHVH1.Content.RectTransform), "FlipX", GUI.Alignment.Center, "GUIButtonSmall")
    FlipXButton.OnClicked = function ()
        RIBA.flipAttached(true, FocusedItem)
    end
    local FlipXButton = GUI.Button(GUI.RectTransform(Vector2(0.5, 1), menuHVH1.Content.RectTransform), "FlipY", GUI.Alignment.Center, "GUIButtonSmall")
    FlipXButton.OnClicked = function ()
        RIBA.flipAttached(false, FocusedItem)
    end

    --Большие кнопочки
    local menuHVH2 = GUI.ListBox(GUI.RectTransform(Vector2(0.95, 0.2), menuHV.Content.RectTransform, GUI.Anchor.TopCenter), true, Color(0,0,0,0), nil) -- содержимое вертикаль
    menuHVH2.Color = Color(0,0,0,0)
    menuHVH2.HoverColor = Color(0,0,0,0)
    menuHVH2.Padding = Vector4(0, 0, 0, 0)
    menuHVH2.CanBeFocused = false

    local leftButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "L", GUI.Alignment.Center, "GUIButtonSmall")
    leftButton.OnClicked = function ()
        RIBA.moveAttached(-10,0,FocusedItem)
    end
    local rightButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "R", GUI.Alignment.Center, "GUIButtonSmall")
    rightButton.OnClicked = function ()
        RIBA.moveAttached(10,0,FocusedItem)
    end
    local upButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "U", GUI.Alignment.Center, "GUIButtonSmall")
    upButton.OnClicked = function ()
        RIBA.moveAttached(0,10,FocusedItem)
    end
    local downButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "D", GUI.Alignment.Center, "GUIButtonSmall")
    downButton.OnClicked = function ()
        RIBA.moveAttached(0,-10,FocusedItem)
    end
    
    --Маленькие кнопочки
    local menuHVH2 = GUI.ListBox(GUI.RectTransform(Vector2(0.95, 0.2), menuHV.Content.RectTransform, GUI.Anchor.TopCenter), true, Color(0,0,0,0), nil) -- содержимое вертикаль
    menuHVH2.Color = Color(0,0,0,0)
    menuHVH2.HoverColor = Color(0,0,0,0)
    menuHVH2.Padding = Vector4(0, 0, 0, 0)
    menuHVH2.CanBeFocused = false

    local leftButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "l", GUI.Alignment.Center, "GUIButtonSmall")
    leftButton.OnClicked = function ()
        RIBA.moveAttached(-1,0,FocusedItem)
    end
    local rightButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "r", GUI.Alignment.Center, "GUIButtonSmall")
    rightButton.OnClicked = function ()
        RIBA.moveAttached(1,0,FocusedItem)
    end
    local upButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "u", GUI.Alignment.Center, "GUIButtonSmall")
    upButton.OnClicked = function ()
        RIBA.moveAttached(0,1,FocusedItem)
    end
    local downButton = GUI.Button(GUI.RectTransform(Vector2(0.25, 1), menuHVH2.Content.RectTransform), "d", GUI.Alignment.Center, "GUIButtonSmall")
    downButton.OnClicked = function ()
        RIBA.moveAttached(0,-1,FocusedItem)
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
