local esp_table = {}
local workspace = cloneref(game:GetService("Workspace"))
local rservice = cloneref(game:GetService("RunService"))
local plrs = cloneref(game:GetService("Players"))
local lplr = plrs.LocalPlayer
local container = Instance.new("Folder", game:GetService("CoreGui").RobloxGui)

-- Utility optimization
if not utility then
    utility = {
        connections = {
            heartbeats = {},
            renderstepped = {}
        }
    }
    
    local function createConnectionHandler(connectionType)
        return function(func)
            local obj = {}
            utility.connections[connectionType][func] = func
            function obj:Disconnect()
                utility.connections[connectionType][func] = nil
            end
            return obj
        end
    end
    
    utility.new_heartbeat = createConnectionHandler("heartbeats")
    utility.new_renderstepped = createConnectionHandler("renderstepped")
    
    local heartbeatConnection = rservice.Heartbeat:Connect(function(delta)
        for _, func in pairs(utility.connections.heartbeats) do
            func(delta)
        end
    end)
    
    local renderConnection = rservice.RenderStepped:Connect(function(delta)
        for _, func in pairs(utility.connections.renderstepped) do
            func(delta)
        end
    end)
    
    utility.unload = function()
        heartbeatConnection:Disconnect()
        renderConnection:Disconnect()
        utility.connections.heartbeats = {}
        utility.connections.renderstepped = {}
    end
end

-- Constants
local VERTICES = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(-1, -1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1),
    Vector3.new(1, -1, 1)
}

local SKELETON_ORDER = {
    LeftFoot = "LeftLowerLeg",
    LeftLowerLeg = "LeftUpperLeg",
    LeftUpperLeg = "LowerTorso",
    RightFoot = "RightLowerLeg",
    RightLowerLeg = "RightUpperLeg",
    RightUpperLeg = "LowerTorso",
    LeftHand = "LeftLowerArm",
    LeftLowerArm = "LeftUpperArm",
    LeftUpperArm = "UpperTorso",
    RightHand = "RightLowerArm",
    RightLowerArm = "RightUpperArm",
    RightUpperArm = "UpperTorso",
    LowerTorso = "UpperTorso",
    UpperTorso = "Head"
}

local BODY_PARTS = {
    Head = true,
    UpperTorso = true,
    LowerTorso = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true
}

-- ESP configuration
esp_table = {
    __loaded = false,
    main_settings = {
        textSize = 12,
        textFont = Drawing.Fonts.Monospace,
        distancelimit = false,
        maxdistance = 2000,
        useteamcolor = false,
        teamcheck = false,
        fadetime = 1
    },
    settings = {
        enemy = {
            enabled = false,
            box = false, box_fill = false, realname = false, displayname = false,
            health = false, dist = false, weapon = false, skeleton = false,
            box_outline = false, realname_outline = false, displayname_outline = false,
            health_outline = false, dist_outline = false, weapon_outline = false,
            box_color = { Color3.new(1, 1, 1), 1 },
            box_fill_color = { Color3.new(1, 0, 0), 0.5 },
            realname_color = { Color3.new(1, 1, 1), 1 },
            displayname_color = { Color3.new(1, 1, 1), 1 },
            health_color = { Color3.new(1, 1, 1), 1 },
            dist_color = { Color3.new(1, 1, 1), 1 },
            weapon_color = { Color3.new(1, 1, 1), 1 },
            skeleton_color = { Color3.new(1, 1, 1), 1 },
            box_outline_color = { Color3.new(), 1 },
            realname_outline_color = Color3.new(),
            displayname_outline_color = Color3.new(),
            health_outline_color = Color3.new(),
            dist_outline_color = Color3.new(),
            weapon_outline_color = Color3.new(),
            chams = false,
            chams_visible_only = false,
            chams_fill_color = { Color3.new(1, 1, 1), 0.5 },
            chamsoutline_color = { Color3.new(1, 1, 1), 0 }
        }
    }
}

local loaded_plrs = {}
local camera = workspace.CurrentCamera

-- Optimized helper functions
local function isBodyPart(name)
    return BODY_PARTS[name] == true
end

     local function getBoundingBox(parts)
        local min, max
        for i = 1, #parts do
            local part = parts[i]
            local cframe, size = part.CFrame, part.Size

            min = Vector3.zero.Min(min or cframe.Position, (cframe - size * 0.5).Position)
            max = Vector3.zero.Max(max or cframe.Position, (cframe + size * 0.5).Position)
        end

        local center = (min + max) * 0.5
        local front = Vector3.new(center.X, center.Y, max.Z)
        return CFrame.new(center, front), max - min
    end

local function worldToScreen(world)
    local screen, inBounds = camera:WorldToViewportPoint(world)
    return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

local function calculateCorners(cframe, size)
    local corners = {}
    local halfSize = size * 0.5
    
    for i = 1, 8 do
        local worldPos = (cframe + halfSize * VERTICES[i]).Position
        local screenPos, inBounds = worldToScreen(worldPos)
        corners[i] = screenPos
    end

    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    
    for i = 1, 8 do
        local corner = corners[i]
        minX = math.min(minX, corner.X)
        minY = math.min(minY, corner.Y)
        maxX = math.max(maxX, corner.X)
        maxY = math.max(maxY, corner.Y)
    end

    return {
        corners = corners,
        topLeft = Vector2.new(math.floor(minX), math.floor(minY)),
        topRight = Vector2.new(math.floor(maxX), math.floor(minY)),
        bottomLeft = Vector2.new(math.floor(minX), math.floor(maxY)),
        bottomRight = Vector2.new(math.floor(maxX), math.floor(maxY))
    }
end

-- ESP object creation
local function createDrawingObject(type, properties)
    local obj = Drawing.new(type)
    for property, value in pairs(properties) do
        obj[property] = value
    end
    return obj
end

-- Main ESP functions
local function create_esp(player)
    if not player or player == lplr then return end
    
    local settings = esp_table.settings.enemy
    local objTable = {
        box_fill = createDrawingObject("Square", { Filled = true, Visible = false }),
        box_outline = createDrawingObject("Square", { Filled = false, Thickness = 3, Visible = false, ZIndex = -1 }),
        box = createDrawingObject("Square", { Filled = false, Thickness = 1, Visible = false }),
        realname = createDrawingObject("Text", { Center = true, Visible = false }),
        displayname = createDrawingObject("Text", { Center = true, Visible = false }),
        health = createDrawingObject("Text", { Center = false, Visible = false }),
        dist = createDrawingObject("Text", { Center = false, Visible = false }),
        weapon = createDrawingObject("Text", { Center = true, Visible = false }),
    }
    
    for partName in pairs(SKELETON_ORDER) do
        objTable["skeleton_" .. partName] = createDrawingObject("Line", { Visible = false })
    end

    local chamsObject = Instance.new("Highlight", container)
    chamsObject.Enabled = false
    
    local plrData = {
        obj = objTable,
        esp = {
            visible = false,
            onscreen = false,
            distance = 0,
            alive = false,
            current_gun = "",
            health = 0,
            max_health = 0,
            corners = nil,
            head = nil,
            character = nil
        },
        chams_object = chamsObject,
        plr_instance = player
    }
    
    loaded_plrs[player] = plrData
    
    plrData.connection = utility.new_renderstepped(function(delta)
        local data = loaded_plrs[player]
        if not data then return end
        
        camera = workspace.CurrentCamera
        if not camera then return end
        
        local obj = data.obj
        local espData = data.esp
        local main_settings = esp_table.main_settings
        local character = player.Character
        
        if not character or not character:FindFirstChild("Head") then
            for _, drawing in pairs(obj) do
                if drawing then
                    drawing.Visible = false
                end
            end
            data.chams_object.Enabled = false
            return
        end
        
        local head = character:FindFirstChild("Head")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local screenPos, onScreen = worldToScreen(head.Position)
        
        espData.onscreen = onScreen
        espData.character = character
        espData.head = head
        
        if not settings.enabled or 
           (main_settings.teamcheck and lplr.Team == player.Team) or
           not onScreen or
           (main_settings.distancelimit and (camera.CFrame.p - head.Position).Magnitude > main_settings.maxdistance) then
            for _, drawing in pairs(obj) do
                if drawing then
                    drawing.Visible = false
                end
            end
            data.chams_object.Enabled = false
            return
        end

        -- Update ESP data
        espData.distance = (camera.CFrame.p - head.Position).Magnitude
        espData.health = humanoid and humanoid.Health or 0
        espData.max_health = humanoid and humanoid.MaxHealth or 1
        espData.alive = humanoid and humanoid.Health > 0
        
        -- Calculate bounding box
        local parts = {}
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") and isBodyPart(child.Name) then
                table.insert(parts, child)
            end
        end
        
        local bboxCF, bboxSize = getBoundingBox(parts)
        if not bboxCF then
            for _, drawing in pairs(obj) do
                if drawing then
                    drawing.Visible = false
                end
            end
            data.chams_object.Enabled = false
            return
        end
        
        espData.corners = calculateCorners(bboxCF, bboxSize)
        local corners = espData.corners
        
        -- Update chams
        local cham = data.chams_object
        cham.Enabled = settings.chams
        if cham.Enabled then
            cham.DepthMode = settings.chams_visible_only and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
            cham.Adornee = character
            cham.FillColor = settings.chams_fill_color[1]
            cham.FillTransparency = settings.chams_fill_color[2]
            cham.OutlineColor = settings.chamsoutline_color[1]
            cham.OutlineTransparency = settings.chamsoutline_color[2]
        end

        -- Update box elements
        obj.box.Visible = settings.box
        obj.box_outline.Visible = settings.box and settings.box_outline
        obj.box_fill.Visible = settings.box and settings.box_fill
        
        if settings.box then
            obj.box.Position = corners.topLeft
            obj.box.Size = corners.bottomRight - corners.topLeft
            obj.box.Color = settings.box_color[1]
            obj.box.Transparency = settings.box_color[2]
            
            if settings.box_outline then
                obj.box_outline.Position = corners.topLeft + Vector2.new(1, 1)
                obj.box_outline.Size = corners.bottomRight - corners.topLeft - Vector2.new(2, 2)
                obj.box_outline.Color = settings.box_outline_color[1]
                obj.box_outline.Transparency = settings.box_outline_color[2]
            end
            
            if settings.box_fill then
                obj.box_fill.Position = corners.topLeft
                obj.box_fill.Size = corners.bottomRight - corners.topLeft
                obj.box_fill.Color = settings.box_fill_color[1]
                obj.box_fill.Transparency = settings.box_fill_color[2]
            end
        end

        -- Update text elements
        local textSize = main_settings.textSize
        local textFont = main_settings.textFont
        
        -- Real name
        obj.realname.Visible = settings.realname
        if settings.realname then
            obj.realname.Size = textSize
            obj.realname.Font = textFont
            obj.realname.Text = player.Name
            obj.realname.Color = settings.realname_color[1]
            obj.realname.Transparency = settings.realname_color[2]
            obj.realname.Outline = settings.realname_outline
            obj.realname.OutlineColor = settings.realname_outline_color
            obj.realname.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.new(0, obj.realname.TextBounds.Y + 2)
        end

        -- Display name
        obj.displayname.Visible = settings.displayname and player.Name ~= player.DisplayName
        if obj.displayname.Visible then
            obj.displayname.Size = textSize
            obj.displayname.Font = textFont
            obj.displayname.Text = player.DisplayName
            obj.displayname.Color = settings.displayname_color[1]
            obj.displayname.Transparency = settings.displayname_color[2]
            obj.displayname.Outline = settings.displayname_outline
            obj.displayname.OutlineColor = settings.displayname_outline_color
            local yOffset = obj.realname.Visible and obj.realname.TextBounds.Y or 0
            obj.displayname.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.new(0, obj.displayname.TextBounds.Y + yOffset + 2)
        end

        -- Distance
        obj.dist.Visible = settings.dist
        if settings.dist then
            obj.dist.Size = textSize
            obj.dist.Font = textFont
            obj.dist.Text = math.round(espData.distance) .. "s"
            obj.dist.Color = settings.dist_color[1]
            obj.dist.Transparency = settings.dist_color[2]
            obj.dist.Outline = settings.dist_outline
            obj.dist.OutlineColor = settings.dist_outline_color
            obj.dist.Position = corners.topRight + Vector2.new(2, 0) - Vector2.new(0, obj.dist.TextBounds.Y * 0.25)
        end

        -- Health
        obj.health.Visible = settings.health
        if settings.health then
            obj.health.Size = textSize
            obj.health.Font = textFont
            obj.health.Text = tostring(math.round(espData.health))
            obj.health.Color = settings.health_color[1]
            obj.health.Transparency = settings.health_color[2]
            obj.health.Outline = settings.health_outline
            obj.health.OutlineColor = settings.health_outline_color
            obj.health.Position = corners.topLeft - Vector2.new(obj.health.TextBounds.X + 2, obj.health.TextBounds.Y * 0.25)
        end

        -- Weapon
        obj.weapon.Visible = settings.weapon
        if settings.weapon then
            obj.weapon.Size = textSize
            obj.weapon.Font = textFont
            obj.weapon.Text = esp_table.get_gun(player)
            obj.weapon.Color = settings.weapon_color[1]
            obj.weapon.Transparency = settings.weapon_color[2]
            obj.weapon.Outline = settings.weapon_outline
            obj.weapon.OutlineColor = settings.weapon_outline_color
            obj.weapon.Position = (corners.bottomLeft + corners.bottomRight) * 0.5
        end

        -- Skeleton
        if settings.skeleton and espData.alive then
            for partName, parentName in pairs(SKELETON_ORDER) do
                local part = character:FindFirstChild(partName)
                local parentPart = character:FindFirstChild(parentName)
                
                if part and parentPart then
                    local partPos, partVisible = worldToScreen(part.Position)
                    local parentPos, parentVisible = worldToScreen(parentPart.Position)
                    
                    if partVisible and parentVisible then
                        local skeletonLine = obj["skeleton_" .. partName]
                        skeletonLine.Visible = true
                        skeletonLine.From = Vector2.new(partPos.X, partPos.Y)
                        skeletonLine.To = Vector2.new(parentPos.X, parentPos.Y)
                        skeletonLine.Color = settings.skeleton_color[1]
                        skeletonLine.Transparency = settings.skeleton_color[2]
                    else
                        if obj["skeleton_" .. partName] then
                            obj["skeleton_" .. partName].Visible = false
                        end
                    end
                else
                    if obj["skeleton_" .. partName] then
                        obj["skeleton_" .. partName].Visible = false
                    end
                end
            end
        else
            for partName in pairs(SKELETON_ORDER) do
                if obj["skeleton_" .. partName] then
                    obj["skeleton_" .. partName].Visible = false
                end
            end
        end

        -- Handle fade out when not alive
        if not espData.alive then
            local fadeAmount = delta / main_settings.fadetime
            for _, drawing in pairs(obj) do
                if drawing and drawing.Visible then
                    drawing.Transparency = math.max(0, drawing.Transparency - fadeAmount)
                    if drawing.Transparency <= 0 then
                        drawing.Visible = false
                    end
                end
            end
            
            if cham.Enabled then
                cham.FillTransparency = math.max(0, cham.FillTransparency - fadeAmount)
                cham.OutlineTransparency = math.max(0, cham.OutlineTransparency - fadeAmount)
                if cham.FillTransparency <= 0 or cham.OutlineTransparency <= 0 then
                    cham.Enabled = false
                end
            end
        end
    end)
end

local function destroy_esp(player)
    local plrData = loaded_plrs[player]
    if not plrData then return end
    
    if plrData.connection then
        plrData.connection:Disconnect()
    end
    
    for _, drawing in pairs(plrData.obj) do
        if drawing then
            pcall(function() drawing:Remove() end)
        end
    end
    
    if plrData.chams_object then
        pcall(function() plrData.chams_object:Destroy() end)
    end
    
    loaded_plrs[player] = nil
end

function esp_table.load()
    if esp_table.__loaded then
        warn("[ESP] Já está carregado")
        return
    end
    
    for _, player in ipairs(plrs:GetPlayers()) do
        if player ~= lplr then
            create_esp(player)
        end
    end
    
    esp_table.playerAdded = plrs.PlayerAdded:Connect(function(player)
        if player ~= lplr then
            create_esp(player)
        end
    end)
    
    esp_table.playerRemoving = plrs.PlayerRemoving:Connect(function(player)
        destroy_esp(player)
    end)
    
    esp_table.__loaded = true
    print("[ESP] Carregado com sucesso")
end

function esp_table.unload()
    if not esp_table.__loaded then
        warn("[ESP] Não está carregado")
        return
    end
    
    for player in pairs(loaded_plrs) do
        destroy_esp(player)
    end
    
    if esp_table.playerAdded then
        esp_table.playerAdded:Disconnect()
    end
    
    if esp_table.playerRemoving then
        esp_table.playerRemoving:Disconnect()
    end
    
    esp_table.__loaded = false
    print("[ESP] Descarregado com sucesso")
end

function esp_table.get_gun(player)
    if player and player.Character then
        for _, v in ipairs(player.Character:GetChildren()) do
            if v:IsA("Model") and not v.Name:find("Holster") and v:FindFirstChild("FlashPart") then
                return v.Name
            end
        end
    end
    return "None"
end

return esp_table
