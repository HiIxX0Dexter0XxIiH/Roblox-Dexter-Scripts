local player = game.Players.LocalPlayer
local placeId = game.PlaceId

local function resolveBranch()
    local env = _G
    if typeof(getgenv) == "function" then
        env = getgenv()
    end

    local branch = env and env.BRM5_BRANCH
    if type(branch) == "string" and branch ~= "" then
        return branch
    end

    return "main"
end

local BRANCH = resolveBranch()

local PVP_PLACE_IDS = {
    [5289429734] = true,
    [5480112241] = true,
    [4524359706] = true,
    [5468388011] = true,
    [3826587512] = true
}

local PVE_PLACE_IDS = {
    [3701546109] = true
}

local function loadRemoteScript(url)
    task.spawn(function()
        loadstring(game:HttpGet(url .. "?v=" .. tostring(os.time())))()
    end)
end

local function loadPvp()
    loadRemoteScript("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/" .. BRANCH .. "/brm5-pvp/main.lua")
end

local function loadPve()
    loadRemoteScript("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/" .. BRANCH .. "/brm5-pve/main.lua")
end

if PVP_PLACE_IDS[placeId] then
    loadPvp()
    return
end

if PVE_PLACE_IDS[placeId] then
    loadPve()
    return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModeSelectionGUI"
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main Frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 200)
frame.Position = UDim2.new(0.5, -160, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

-- Rounded corners
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Select a Mode"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = frame

-- Button creation function
local function createButton(name, text, color, posY)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.8, 0, 0, 45)
    button.Position = UDim2.new(0.1, 0, 0, posY)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.AutoButtonColor = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    button.Parent = frame
    return button
end

local pvpButton = createButton("PVPButton", "PVP", Color3.fromRGB(200, 60, 60), 60)
local pveButton = createButton("PVEButton", "PVE", Color3.fromRGB(60, 200, 60), 115)

local function setLoadingState(pvpText, pveText)
    pvpButton.AutoButtonColor = false
    pveButton.AutoButtonColor = false
    pvpButton.Text = pvpText
    pveButton.Text = pveText
    screenGui:Destroy()
end

local function onPvpSelected()
    setLoadingState("Loading...", "Please wait...")
    loadPvp()
end

local function onPveSelected()
    setLoadingState("Please wait...", "Loading...")
    loadPve()
end

pvpButton.MouseButton1Click:Connect(onPvpSelected)
pveButton.MouseButton1Click:Connect(onPveSelected)
