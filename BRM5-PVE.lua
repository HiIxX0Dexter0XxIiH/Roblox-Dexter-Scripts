-- BRM5 v6 OPTIMIZED by dexter

-- Services used
Players = game:GetService("Players")
local RunService = game:GetService("RunService")           -- For RenderStepped updates
local UserInputService = game:GetService("UserInputService") -- For keyboard input
local Workspace = game:GetService("Workspace")             -- To access all objects in the game world
local localPlayer = Players.LocalPlayer                     -- Reference to the local player
local camera = Workspace.CurrentCamera                      -- Reference to the current camera

-- Constants
local RAYCAST_COOLDOWN = 0.15                               -- Minimum time between raycasts
local TARGET_HITBOX_SIZE = Vector3.new(15, 15, 15)          -- Size used for "silent hitbox"

-- Data tables
local activeNPCs = {}        -- Tracks currently active NPCs
local trackedParts = {}      -- Tracks parts that have a box adornment
local originalSizes = {}     -- Stores original sizes of NPC root parts
local wallEnabled = false    -- Toggles wall ESP
local silentEnabled = false  -- Toggles silent aim hitbox
local showHitbox = false     -- Toggles hitbox visibility
local guiVisible = true      -- Tracks whether GUI is visible
local isUnloaded = false     -- Indicates if the script has been unloaded
local wallConnections = {}   -- Stores event connections for cleanup

-- Returns the "root" part of a model
local function getRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("Root") 
        or model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("UpperTorso")
end

-- Checks if a model contains any AI child
local function hasAIChild(model)
    if not model then return false end
    for _, c in ipairs(model:GetChildren()) do
        if type(c.Name) == "string" and c.Name:sub(1,3) == "AI_" then
            return true
        end
    end
    return false
end

-- Creates a visible box around a part (ESP)
local function createBoxForPart(part)
    if isUnloaded or not part or not part.Parent then return end
    if part:FindFirstChild("Wall_Box") then return end -- Skip if box already exists
    local boxSize = part.Size + Vector3.new(0.1, 0.1, 0.1)
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Wall_Box"
    box.Size = boxSize
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Color3 = Color3.fromRGB(255, 0, 0) -- Red by default
    box.Transparency = 0.3
    box.Parent = part
    trackedParts[part] = true
end

-- Destroys all active boxes
local function destroyAllBoxes()
    for part, _ in pairs(trackedParts) do
        if part and part.Parent and part:FindFirstChild("Wall_Box") then
            pcall(function() part.Wall_Box:Destroy() end)
        end
    end
    trackedParts = {}
end

-- Expands the NPC's root part to a larger "silent hitbox"
local function applySilentHitbox(model, root)
    if not model or not root then return end
    if not originalSizes[model] then originalSizes[model] = root.Size end
    if root.Size ~= TARGET_HITBOX_SIZE then
        root.Size = TARGET_HITBOX_SIZE
        root.Transparency = showHitbox and 0.85 or 1
        root.CanCollide = true
    end
end

-- Restores the original size of an NPC's root part
local function restoreOriginalSize(model)
    local root = getRootPart(model)
    if originalSizes[model] and root then
        pcall(function()
            root.Size = originalSizes[model]
            root.Transparency = 1
            root.CanCollide = false
        end)
    end
    originalSizes[model] = nil
end

-- Removes an NPC from tracking and cleans up adornments/events
local function removeNPC(model)
    if not model then return end
    local data = activeNPCs[model]
    if data then
        -- Destroy head box if exists
        if data.head and data.head:FindFirstChild("Wall_Box") then
            pcall(function() data.head.Wall_Box:Destroy() end)
            trackedParts[data.head] = nil
        end
        -- Disconnect all connected events
        if data.conns then
            for _, c in ipairs(data.conns) do
                pcall(function() c:Disconnect() end)
            end
        end
    end
    activeNPCs[model] = nil
    restoreOriginalSize(model)
end

-- Adds an NPC to tracking if it's valid
local function addNPC(model)
    if isUnloaded or not model or activeNPCs[model] then return end
    if not model:IsA("Model") or model.Name ~= "Male" then return end
    if not hasAIChild(model) then return end

    local head = model:FindFirstChild("Head")
    local root = getRootPart(model)
    if not head or not root then return end

    activeNPCs[model] = { head = head, root = root, conns = {} }

    -- Create ESP box if wall is enabled
    if wallEnabled then createBoxForPart(head) end

    -- Monitor NPC removal
    local ancestryConn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then removeNPC(model) end
    end)
    table.insert(activeNPCs[model].conns, ancestryConn)
    table.insert(wallConnections, ancestryConn)

    -- Monitor NPC death
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local diedConn = humanoid.Died:Connect(function()
            task.delay(0, function() removeNPC(model) end)
        end)
        table.insert(activeNPCs[model].conns, diedConn)
        table.insert(wallConnections, diedConn)
    end

    -- Monitor AI child removal
    local childRemovedConn = model.ChildRemoved:Connect(function(child)
        if child and type(child.Name) == "string" and child.Name:sub(1,3) == "AI_" then
            if not hasAIChild(model) then removeNPC(model) end
        end
    end)
    table.insert(activeNPCs[model].conns, childRemovedConn)
    table.insert(wallConnections, childRemovedConn)
end

-- Watches a model for AI children being added
local function watchModelForAI(model)
    if isUnloaded or not model or not model:IsA("Model") or model.Name ~= "Male" then return end
    if hasAIChild(model) then addNPC(model) return end

    local conn = model.ChildAdded:Connect(function(child)
        if child and type(child.Name) == "string" and child.Name:sub(1,3) == "AI_" then
            task.delay(0.1, function()
                if hasAIChild(model) then addNPC(model) end
            end)
        end
    end)
    table.insert(wallConnections, conn)

    local anc = model.AncestryChanged:Connect(function(_, parent)
        if not parent then pcall(function() conn:Disconnect() end) end
    end)
    table.insert(wallConnections, anc)
end

-- Initial scan of workspace for NPCs
for _, child in ipairs(Workspace:GetChildren()) do
    if child:IsA("Model") and child.Name == "Male" then
        if hasAIChild(child) then addNPC(child) else watchModelForAI(child) end
    end
end

-- Track newly added NPCs in workspace
local workspaceChildAdded = Workspace.ChildAdded:Connect(function(child)
    if isUnloaded then return end
    if child:IsA("Model") and child.Name == "Male" then
        task.delay(0.2, function()
            if isUnloaded then return end
            if hasAIChild(child) then addNPC(child) else watchModelForAI(child) end
        end)
    end
end)
table.insert(wallConnections, workspaceChildAdded)

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Wall_GUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.Size = UDim2.new(0, 200, 0, 210)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = guiVisible
mainFrame.AnchorPoint = Vector2.new(0, 0)
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", mainFrame)
title.Text = "BRM5 v6 by dexter"
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.BorderSizePixel = 0
Instance.new("UICorner", title)

-- Container for buttons
local buttonContainer = Instance.new("Frame", mainFrame)
buttonContainer.Position = UDim2.new(0, 0, 0, 40)
buttonContainer.Size = UDim2.new(1, 0, 1, -40)
buttonContainer.BackgroundTransparency = 1

local uiList = Instance.new("UIListLayout", buttonContainer)
uiList.Padding = UDim.new(0, 8)
uiList.FillDirection = Enum.FillDirection.Vertical
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiList.VerticalAlignment = Enum.VerticalAlignment.Top

-- Helper function to create buttons
local function createButton(text, color, parent)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Text = text
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham
    btn.TextScaled = true
    Instance.new("UICorner", btn)
    return btn
end

-- Wall ESP toggle button
local toggleBtn = createButton("Wall OFF", Color3.fromRGB(40, 40, 40), buttonContainer)
toggleBtn.MouseButton1Click:Connect(function()
    wallEnabled = not wallEnabled
    toggleBtn.Text = wallEnabled and "Wall ON" or "Wall OFF"
    if wallEnabled then
        for model, data in pairs(activeNPCs) do
            if data and data.head then createBoxForPart(data.head) end
        end
    else
        destroyAllBoxes()
    end
end)

-- Silent hitbox toggle button
local silentBtn = createButton("Silent OFF (RISKY)", Color3.fromRGB(80, 20, 20), buttonContainer)
silentBtn.Font = Enum.Font.GothamBold
silentBtn.MouseButton1Click:Connect(function()
    silentEnabled = not silentEnabled
    silentBtn.Text = silentEnabled and "Silent ON (RISKY)" or "Silent OFF (RISKY)"
    if not silentEnabled then
        for model, _ in pairs(originalSizes) do restoreOriginalSize(model) end
    end
end)

-- Hitbox visibility toggle button
local hitboxBtn = createButton("Show Hitbox OFF", Color3.fromRGB(40, 80, 40), buttonContainer)
hitboxBtn.MouseButton1Click:Connect(function()
    showHitbox = not showHitbox
    hitboxBtn.Text = showHitbox and "Show Hitbox ON" or "Show Hitbox OFF"
    for model, _ in pairs(originalSizes) do
        local root = getRootPart(model)
        if root then root.Transparency = showHitbox and 0.85 or 1 end
    end
end)

-- Unload script button
local unloadBtn = createButton("Unload", Color3.fromRGB(100, 0, 0), buttonContainer)
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.MouseButton1Click:Connect(function()
    isUnloaded = true
    destroyAllBoxes()
    for model, _ in pairs(activeNPCs) do restoreOriginalSize(model) end
    activeNPCs = {}
    originalSizes = {}
    for _, conn in ipairs(wallConnections) do pcall(function() conn:Disconnect() end) end
    wallConnections = {}
    pcall(function() screenGui:Destroy() end)
end)

-- Main update loop (runs every frame)
local lastRaycast = 0
local renderConn = RunService.RenderStepped:Connect(function(dt)
    if isUnloaded then return end
    lastRaycast = lastRaycast + dt
    local doRaycast = false
    if lastRaycast >= RAYCAST_COOLDOWN then
        doRaycast = true
        lastRaycast = 0
    end

    for model, data in pairs(activeNPCs) do
        if not model or not data then
            activeNPCs[model] = nil
        else
            local head = data.head
            local root = data.root

            -- Wall ESP visibility update
            if wallEnabled and head and head.Parent and head:FindFirstChild("Wall_Box") and doRaycast then
                local origin = camera and camera.CFrame.Position 
                    or (localPlayer.Character and localPlayer.Character:FindFirstChild("Head") and localPlayer.Character.Head.Position) 
                    or Vector3.new(0,0,0)
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                rayParams.FilterDescendantsInstances = { localPlayer.Character, head }
                local direction = head.Position - origin
                if direction.Magnitude > 0 then
                    local result = Workspace:Raycast(origin, direction, rayParams)
                    local isVisible = (not result) or (result.Instance and result.Instance:IsDescendantOf(model))
                    local box = head:FindFirstChild("Wall_Box")
                    if box then
                        local targetColor = isVisible and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
                        if box.Color3 ~= targetColor then box.Color3 = targetColor end
                    end
                end
            end

            -- Apply silent hitbox if enabled
            if silentEnabled and root then applySilentHitbox(model, root) end
        end
    end
end)
table.insert(wallConnections, renderConn)

-- Input listener for toggling GUI
local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isUnloaded then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        guiVisible = not guiVisible
        mainFrame.Visible = guiVisible
    end
end)
table.insert(wallConnections, inputConn)

print("[BRM5 v6] Script loaded and optimized with modified CanCollide.")
