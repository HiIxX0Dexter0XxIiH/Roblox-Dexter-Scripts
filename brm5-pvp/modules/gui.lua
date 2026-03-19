local GUI = {}

GUI.screenGui = nil
GUI.mainFrame = nil
GUI.modalOverlay = nil
GUI.cursorIndicator = nil
GUI.toggleButton = nil
GUI.tabButtons = {}
GUI.tabs = {}

local function createTab(container)
    local frame = Instance.new("ScrollingFrame", container)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.ScrollBarThickness = 2
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    return frame
end

local function createToggleButton(parent, text, initialActive, callback)
    local button = Instance.new("TextButton", parent)
    button.Size = UDim2.new(1, -10, 0, 35)
    button.BackgroundColor3 = initialActive and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(35, 35, 35)
    button.Text = text
    button.TextColor3 = initialActive and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
    button.Font = "Gotham"
    button.TextSize = 13
    Instance.new("UICorner", button)

    local active = initialActive and true or false
    button.MouseButton1Click:Connect(function()
        active = not active
        button.BackgroundColor3 = active and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(35, 35, 35)
        button.TextColor3 = active and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
        callback(active)
    end)
end

local function createActionButton(parent, text, accentColor, callback)
    local button = Instance.new("TextButton", parent)
    button.Size = UDim2.new(1, -10, 0, 35)
    button.BackgroundColor3 = accentColor
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = "GothamBold"
    button.TextSize = 13
    Instance.new("UICorner", button)
    button.MouseButton1Click:Connect(callback)
end

local function updateToggleButtonText(button, isVisible)
    if button then
        button.Text = isVisible and "Hide GUI" or "Open GUI"
    end
end

local function createLabel(parent, text, color, size, layoutIndex)
    local label = Instance.new("TextLabel", parent)
    label.Size = UDim2.new(1, -10, 0, size or 30)
    label.Text = text
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.Font = "GothamBold"
    label.TextSize = 13
    label.BackgroundTransparency = 1
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    if layoutIndex then
        label.LayoutOrder = layoutIndex
    end
    return label
end

local function createInfoLabel(parent, text, height)
    local label = Instance.new("TextLabel", parent)
    label.Size = UDim2.new(1, -10, 0, height or 74)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(185, 185, 185)
    label.Font = "Gotham"
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.BackgroundTransparency = 1
    return label
end

local function createSlider(parent, label, initialValue, maxValue, callback, layoutIndex, services)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 50)
    frame.BackgroundTransparency = 1
    if layoutIndex then
        frame.LayoutOrder = layoutIndex
    end

    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Text = label .. ": " .. initialValue
    valueLabel.Size = UDim2.new(1, 0, 0, 20)
    valueLabel.TextColor3 = Color3.new(1, 1, 1)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left

    local bar = Instance.new("Frame", frame)
    bar.Position = UDim2.new(0, 0, 0, 25)
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(maxValue > 0 and (initialValue / maxValue) or 0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)

    local dragging = false

    local function update()
        local mouseX = services.UserInputService:GetMouseLocation().X
        local position = math.clamp((mouseX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(position * maxValue + 0.5)
        fill.Size = UDim2.new(position, 0, 1, 0)
        valueLabel.Text = label .. ": " .. value
        callback(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update()
        end
    end)

    services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    services.RunService.RenderStepped:Connect(function()
        if dragging then
            update()
        end
    end)
end

function GUI:init(services, config, callbacks)
    local localPlayer = services.localPlayer
    local playerMouse = localPlayer:GetMouse()

    -- The modal overlay and custom cursor make the menu usable even while the
    -- script temporarily releases the game's mouse lock.
    self.screenGui = Instance.new("ScreenGui", localPlayer.PlayerGui)
    self.screenGui.Name = "BRM5_PVP_Modular"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.DisplayOrder = 9999
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local modalOverlay = Instance.new("TextButton", self.screenGui)
    modalOverlay.Name = "ModalOverlay"
    modalOverlay.Size = UDim2.fromScale(1, 1)
    modalOverlay.BackgroundTransparency = 1
    modalOverlay.BorderSizePixel = 0
    modalOverlay.Text = ""
    modalOverlay.AutoButtonColor = false
    modalOverlay.Modal = true
    modalOverlay.Active = true
    modalOverlay.Visible = config.guiVisible
    self.modalOverlay = modalOverlay

    local cursorIndicator = Instance.new("Frame", self.screenGui)
    cursorIndicator.Name = "CursorIndicator"
    cursorIndicator.Size = UDim2.fromOffset(10, 10)
    cursorIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
    cursorIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    cursorIndicator.BorderSizePixel = 0
    cursorIndicator.Visible = config.guiVisible
    cursorIndicator.ZIndex = 100
    Instance.new("UICorner", cursorIndicator).CornerRadius = UDim.new(1, 0)
    self.cursorIndicator = cursorIndicator

    local cursorStroke = Instance.new("UIStroke", cursorIndicator)
    cursorStroke.Color = Color3.fromRGB(0, 0, 0)
    cursorStroke.Thickness = 1.5

    local toggleButton = Instance.new("TextButton", self.screenGui)
    toggleButton.Name = "GuiToggleButton"
    toggleButton.Size = UDim2.fromOffset(110, 36)
    toggleButton.Position = UDim2.new(0, 20, 0.5, -18)
    toggleButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    toggleButton.BorderSizePixel = 0
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = "GothamBold"
    toggleButton.TextSize = 13
    toggleButton.ZIndex = 101
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)
    self.toggleButton = toggleButton
    updateToggleButtonText(toggleButton, config.guiVisible)

    toggleButton.MouseButton1Click:Connect(function()
        if callbacks.onVisibilityToggle then
            callbacks.onVisibilityToggle()
        else
            self:toggleVisibility()
        end
    end)

    local main = Instance.new("Frame", self.screenGui)
    main.Size = UDim2.new(0, 500, 0, 350)
    main.Position = UDim2.new(0.5, -250, 0.5, -175)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    main.Active = true
    main.Visible = config.guiVisible
    main.ZIndex = 1
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
    self.mainFrame = main

    -- Dragging logic is kept local to the frame so the module can rebuild the
    -- GUI cleanly after unload/reload without shared state.
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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    services.RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            updateDrag(dragInput)
        end

        if self.cursorIndicator then
            self.cursorIndicator.Position = UDim2.fromOffset(playerMouse.X, playerMouse.Y)
        end
    end)

    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "BRM5 v7.0 🎇 PVP"
    title.Font = "GothamBold"
    title.TextColor3 = Color3.fromRGB(85, 170, 255)
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1

    local sidebar = Instance.new("Frame", main)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.Size = UDim2.new(0, 130, 1, -40)
    sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    sidebar.BorderSizePixel = 0

    local sideLayout = Instance.new("UIListLayout", sidebar)
    sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sideLayout.Padding = UDim.new(0, 8)

    local container = Instance.new("Frame", main)
    container.Position = UDim2.new(0, 140, 0, 50)
    container.Size = UDim2.new(1, -150, 1, -60)
    container.BackgroundTransparency = 1

    local tabCombat = createTab(container)
    local tabVisuals = createTab(container)
    local tabWeapons = createTab(container)
    local tabColors = createTab(container)
    local tabCredits = createTab(container)
    tabCombat.Visible = true

    self.tabs = {
        combat = tabCombat,
        visuals = tabVisuals,
        weapons = tabWeapons,
        colors = tabColors,
        credits = tabCredits
    }

    local function addTabButton(name, targetTab)
        local button = Instance.new("TextButton", sidebar)
        button.Size = UDim2.new(1, -20, 0, 35)
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        button.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        button.Font = "GothamMedium"
        button.TextSize = 13
        button.Text = name
        Instance.new("UICorner", button)

        self.tabButtons[name] = button
        if name == "Combat" then
            button.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
            button.TextColor3 = Color3.new(0, 0, 0)
        end

        button.MouseButton1Click:Connect(function()
            for _, tabButton in pairs(self.tabButtons) do
                tabButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                tabButton.TextColor3 = Color3.new(0.8, 0.8, 0.8)
            end

            button.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
            button.TextColor3 = Color3.new(0, 0, 0)

            for _, tab in pairs(self.tabs) do
                tab.Visible = false
            end
            targetTab.Visible = true
        end)
    end

    addTabButton("Combat", tabCombat)
    addTabButton("Visuals", tabVisuals)
    addTabButton("Weapons", tabWeapons)
    addTabButton("Colors", tabColors)
    addTabButton("Credits and Help", tabCredits)

    -- Tabs are intentionally thin: they only call the callbacks owned by
    -- main.lua so game logic stays outside the UI layer.
    createToggleButton(tabCombat, "Aim", config.aimEnabled, callbacks.onAimToggle)
    createToggleButton(tabCombat, "FOV", config.fovEnabled, callbacks.onFOVToggle)
    createSlider(tabCombat, "FOV Radius", config.fovRadius, config.MAX_FOV_RADIUS, callbacks.onFOVRadiusChange, nil, services)
    createSlider(tabCombat, "Smoothing", config.smoothing, config.MAX_SMOOTHING, callbacks.onSmoothingChange, nil, services)
    createActionButton(tabCombat, "Scan Allies (3s)", Color3.fromRGB(65, 125, 85), callbacks.onScanAllies)
    createInfoLabel(
        tabCombat,
        "At the start of each round, press U and look at your teammates for a few seconds so they get marked as allies and stop appearing on WALL and AIM.",
        92
    )

    createToggleButton(tabVisuals, "Walls", config.wallEnabled, callbacks.onWallToggle)
    createToggleButton(tabVisuals, "FullBright", config.fullBrightEnabled, callbacks.onFullBrightToggle)
    createInfoLabel(
        tabVisuals,
        "Walls keeps the enemy detection boxes updated even when hidden, so AIM can keep using them correctly.",
        58
    )

    createLabel(tabWeapons, "Reset character to apply changes", Color3.fromRGB(255, 100, 100))
    createToggleButton(tabWeapons, "No recoil", config.patchOptions.recoil, callbacks.onNoRecoilToggle)
    createToggleButton(tabWeapons, "All Firemodes", config.patchOptions.firemodes, callbacks.onFiremodeToggle)

    local layoutIndex = 1
    createLabel(tabColors, "-- VISIBLE COLOR --", Color3.new(0.5, 1, 0.5), 24, layoutIndex)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "R", config.visibleR, 255, callbacks.onVisibleRChange, layoutIndex, services)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "G", config.visibleG, 255, callbacks.onVisibleGChange, layoutIndex, services)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "B", config.visibleB, 255, callbacks.onVisibleBChange, layoutIndex, services)
    layoutIndex = layoutIndex + 1

    createLabel(tabColors, "-- HIDDEN COLOR --", Color3.new(1, 0.5, 0.5), 24, layoutIndex)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "R", config.hiddenR, 255, callbacks.onHiddenRChange, layoutIndex, services)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "G", config.hiddenG, 255, callbacks.onHiddenGChange, layoutIndex, services)
    layoutIndex = layoutIndex + 1
    createSlider(tabColors, "B", config.hiddenB, 255, callbacks.onHiddenBChange, layoutIndex, services)

    local function addCredit(text, font, size)
        local label = Instance.new("TextLabel", tabCredits)
        label.Size = UDim2.new(1, -10, 0, size or 50)
        label.Text = text
        label.TextColor3 = Color3.new(0.9, 0.9, 0.9)
        label.Font = font or "Gotham"
        label.TextSize = 12
        label.TextWrapped = true
        label.BackgroundTransparency = 1
    end

    local clipboardStatus = createInfoLabel(tabCredits, "Click a link to copy it to the clipboard.", 40)
    clipboardStatus.TextColor3 = Color3.fromRGB(140, 200, 255)

    local function copyToClipboard(text, label)
        if type(setclipboard) == "function" then
            local ok = pcall(setclipboard, text)
            if ok then
                clipboardStatus.Text = "Copied to clipboard: " .. label
                return
            end
        end
        clipboardStatus.Text = "Clipboard is not available in this executor."
    end

    local function addLinkButton(label, url, accentColor)
        local button = Instance.new("TextButton", tabCredits)
        button.Size = UDim2.new(1, -10, 0, 44)
        button.BackgroundColor3 = accentColor
        button.Text = label
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = "GothamBold"
        button.TextSize = 13
        button.AutoButtonColor = true
        Instance.new("UICorner", button)

        button.MouseButton1Click:Connect(function()
            copyToClipboard(url, label)
        end)

        local urlLabel = Instance.new("TextLabel", button)
        urlLabel.Size = UDim2.new(1, -16, 0, 16)
        urlLabel.Position = UDim2.new(0, 8, 1, -18)
        urlLabel.BackgroundTransparency = 1
        urlLabel.Text = url
        urlLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
        urlLabel.Font = "Gotham"
        urlLabel.TextSize = 10
    end

    addCredit("Credits and Help", "GothamBold", 28)
    addCredit("Made by: HiIxX0Dexter0XxIiH", "GothamBold", 24)
    addLinkButton("GitHub", "https://github.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts", Color3.fromRGB(45, 95, 160))
    addLinkButton("Reddit", "https://www.reddit.com/r/BRM5Scripts/", Color3.fromRGB(185, 75, 45))

    local unloadButton = Instance.new("TextButton", sidebar)
    unloadButton.Size = UDim2.new(0, 110, 0, 35)
    unloadButton.AnchorPoint = Vector2.new(0.5, 0)
    unloadButton.Position = UDim2.new(0.5, 0, 0, 0)
    unloadButton.Text = "Unload Script"
    unloadButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    unloadButton.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", unloadButton)
    unloadButton.MouseButton1Click:Connect(callbacks.onUnload)
end

function GUI:setVisibleState(isVisible)
    if self.mainFrame then
        self.mainFrame.Visible = isVisible
    end
    if self.modalOverlay then
        self.modalOverlay.Visible = isVisible
    end
    if self.cursorIndicator then
        self.cursorIndicator.Visible = isVisible
    end
    updateToggleButtonText(self.toggleButton, isVisible)
    return isVisible
end

function GUI:toggleVisibility()
    if self.mainFrame then
        return self:setVisibleState(not self.mainFrame.Visible)
    end
    return false
end

function GUI:destroy()
    if self.screenGui then
        self.screenGui:Destroy()
    end

    self.screenGui = nil
    self.mainFrame = nil
    self.modalOverlay = nil
    self.cursorIndicator = nil
    self.toggleButton = nil
    self.tabButtons = {}
    self.tabs = {}
end

return GUI
