-- Clears the console output before starting the script
print("Starting script...")
if typeof(clear) == "function" then clear() end

-- SERVICES: Getting the basic tools from Roblox to interact with the game
local Players = game:GetService("Players")           -- To get info about players
local RunService = game:GetService("RunService")     -- To run code every frame (very fast)
local UserInputService = game:GetService("UserInputService") -- To detect keyboard/mouse
local Workspace = game:GetService("Workspace")       -- To access the 3D world objects
local TweenService = game:GetService("TweenService") -- To create smooth animations
local RS = game:GetService("ReplicatedStorage")      -- To access shared game files
local lighting = game:GetService("Lighting")         -- To control sky, brightness, and time

-- SETTINGS & VARIABLES
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local RAYCAST_COOLDOWN = 0.15
local TARGET_HITBOX_SIZE = Vector3.new(15, 15, 15) -- Size of the modified hitboxes (bigger = easier to hit)

local activeNPCs = {}      -- List of enemies currently in the game
local trackedParts = {}    -- List of body parts we are watching
local originalSizes = {}   -- Storage for original sizes to restore them later
local wallConnections = {} -- List of technical connections to clean up later

-- TOGGLES (True = On / False = Off)
local wallEnabled = false       -- ESP (Wallhack)
local silentEnabled = false     -- Makes targets bigger
local showHitbox = false        -- Shows the big hitbox box
local fullBrightEnabled = false -- Removes shadows/darkness
local guiVisible = true         -- Menu visibility
local isUnloaded = false        -- To stop the script

local patchOptions = { recoil = false, firemodes = false }

-- COLORS (Red, Green, Blue: 0 to 255)
local visibleR, visibleG, visibleB = 0, 255, 0    -- Green for visible enemies
local hiddenR, hiddenG, hiddenB = 255, 0, 0       -- Red for enemies behind walls
local visibleColor = Color3.fromRGB(visibleR, visibleG, visibleB)
local hiddenColor = Color3.fromRGB(hiddenR, hiddenG, hiddenB)

-- Store original game lighting to restore it later
local originalLighting = {
    Brightness = lighting.Brightness,
    ClockTime = lighting.ClockTime,
    FogEnd = lighting.FogEnd,
    GlobalShadows = lighting.GlobalShadows,
    Ambient = lighting.Ambient
}

--- HELPER FUNCTIONS ---

-- Finds the main part of a character (Root)
local function getRootPart(model)
    return model:FindFirstChild("Root") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso")
end

-- Checks if the model is an AI/NPC enemy
local function hasAIChild(model)
    for _, c in ipairs(model:GetChildren()) do
        if type(c.Name) == "string" and c.Name:sub(1, 3) == "AI_" then return true end
    end
    return false
end

-- Creates the visual box for Wallhack (ESP)
local function createBoxForPart(part)
    if not part or part:FindFirstChild("Wall_Box") then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Wall_Box"
    box.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Adornee = part
    box.AlwaysOnTop = true -- This allows seeing it through walls
    box.ZIndex = 10
    box.Color3 = visibleColor
    box.Transparency = 0.3
    box.Parent = part
    trackedParts[part] = true
end

-- Removes all ESP boxes
local function destroyAllBoxes()
    for part, _ in pairs(trackedParts) do
        if part and part:FindFirstChild("Wall_Box") then pcall(function() part.Wall_Box:Destroy() end) end
    end
    trackedParts = {}
end

-- Makes the NPC hitboxes larger (Silent Aim effect)
local function applySilentHitbox(model, root)
    if not originalSizes[model] then originalSizes[model] = root.Size end
    root.Size = TARGET_HITBOX_SIZE
    root.Transparency = showHitbox and 0.85 or 1 -- If showHitbox is true, you'll see a faint box
    root.CanCollide = true
end

-- Restores hitboxes to their normal size
local function restoreOriginalSize(model)
    local root = getRootPart(model)
    if root and originalSizes[model] then
        root.Size = originalSizes[model]
        root.Transparency = 1
        root.CanCollide = false
    end
    originalSizes[model] = nil
end

-- Adds an enemy to our tracking list
local function addNPC(model)
    if activeNPCs[model] or model.Name ~= "Male" or not hasAIChild(model) then return end
    local head = model:FindFirstChild("Head")
    local root = getRootPart(model)
    if not head or not root then return end
    activeNPCs[model] = { head = head, root = root }
    if wallEnabled then createBoxForPart(head) end
end

-- Weapon Mods: Anti-Recoil and Firemodes
local function patchWeapons(options)
    local weaponsFolder = RS:FindFirstChild("Shared")
        and RS.Shared:FindFirstChild("Configs")
        and RS.Shared.Configs:FindFirstChild("Weapon")
        and RS.Shared.Configs.Weapon:FindFirstChild("Weapons_Player")
    
    if not weaponsFolder then return end

    for _, platform in pairs(weaponsFolder:GetChildren()) do
        if platform.Name:match("^Platform_") then
            for _, weapon in pairs(platform:GetChildren()) do
                for _, child in pairs(weapon:GetChildren()) do
                    if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                        local success, receiver = pcall(require, child)
                        if success and receiver and receiver.Config and receiver.Config.Tune then
                            local tune = receiver.Config.Tune
                            if options.recoil then
                                -- Set all recoil values to 0
                                tune.Recoil_X = 0 tune.Recoil_Z = 0 tune.RecoilForce_Tap = 0
                                tune.RecoilForce_Impulse = 0 tune.Recoil_Range = Vector2.zero
                                tune.Recoil_Camera = 0 tune.RecoilAccelDamp_Crouch = Vector3.new(1, 1, 1)
                                tune.RecoilAccelDamp_Prone = Vector3.new(1, 1, 1)
                            end
                            if options.firemodes then 
                                -- Unlocks Auto, Burst, and Semi fire modes
                                tune.Firemodes = {3, 2, 1, 0} 
                            end
                        end
                    end
                end
            end
        end
    end
end

--- GUI CREATION (The Menu) ---

local sg = Instance.new("ScreenGui", localPlayer.PlayerGui)
sg.Name = "BRM5_V6_Final"
sg.ResetOnSpawn = false -- GUI won't disappear when you die
sg.DisplayOrder = 9999

-- Main Window Frame
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 500, 0, 350)
main.Position = UDim2.new(0.5, -250, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

-- Make the GUI draggable
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
topBar.BorderSizePixel = 0
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)

RunService.RenderStepped:Connect(function()
    if dragging and dragInput then updateDrag(dragInput) end
end)

-- Title
local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "BRM5 v6.5 🎇"
title.Font = "GothamBold"
title.TextColor3 = Color3.fromRGB(85, 170, 255)
title.TextSize = 16
title.TextXAlignment = "Left"
title.BackgroundTransparency = 1

-- Sidebar for Tabs
local sidebar = Instance.new("Frame", main)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.Size = UDim2.new(0, 130, 1, -40)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sidebar.BorderSizePixel = 0

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 8)

-- Content Container
local container = Instance.new("Frame", main)
container.Position = UDim2.new(0, 140, 0, 50)
container.Size = UDim2.new(1, -150, 1, -60)
container.BackgroundTransparency = 1

-- Function to create a tab page
local function createTab()
    local f = Instance.new("ScrollingFrame", container)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.ScrollBarThickness = 2
    f.CanvasSize = UDim2.new(0, 0, 0, 0)
    f.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local l = Instance.new("UIListLayout", f)
    l.Padding = UDim.new(0, 12)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.SortOrder = Enum.SortOrder.LayoutOrder

    return f
end

-- Define Tabs
local tabCombat = createTab()
local tabVisuals = createTab()
local tabWeapons = createTab()
local tabColors = createTab()
local tabCredits = createTab()
tabCombat.Visible = true

local tabButtons = {}

-- Function to add buttons to the sidebar
local function addTabBtn(name, target)
    local b = Instance.new("TextButton", sidebar)
    b.Size = UDim2.new(1, -20, 0, 35)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    b.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    b.Font = "GothamMedium"
    b.TextSize = 13
    Instance.new("UICorner", b)

    tabButtons[name] = b
    if name == "Combat" then
        b.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
        b.TextColor3 = Color3.new(0, 0, 0)
    end

    b.Text = name
    b.MouseButton1Click:Connect(function()
        for n, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        end
        b.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
        b.TextColor3 = Color3.new(0, 0, 0)

        tabCombat.Visible = false
        tabVisuals.Visible = false
        tabWeapons.Visible = false
        tabColors.Visible = false
        tabCredits.Visible = false
        target.Visible = true
    end)
end

addTabBtn("Combat", tabCombat)
addTabBtn("Visuals", tabVisuals)
addTabBtn("Weapons", tabWeapons)
addTabBtn("Colors", tabColors)
addTabBtn("Credits", tabCredits)

-- Function to create Toggle Buttons inside tabs
local function createButton(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = "Gotham"
    btn.TextSize = 13
    Instance.new("UICorner", btn)
    local act = false
    btn.MouseButton1Click:Connect(function()
        act = not act
        btn.BackgroundColor3 = act and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(35, 35, 35)
        btn.TextColor3 = act and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
        cb(act)
    end)
end

-- COMBAT TAB
createButton(tabCombat, "Silent Hitbox", function(v) silentEnabled = v end)
createButton(tabCombat, "Show Hitbox", function(v) showHitbox = v end)

-- VISUALS TAB
createButton(tabVisuals, "Wall ESP", function(v)
    wallEnabled = v
    if wallEnabled then 
        for _, d in pairs(activeNPCs) do createBoxForPart(d.head) end 
    else 
        destroyAllBoxes() 
    end
end)
createButton(tabVisuals, "FullBright", function(v)
    fullBrightEnabled = v
    if not v then 
        -- Restore original lighting when turned off
        for p, val in pairs(originalLighting) do lighting[p] = val end 
    end
end)

-- WEAPONS TAB
local weaponNote = Instance.new("TextLabel", tabWeapons)
weaponNote.Size = UDim2.new(1, -10, 0, 30)
weaponNote.Text = "Reset character to apply changes"
weaponNote.TextColor3 = Color3.fromRGB(255, 100, 100)
weaponNote.Font = "GothamBold"
weaponNote.TextSize = 12
weaponNote.BackgroundTransparency = 1

createButton(tabWeapons, "Anti-Recoil", function(v) 
    patchOptions.recoil = v 
    patchWeapons(patchOptions) 
end)
createButton(tabWeapons, "Unlock Firemodes", function(v) 
    patchOptions.firemodes = v 
    patchWeapons(patchOptions) 
end)

-- COLORS TAB (Sliders for R, G, B)
local layoutIndex = 1
local function createLabel(parent, text, color)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, -10, 0, 30)
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.Font = "GothamBold"
    lbl.BackgroundTransparency = 1
    lbl.LayoutOrder = layoutIndex
    layoutIndex += 1
end

local function createSliderOrdered(parent, label, init, cb)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -10, 0, 50)
    f.BackgroundTransparency = 1
    f.LayoutOrder = layoutIndex
    layoutIndex += 1

    local l = Instance.new("TextLabel", f)
    l.Text = label .. ": " .. init
    l.Size = UDim2.new(1, 0, 0, 20)
    l.TextColor3 = Color3.new(1, 1, 1)
    l.BackgroundTransparency = 1
    l.TextXAlignment = "Left"

    local bar = Instance.new("Frame", f)
    bar.Position = UDim2.new(0, 0, 0, 25)
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(init / 255, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)

    local draggingS = false
    local function up()
        local p = math.clamp((UserInputService:GetMouseLocation().X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(p * 255)
        fill.Size = UDim2.new(p, 0, 1, 0)
        l.Text = label .. ": " .. val
        cb(val)
    end

    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingS = true up() end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingS = false end end)
    RunService.RenderStepped:Connect(function() if draggingS then up() end end)
end

createLabel(tabColors, "-- VISIBLE COLOR --", Color3.new(0.5, 1, 0.5))
createSliderOrdered(tabColors, "R", visibleR, function(v) visibleR = v visibleColor = Color3.fromRGB(visibleR, visibleG, visibleB) end)
createSliderOrdered(tabColors, "G", visibleG, function(v) visibleG = v visibleColor = Color3.fromRGB(visibleR, visibleG, visibleB) end)
createSliderOrdered(tabColors, "B", visibleB, function(v) visibleB = v visibleColor = Color3.fromRGB(visibleR, visibleG, visibleB) end)

createLabel(tabColors, "-- HIDDEN COLOR --", Color3.new(1, 0.5, 0.5))
createSliderOrdered(tabColors, "R", hiddenR, function(v) hiddenR = v hiddenColor = Color3.fromRGB(hiddenR, hiddenG, hiddenB) end)
createSliderOrdered(tabColors, "G", hiddenG, function(v) hiddenG = v hiddenColor = Color3.fromRGB(hiddenR, hiddenG, hiddenB) end)
createSliderOrdered(tabColors, "B", hiddenB, function(v) hiddenB = v hiddenColor = Color3.fromRGB(hiddenR, hiddenG, hiddenB) end)

-- CREDITS TAB
local function addCredit(text, font)
    local c = Instance.new("TextLabel", tabCredits)
    c.Size = UDim2.new(1, -10, 0, 50)
    c.Text = text
    c.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    c.Font = font or "Gotham"
    c.TextSize = 12
    c.TextWrapped = true
    c.BackgroundTransparency = 1
end

addCredit("Made by: HiIxX0Dexter0XxIiH", "GothamBold")
addCredit("https://github.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts", "Gotham")

-- UNLOAD BUTTON: Safely removes the script effects
local unl = Instance.new("TextButton", sidebar)
unl.Size = UDim2.new(0, 110, 0, 35)
unl.AnchorPoint = Vector2.new(0.5, 0)
unl.Position = UDim2.new(0.5, 0, 0, 0)
unl.Text = "Unload Script"
unl.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
unl.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", unl)
unl.MouseButton1Click:Connect(function()
    isUnloaded = true
    destroyAllBoxes()
    for m, _ in pairs(activeNPCs) do restoreOriginalSize(m) end
    for _, c in ipairs(wallConnections) do pcall(function() c:Disconnect() end) end
    sg:Destroy()
end)

--- MAIN GAME LOOPS ---

-- Detect NPCs already in game
for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") and m.Name == "Male" then if hasAIChild(m) then addNPC(m) end end
end

-- Detect new NPCs when they spawn
table.insert(wallConnections, Workspace.ChildAdded:Connect(function(m)
    if m:IsA("Model") and m.Name == "Male" then 
        task.delay(0.2, function() if hasAIChild(m) then addNPC(m) end end) 
    end
end))

-- Continuous loop for Lighting, ESP Visibility, and Hitbox checks
RunService.RenderStepped:Connect(function()
    if isUnloaded then return end

    -- Apply FullBright if enabled
    if fullBrightEnabled then
        lighting.Brightness = 2
        lighting.ClockTime = 12
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
        lighting.Ambient = Color3.new(1, 1, 1)
    end

    for m, d in pairs(activeNPCs) do
        -- Update ESP colors based on line of sight
        if wallEnabled and d.head and d.head:FindFirstChild("Wall_Box") then
            local origin = camera.CFrame.Position
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            rp.FilterDescendantsInstances = {localPlayer.Character, d.head}
            
            -- Raycast to check if there is a wall between you and the NPC
            local r = Workspace:Raycast(origin, d.head.Position - origin, rp)
            d.head.Wall_Box.Color3 = (not r or r.Instance:IsDescendantOf(m)) and visibleColor or hiddenColor
        end

        -- Apply larger hitboxes if enabled
        if silentEnabled then applySilentHitbox(m, d.root) end
    end
end)

-- Toggle Menu visibility with the "INSERT" key
UserInputService.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.Insert then
        guiVisible = not guiVisible
        main.Visible = guiVisible
    end
end)
