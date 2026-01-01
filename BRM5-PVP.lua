-- BRM5 v6.5 by dexter 
-- Credits to ryknuq and their overvoltage script, which helped me understand how to integrate the Aim into my script. Without their script, I don't think I could have done this.

-- Obtaining essential Roblox services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Local variables for player and configuration
local LocalPlayer = Players.LocalPlayer -- Reference to the local player
local configFile = "Dexter_Config.txt" -- Configuration file name

-- Constants for target detection
local TARGET_NAME = "Male" -- Name of the target NPC model
local TARGET_PART = "Head" -- NPC body part to aim at
local REQUIRED_CHILD = "Wall_Box" -- Name of the required child object to identify valid targets for the Aim
local DEADZONE = 1.5 -- Deadzone for the Aim, to avoid jerky movements with small deltas

-- Tables and state variables
local trackedParts = {} -- Stores NPC parts that are being tracked (for Wall)
local wallConnections = {} -- Stores event connections for Wall
local wallEnabled = false -- Wall state (on/off)
local guiVisible = true -- GUI visibility state
local isUnloaded = false -- Indicates if the script has been unloaded/disabled

-- configuration variables
local aimEnabled = false -- Aim state (on/off)
local smoothing = 95 -- Aim smoothing level (0-100, higher = smoother)
local holdingRightClick = false -- Indicates if the player is holding down the right mouse button
local fovEnabled = false -- FOV (field of view) circle state (on/off)
local fovRadius = 100 -- FOV circle radius in pixels

-- Creation of the FOV circle (initially invisible)
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(0, 255, 0) -- Green color
fovCircle.Thickness = 2 -- Line thickness
fovCircle.Filled = false -- Do not fill the circle
fovCircle.Visible = false -- Initially invisible

-- Function to save the current configuration to a file
local function saveConfig(config)
    if writefile then -- Checks if the 'writefile' function is available (exploit environments)
        writefile(configFile, HttpService:JSONEncode({ -- Encodes the configuration table to JSON and writes it
            wall = config.wall,
            aim = config.aim,
            fovEnabled = config.fovEnabled,
            fovRadius = config.fovRadius,
            smoothing = config.smoothing
        }))
    end
end

-- Function to load the configuration from a file
local function loadConfig()
    if isfile and isfile(configFile) and readfile then -- Checks if 'isfile' and 'readfile' functions are available and if the file exists
        local success, data = pcall(function() -- Safely tries to decode the JSON file
            return HttpService:JSONDecode(readfile(configFile))
        end)
        if success then -- If decoding was successful
            return { -- Returns the loaded configuration, with default values if any are missing
                wall = data.wall or false,
                aim = data.aim or false,
                fovEnabled = data.fovEnabled or false,
                fovRadius = data.fovRadius or 100,
                smoothing = data.smoothing or 95
            }
        end
    end
    -- Returns the default configuration if the file could not be loaded
    return {
        wall = false,
        aim = false,
        fovEnabled = false,
        fovRadius = 100,
        smoothing = 95
    }
end

-- Loads the configuration when the script starts
local currentConfig = loadConfig() -- Renamed 'config' to 'currentConfig' to avoid conflict with the function parameter name
wallEnabled = currentConfig.wall
aimEnabled = currentConfig.aim
fovEnabled = currentConfig.fovEnabled
fovRadius = currentConfig.fovRadius
smoothing = currentConfig.smoothing

-- Function to destroy all Wall boxes
local function destroyAllBoxes()
    for part, _ in pairs(trackedParts) do
        if part and part.Parent and part:FindFirstChild("Wall_Box") then
            part.Wall_Box:Destroy() -- Destroys the box instance
        end
    end
    trackedParts = {} -- Empties the tracked parts table
end

local function createBoxForPart(part)
    if isUnloaded or not part or part.Parent == nil or part:FindFirstChild("Wall_Box") then return end -- Conditions for not creating the box
    task.wait(0.5) -- Short wait to ensure the part is fully loaded
    if not part or not part.Parent or part:FindFirstChild("Wall_Box") then return end -- Double check

    local box = Instance.new("BoxHandleAdornment") -- Creates the visual object for the Wall
    box.Name = "Wall_Box" -- Object name
    box.Size = part.Size + Vector3.new(0.1, 0.1, 0.1) -- Size slightly larger than the part
    box.Adornee = part -- Associates the box with the NPC part
    box.AlwaysOnTop = true -- Always visible through other objects
    box.ZIndex = 5 -- Rendering order
    box.Color3 = Color3.fromRGB(255, 0, 0) -- Initial color (red by default, will change if visible)
    box.Transparency = 0.3 -- Box transparency
    box.Parent = part -- Parents the box to the part

    trackedParts[part] = true -- Adds the part to the tracked list
end

-- Function to create boxes for all existing NPCs that meet the criteria
local function createBoxesForAllNPCs()
    for _, npc in ipairs(Workspace:GetDescendants()) do -- Iterates over all descendants of the Workspace
        if npc:IsA("Model") and npc.Name == TARGET_NAME then -- If it's a model with the target name
            local head = npc:FindFirstChild(TARGET_PART) -- Looks for the target part (head)
            if head then createBoxForPart(head) end -- If found, creates the box
        end
    end
end

-- Function to register existing NPCs at startup (without creating boxes yet, just adds them to trackedParts)
local function registerExistingNPCs()
    for _, npc in ipairs(Workspace:GetDescendants()) do
        if npc:IsA("Model") and npc.Name == TARGET_NAME then
            local head = npc:FindFirstChild(TARGET_PART)
            if head then trackedParts[head] = true end -- Only registers that it exists
        end
    end
end

-- Creation of the graphical user interface (GUI)
local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui")) -- Main GUI container
gui.Name = "AimWallGUI"
gui.ResetOnSpawn = false -- So the GUI doesn't reset when the player respawns
gui.DisplayOrder = 9999 -- High display order to be on top of other GUIs

local frame = Instance.new("Frame", gui) -- Main GUI frame
frame.Size = UDim2.new(0, 260, 0, 418) -- Frame size
frame.Position = UDim2.new(0, 20, 0, 60) -- Frame position
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Dark background color
frame.Active = true -- Allows the GUI to capture clicks
frame.Draggable = true -- Allows the frame to be draggable
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8) -- Rounded corners for the frame

-- Helper function to create buttons within the frame
local function createButton(text, positionY, color)
    local button = Instance.new("TextButton", frame)
    button.Size = UDim2.new(0.9, 0, 0, 30) -- Size relative to the frame
    button.Position = UDim2.new(0.05, 0, 0, positionY) -- Position relative to the frame
    button.Text = text -- Button text
    button.BackgroundColor3 = color -- Background color
    button.TextColor3 = Color3.new(1, 1, 1) -- Text color (white)
    button.Font = Enum.Font.GothamBold -- Text font
    button.TextSize = 16 -- Text size
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6) -- Rounded corners for the button
    return button
end

-- Creation of the GUI title
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "🎯 BRM5 v4 - by Dexter"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.BackgroundTransparency = 1 -- Transparent background

-- Creation of the button to enable/disable Wall
local wallBtn = createButton(wallEnabled and "Wall: ON" or "Wall: OFF", 40, Color3.fromRGB(60, 60, 60))
wallBtn.MouseButton1Click:Connect(function() -- Event on button click
    wallEnabled = not wallEnabled -- Toggles the Wall state
    currentConfig.wall = wallEnabled -- Updates the configuration
    saveConfig(currentConfig) -- Saves the configuration
    wallBtn.Text = "Wall: " .. (wallEnabled and "ON" or "OFF") -- Updates the button text
    wallBtn.BackgroundColor3 = wallEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60) -- Changes the button color

    -- Updates the transparency of existing boxes based on Wall state
    for part, _ in pairs(trackedParts) do
        local box = part:FindFirstChild("Wall_Box")
        if box and box:IsA("BoxHandleAdornment") then
            box.Transparency = wallEnabled and 0.3 or 1 -- 0.3 if ON, 1 (invisible) if OFF
        end
    end
end)

-- Event to show/hide the GUI when the "Insert" key is pressed
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end -- If the input was already processed by another GUI, do nothing
    if input.KeyCode == Enum.KeyCode.Insert then
        guiVisible = not guiVisible -- Toggles the visibility state
        frame.Visible = guiVisible -- Applies the state to the frame

        -- If the GUI is hidden, locks the cursor to the center for the game
        if not guiVisible then
            UserInputService.MouseIconEnabled = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    end
end)

-- Creation of the button to enable/disable Aim
local aimBtn = createButton("Aim: OFF", 80, Color3.fromRGB(60, 60, 60))
aimBtn.MouseButton1Click:Connect(function()
    aimEnabled = not aimEnabled -- Toggles the Aim state
    aimBtn.Text = "Aim: " .. (aimEnabled and "ON" or "OFF") -- Updates the text
    aimBtn.BackgroundColor3 = aimEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60) -- Changes the color
    currentConfig.aim = aimEnabled -- Updates the configuration
    saveConfig(currentConfig) -- Saves the configuration
end)

-- Creation of the button to enable/disable FOV
local fovBtn = createButton("FOV: OFF", 120, Color3.fromRGB(60, 60, 60))
fovBtn.MouseButton1Click:Connect(function()
    fovEnabled = not fovEnabled -- Toggles the FOV state
    fovBtn.Text = "FOV: " .. (fovEnabled and "ON" or "OFF") -- Updates the text
    fovBtn.BackgroundColor3 = fovEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 60) -- Changes the color
    currentConfig.fovEnabled = fovEnabled -- Updates the configuration
    saveConfig(currentConfig) -- Saves the configuration
end)

-- Creation of the button to unload/disable the script
local unloadBtn = createButton("Unload", 160, Color3.fromRGB(170, 0, 0)) -- Red color to indicate destructive action
unloadBtn.MouseButton1Click:Connect(function()
    isUnloaded = true -- Marks the script as unloaded
    destroyAllBoxes() -- Destroys all Wall boxes
    fovCircle:Remove() -- Removes the FOV circle
    gui:Destroy() -- Destroys the GUI
    for _, conn in ipairs(wallConnections) do pcall(function() conn:Disconnect() end) end -- Disconnects all event connections
    if mainRenderLoop then mainRenderLoop:Disconnect() end -- Disconnects the main RenderStepped loop (using 'mainRenderLoop' for the first loop)
end)

-- Botón de No Recoil (Anti-recoil)
local noRecoilBtn = createButton("No Recoil: OFF", 200, Color3.fromRGB(60, 60, 60))
local noRecoilEnabled = false

noRecoilBtn.MouseButton1Click:Connect(function()
    noRecoilEnabled = not noRecoilEnabled
    noRecoilBtn.Text = "No Recoil: " .. (noRecoilEnabled and "ON" or "OFF")
    noRecoilBtn.BackgroundColor3 = noRecoilEnabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 60)

    -- Código que elimina el retroceso si está activado
    local weaponsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
        and game:GetService("ReplicatedStorage").Shared:FindFirstChild("Configs")
        and game:GetService("ReplicatedStorage").Shared.Configs:FindFirstChild("Weapon")
        and game:GetService("ReplicatedStorage").Shared.Configs.Weapon:FindFirstChild("Weapons_Player")

    if weaponsFolder then
        for _, platform in pairs(weaponsFolder:GetChildren()) do
            if platform.Name:match("^Platform_") then
                for _, weapon in pairs(platform:GetChildren()) do
                    for _, child in pairs(weapon:GetChildren()) do
                        if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                            local success, receiver = pcall(require, child)
                            if success and receiver and receiver.Config and receiver.Config.Tune then
                                local tune = receiver.Config.Tune
                                if noRecoilEnabled then
                                    tune.Recoil_X = 0
                                    tune.Recoil_Z = 0
                                    tune.RecoilForce_Tap = 0
                                    tune.RecoilForce_Impulse = 0
                                    tune.Recoil_Range = Vector2.zero
                                    tune.Recoil_Camera = 0
                                    tune.RecoilAccelDamp_Crouch = Vector3.new(1, 1, 1)
                                    tune.RecoilAccelDamp_Prone = Vector3.new(1, 1, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)



-- Function to create a slider control in the GUI
local function createSlider(labelText, min, max, defaultValue, positionY, callback) -- Renamed 'default' to 'defaultValue'
    -- Slider label
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, positionY)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText .. ": " .. defaultValue

    -- Slider background
    local sliderBack = Instance.new("Frame", frame)
    sliderBack.Size = UDim2.new(0.9, 0, 0, 6)
    sliderBack.Position = UDim2.new(0.05, 0, 0, positionY + 22)
    sliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Instance.new("UICorner", sliderBack).CornerRadius = UDim.new(0, 4)

    -- Slider button/indicator that is dragged
    local sliderButton = Instance.new("TextButton", sliderBack)
    sliderButton.Size = UDim2.new(0, 10, 1.5, 0) -- Indicator size
    sliderButton.Position = UDim2.new((defaultValue - min) / (max - min), -5, 0, -2) -- Initial position based on the default value
    sliderButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255) -- Indicator color
    sliderButton.Text = "" -- No text
    Instance.new("UICorner", sliderButton).CornerRadius = UDim.new(1, 0) -- Circular indicator

    local dragging = false -- State to know if the slider is being dragged

    -- Event when the slider button is pressed
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)

    -- Event when the mouse button is released anywhere
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false -- Stop dragging
        end
    end)

    -- Updates the slider position and value while dragging
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mouseXPosition = UserInputService:GetMouseLocation().X -- Mouse X position
            -- Calculates the relative mouse position within the slider background
            local relativeXPosition = math.clamp((mouseXPosition - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
            local value = math.floor((min + (max - min) * relativeXPosition) + 0.5) -- Calculates the slider value
            sliderButton.Position = UDim2.new(relativeXPosition, -5, 0, -2) -- Updates the indicator position
            label.Text = labelText .. ": " .. value -- Updates the label text
            callback(value) -- Calls the callback function with the new value
        end
    end)
end

-- Creation of the slider for FOV Radius
createSlider("FOV Radius", 0, 500, fovRadius, 240, function(value)
    fovRadius = value -- Updates the global radius variable
    currentConfig.fovRadius = value -- Updates the configuration
    saveConfig(currentConfig) -- Saves the configuration
end)

-- Creation of the slider for Aim Smoothing
createSlider("Smoothing", 0, 100, smoothing, 300, function(value)
    smoothing = value -- Updates the global smoothing variable
    currentConfig.smoothing = value -- Updates the configuration
    saveConfig(currentConfig) -- Saves the configuration
end)

-- Configuration of the instruction label
local instructionLabelYPosition = 298 -- Renamed 'noteLabelY'
local instructionTextContent = "READ before using the script:\nEach time you start a round, during the first few seconds (when you still can't move), press the U key and look at all your team members. This will mark them as allies so they don't appear on the WALL or AIM.\n\nYou must do this every round. This is a beta version, so for now the process is manual. However, as soon as I find a way, I will update the script to automatically detect teammates." -- Renamed 'noteText'

local instructionNote = Instance.new("TextLabel", frame) -- Label to display instructions
instructionNote.Name = "InstructionNote"
instructionNote.Size = UDim2.new(0.9, 0, 0, 110)
instructionNote.Position = UDim2.new(0.05, 0, 0, 340)
instructionNote.BackgroundTransparency = 1
instructionNote.TextColor3 = Color3.fromRGB(230, 230, 230)
instructionNote.Font = Enum.Font.Gotham
instructionNote.TextSize = 12
instructionNote.TextWrapped = true -- Allows text to wrap to multiple lines
instructionNote.TextXAlignment = Enum.TextXAlignment.Left
instructionNote.TextYAlignment = Enum.TextYAlignment.Top
instructionNote.Text = instructionTextContent -- Assigns the instruction text

-- Events to detect if the right mouse button is held down (for Aim)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holdingRightClick = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holdingRightClick = false end
end)

-- Function to get the closest valid head to the screen center
local function getClosestValidHead()
    local closestTarget, minDistance = nil, math.huge -- Initializes the closest target and minimum distance
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) -- Screen center

    for _, model in ipairs(Workspace:GetChildren()) do -- Iterates over the direct children of the Workspace
        if model:IsA("Model") and model.Name == TARGET_NAME then -- If it's a model with the target name
            local head = model:FindFirstChild(TARGET_PART) -- Looks for the head
            -- Checks that the head exists, is a BasePart, and has Wall_Box (indicator of a valid enemy)
            if head and head:IsA("BasePart") and head:FindFirstChild(REQUIRED_CHILD) then
                local box = head:FindFirstChild(REQUIRED_CHILD)
                -- Checks that the box exists, is a BoxHandleAdornment, and is green (visible and enemy)
                if box and box:IsA("BoxHandleAdornment") and box.Color3 == Color3.fromRGB(0, 255, 0) then
                    local targetScreenPosition, onScreen = Camera:WorldToViewportPoint(head.Position) -- Converts 3D position to 2D
                    if onScreen then -- If the head is on the screen
                        local distanceToCenter = (Vector2.new(targetScreenPosition.X, targetScreenPosition.Y) - screenCenter).Magnitude -- Calculates the distance to the center
                        -- If it's within FOV (if enabled) and is the closest so far
                        if (not fovEnabled or distanceToCenter <= fovRadius) and distanceToCenter < minDistance then
                            closestTarget = head -- Updates the closest target
                            minDistance = distanceToCenter -- Updates the minimum distance
                        end
                    end
                end
            end
        end
    end
    return closestTarget -- Returns the closest head found
end

-- Function to aim at a target
local function aimAtTarget(target) -- Renamed 'aimTo'
    local targetScreenPosition = Camera:WorldToViewportPoint(target.Position) -- Target position on the screen
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) -- Screen center
    local delta = targetScreenPosition - Vector3.new(screenCenter.X, screenCenter.Y, targetScreenPosition.Z) -- Difference between the target and the center

    -- If the target is within the deadzone, do not move the mouse
    if math.abs(delta.X) < DEADZONE and math.abs(delta.Y) < DEADZONE then return end

    local smoothingFactor = math.clamp(1 - (smoothing / 100), 0, 1) -- Calculates the smoothing factor (0 to 1)
    if mousemoverel then -- Checks if the 'mousemoverel' function is available (moves mouse relatively)
        -- Moves the mouse, applying smoothing and limiting movement to avoid excessive turns
        mousemoverel(math.clamp(delta.X * smoothingFactor, -25, 25), math.clamp(delta.Y * smoothingFactor, -25, 25))
    end
end

-- Initialization when loading the script
registerExistingNPCs() -- Registers NPCs that already exist in the game
if wallEnabled then -- If Wall is enabled by configuration
    createBoxesForAllNPCs() -- Creates boxes for NPCs
    -- Ensures all tracked NPCs have a box if Wall is active
    for part, _ in pairs(trackedParts) do
        if part and part.Parent and not part:FindFirstChild("Wall_Box") then
            createBoxForPart(part)
        end
    end
end

-- Connection to detect new NPCs added to the Workspace
table.insert(wallConnections, Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child.Name == TARGET_NAME then -- If it's a model with the target name
        task.wait(0.5) -- Waits for the model to load completely
        local head = child:FindFirstChild(TARGET_PART) -- Looks for the head
        if head then
            trackedParts[head] = true -- Adds to the tracked list
            if wallEnabled then createBoxForPart(head) end -- Creates the box if Wall is active
        end
    end
end))

-- Main loop that runs every frame (RenderStepped for visual updates)
local mainRenderLoop -- Renamed 'loop' to 'mainRenderLoop' for the first loop for clarity
mainRenderLoop = RunService.RenderStepped:Connect(function()
    if isUnloaded then return end -- If the script is unloaded, do nothing

    for part, _ in pairs(trackedParts) do
        if part and part.Parent and part:FindFirstChild("Wall_Box") then
            local box = part.Wall_Box
            local cameraPosition = Camera.CFrame.Position -- Camera position
            -- Casts a ray from the camera to the part to check for obstacles
            local raycastResult = Workspace:Raycast(cameraPosition, part.Position - cameraPosition, RaycastParams.new())
            -- It's visible if there's no result (ray didn't hit anything) or if what it hit is a descendant of the same NPC
            local isVisible = not raycastResult or raycastResult.Instance:IsDescendantOf(part.Parent)

            box.Color3 = isVisible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0) -- Green if visible, Red if not
            box.Visible = true -- Keeps the box visible (transparency is handled by the button)
        else
            -- If the part no longer exists or doesn't have Wall_Box, removes it from the tracking table
            trackedParts[part] = nil
        end
    end

    -- Updates the position and visibility of the FOV circle
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Position = screenCenter
    fovCircle.Radius = fovRadius
    fovCircle.Visible = fovEnabled and aimEnabled -- Visible only if FOV and Aim are enabled

    -- Aim logic
    if aimEnabled and holdingRightClick then -- If Aim is enabled and right-click is held
        local target = getClosestValidHead() -- Gets the closest valid target
        if target then aimAtTarget(target) end -- If there's a target, aim at it
    end
end)

-- Variable to control if ally scanning is active
local allyScanActive = false -- Renamed 'scanningActive'

-- Function to start a temporary ally scan (when 'U' is pressed)
local function startTimedAllyScan(duration) -- Renamed 'startTimedScan'
    if allyScanActive then return end -- If a scan is already active, do nothing
    allyScanActive = true
    local scanStartTime = tick() -- Scan start time

    local heartbeatConnection -- Variable to store the Heartbeat connection
    heartbeatConnection = RunService.Heartbeat:Connect(function() -- Executes on every server "heartbeat" (more frequent than RenderStepped)
        if tick() - scanStartTime > duration then -- If the scan duration has passed
            allyScanActive = false -- Disables scanning
            if heartbeatConnection then heartbeatConnection:Disconnect() end -- Check if connection exists before disconnecting
            heartbeatConnection = nil
            return
        end

        -- Iterates over models in Workspace to mark allies
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model.Name == "Male" then -- Assumes initial targets are "Male" (Consider using TARGET_NAME)
                local head = model:FindFirstChild("Head") -- (Consider using TARGET_PART)
                if head then
                    local box = head:FindFirstChild("Wall_Box")
                    -- If the box is green (visible, indicates the player is looking at it)
                    if box and box:IsA("BoxHandleAdornment") and box.Color3 == Color3.fromRGB(0, 255, 0) then
                        box:Destroy() -- Destroys the box (it will no longer be a target)
                        model.Name = "Team" -- Renames the model to mark it as an ally (prevents it from being targeted)
                    end
                end
            end
        end
    end)
end

-- Event to start ally scan when 'U' key is pressed
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.U then
        startTimedAllyScan(3) -- Starts a 3-second scan
    end
end)

-- Trash? 🔽
local secondaryRenderLoop
secondaryRenderLoop = RunService.RenderStepped:Connect(function()
    if isUnloaded then return end
    for part, _ in pairs(trackedParts) do
        if part and part.Parent and part:FindFirstChild("Wall_Box") then
            local box = part.Wall_Box
            if not box.Visible then
                box:Destroy() 
            end
        end
    end
end)

-- Function to hide Wall_Box if the NPC has a specific constraint (could be for ragdolls or specific NPCs)
local function hideWallBoxIfHasConstraint()
    for _, npc in ipairs(Workspace:GetChildren()) do
        if npc:IsA("Model") and npc.Name == "Male" then -- Only for NPCs named "Male" (Should this be TARGET_NAME?)
            local head = npc:FindFirstChild("Head") -- (Should this be TARGET_PART?)
            if head and head:FindFirstChild("Wall_Box") then
                -- If the NPC has a "BallSocketConstraint" (common in ragdolls)
                if npc:FindFirstChildWhichIsA("BallSocketConstraint", true) then -- true for recursive search
                    head.Wall_Box.Visible = false -- Hides the box
                end
            end
        end
    end
end

-- Executes the function once at startup
hideWallBoxIfHasConstraint()

-- Creates a new task (coroutine) to execute hideWallBoxIfHasConstraint periodically
task.spawn(function()
    while not isUnloaded and task.wait(1) do -- Added 'not isUnloaded' to stop when unloaded, and put wait in condition
        hideWallBoxIfHasConstraint()
        -- task.wait(1) -- Waits 1 second between each check (moved to while condition)
    end
end)

-- Ensure unloadBtn disconnects the second loop too if it's active
local originalUnloadClick = unloadBtn.MouseButton1Click -- Store original
unloadBtn.MouseButton1Click:ClearAllConnections() -- Clear existing (if any were added before this point by mistake)
unloadBtn.MouseButton1Click:Connect(function()
    isUnloaded = true 
    destroyAllBoxes() 
    fovCircle:Remove() 
    gui:Destroy() 
    for _, conn in ipairs(wallConnections) do pcall(function() conn:Disconnect() end) end 
    if mainRenderLoop then mainRenderLoop:Disconnect() end
    if secondaryRenderLoop then secondaryRenderLoop:Disconnect() end -- Added disconnection for the second loop
    -- If originalUnloadClick had other logic beyond these disconnections, it's lost.
    -- However, the original script's unloadBtn only did these actions.
end)
