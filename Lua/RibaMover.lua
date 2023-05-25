if SERVER then

    Hook.Add("loaded", "RIBAMove", function()
        Networking.Receive("MoveMSG", function(msg, sender)
            local Item = Entity.FindEntityByID(tonumber(msg.ReadString()))
            local H = msg.ReadInt16()
            local V = msg.ReadInt16()

            Item.Move(Vector2(H, V), false)

        end)
    end)

    
    Hook.Add("loaded", "RIBAMove", function()
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

    return
end

-- GetPositionUpdateInterval


RIBA.Flip = function(X, Item)
    if (not Game.IsSingleplayer) then
        local netMsg = Networking.Start("FlipMSG");
        netMsg.WriteString(tostring(Item.ID))
        netMsg.WriteBoolean(X)
        Networking.Send(netMsg)
    end
    if X then
        Item.FlipX(false)
    else
        Item.FlipY(false)
    end
end

RIBA.Move = function(H, V, Item)
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


    local menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.15, 0.1), menu.RectTransform, GUI.Anchor.Center))

    -- local menuContent = GUI.Frame(GUI.RectTransform(Vector2(0.15, 0.1), menu.RectTransform, GUI.Anchor.BottomCenter), "", Color(255,255,255,255)) -- основное окно
    menuContent.RectTransform.AbsoluteOffset = Point(0, 110)
    -- menuContent.Color = Color(112,150,124,255)
    -- menuContent.Color = Color(0,0,0,0)
    -- menuContent.HoverColor = Color(0,0,0,0)

    local menuH = GUI.ListBox(GUI.RectTransform(Vector2(1, 1), menuContent.RectTransform, GUI.Anchor.BottomCenter), true) -- содержимое горизонталь

    local imageFrame = GUI.Frame(GUI.RectTransform(Point(93, 93), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), "GUITextBox", Color(0,0,0,0))  ---иконка
    local image = GUI.Image(GUI.RectTransform(Point(93, 93), imageFrame.RectTransform, GUI.Anchor.Center), sprite)
    imageFrame.CanBeFocused = false

    local menuHV = GUI.ListBox(GUI.RectTransform(Vector2(0.665, 1), menuH.Content.RectTransform, GUI.Anchor.CenterLeft), false) -- содержимое вертикаль
    menuHV.Color = Color(0,0,0,0)
    menuHV.HoverColor = Color(0,0,0,0)


    local numberInput = GUI.NumberInput(GUI.RectTransform(Vector2(1, 0.45), menuHV.Content.RectTransform), NumberType.Int) -- крутилка
    numberInput.MinValueInt = 001
    numberInput.MaxValueInt = 900
    numberInput.valueStep = 10
    if depthInt ~= nil then
        numberInput.IntValue = depthInt
    end
    numberInput.OnValueChanged = function ()
        FocusedItem.SpriteDepth = math.round(numberInput.IntValue/1000.0, 3)
    end
    
    local menuHVH = GUI.ListBox(GUI.RectTransform(Vector2(0.95, 0.45), menuHV.Content.RectTransform, GUI.Anchor.TopCenter), true, Color(0,0,0,0)) -- содержимое вертикаль
    menuHVH.Color = Color(0,0,0,0)
    menuHVH.HoverColor = Color(0,0,0,0)
    menuHVH.CanBeFocused = false

    local FlipXButton = GUI.Button(GUI.RectTransform(Vector2(0.2, 1.2), menuHVH.Content.RectTransform), "FlipX", GUI.Alignment.Center, "GUIButtonSmall")
    FlipXButton.OnClicked = function ()
        RIBA.Flip(true,FocusedItem)
    end
    local FlipYButton = GUI.Button(GUI.RectTransform(Vector2(0.2, 1.2), menuHVH.Content.RectTransform), "FlipY", GUI.Alignment.Center, "GUIButtonSmall")
    FlipYButton.OnClicked = function ()
        RIBA.Flip(false,FocusedItem)
    end
    local leftButton = GUI.Button(GUI.RectTransform(Vector2(0.16, 1.2), menuHVH.Content.RectTransform), "L", GUI.Alignment.Center, "GUIButtonSmall")
    leftButton.OnClicked = function ()
        RIBA.Move(-10,0,FocusedItem)
    end
    local rightButton = GUI.Button(GUI.RectTransform(Vector2(0.16, 1.2), menuHVH.Content.RectTransform), "R", GUI.Alignment.Center, "GUIButtonSmall")
    rightButton.OnClicked = function ()
        RIBA.Move(10,0,FocusedItem)
    end
    local upButton = GUI.Button(GUI.RectTransform(Vector2(0.16, 1.2), menuHVH.Content.RectTransform), "U", GUI.Alignment.Center, "GUIButtonSmall")
    upButton.OnClicked = function ()
        RIBA.Move(0,10,FocusedItem)
    end
    local downButton = GUI.Button(GUI.RectTransform(Vector2(0.16, 1.2), menuHVH.Content.RectTransform), "D", GUI.Alignment.Center, "GUIButtonSmall")
    downButton.OnClicked = function ()
        RIBA.Move(0,-10,FocusedItem)
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
