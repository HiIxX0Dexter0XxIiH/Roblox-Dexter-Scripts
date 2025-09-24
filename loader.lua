-- Variables
local player = game.Players.LocalPlayer
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

-- Create buttons
local pvpButton = createButton("PVPButton", "PVP", Color3.fromRGB(200, 60, 60), 60)
local pveButton = createButton("PVEButton", "PVE", Color3.fromRGB(60, 200, 60), 115)

-- Ensure character is loaded
local function getSafeCharacter()
    local character = player.Character
    if not character or not character.Parent then
        character = player.CharacterAdded:Wait()
    end
    return character
end

-- Mode selection functions
local function onPvpSelected()
    -- Deshabilitar botones inmediatamente
    pvpButton.AutoButtonColor = false
    pveButton.AutoButtonColor = false
    pvpButton.Text = "Loading..."
    pveButton.Text = "Please wait..."

    -- Destruir GUI antes de cargar el script
    screenGui:Destroy()

    -- Ejecutar script en segundo plano
    task.spawn(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/refs/heads/main/BRM5-PVP.lua"))()
    end)
end

local function onPveSelected()
    -- Deshabilitar botones inmediatamente
    pvpButton.AutoButtonColor = false
    pveButton.AutoButtonColor = false
    pvpButton.Text = "Please wait..."
    pveButton.Text = "Loading..."

    -- Destruir GUI antes de cargar el script
    screenGui:Destroy()

    -- Ejecutar script en segundo plano
    task.spawn(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/refs/heads/main/BRM5-PVE.lua"))()
    end)
end

-- Connect buttons
pvpButton.MouseButton1Click:Connect(onPvpSelected)
pveButton.MouseButton1Click:Connect(onPveSelected)
