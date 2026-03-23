
local Markers = {}

Markers.trackedParts = {} -- List of body parts we are watching
Markers.enabled = false
Markers.boxTransparency = 0.3
Markers._updateCursor = 1

local function hasBallSocketConstraint(model)
    return model and model:FindFirstChildWhichIsA("BallSocketConstraint", true) ~= nil
end

local function collectActiveNPCModels(npcManager)
    local models = {}
    for model, _ in pairs(npcManager:getActiveNPCs()) do
        table.insert(models, model)
    end
    return models
end

local function ensureBox(part, color)
    local box = part:FindFirstChild("Marker_Box")
    if box then
        box.Color3 = color
        return box
    end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Marker_Box"
    box.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = color
    box.Transparency = Markers.boxTransparency
    box.Parent = part

    return box
end

function Markers.createBoxForPart(part, config)
    if not part then
        return
    end

    ensureBox(part, (config and config.visibleColor) or Color3.fromRGB(0, 255, 0))
    Markers.trackedParts[part] = true
end

function Markers.destroyBoxForPart(part)
    if not part then
        return
    end

    local box = part:FindFirstChild("Marker_Box")
    if box then
        pcall(function() box:Destroy() end)
    end
    Markers.trackedParts[part] = nil
end

-- Removes all marker boxes
function Markers.destroyAllBoxes()
    for part, _ in pairs(Markers.trackedParts) do
        if part then
            local box = part:FindFirstChild("Marker_Box")
            if box then
                pcall(function() box:Destroy() end)
            end
        end
    end
    Markers.trackedParts = {}
end

-- Updates marker colors based on line of sight
function Markers.updateColors(npcManager, camera, workspace, localPlayer, config)
    if not Markers.enabled then 
        return 
    end
    camera = camera or (workspace and workspace.CurrentCamera)
    if not camera or not localPlayer then
        return
    end
    local character = localPlayer.Character
    if not character and camera.CameraSubject then
        character = camera.CameraSubject:FindFirstAncestorOfClass("Model")
    end

    local maxPerStep = config.MARKER_MAX_PER_STEP or 12
    local origin = camera.CFrame.Position
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances = character and {character} or {}

    local models = collectActiveNPCModels(npcManager)
    local total = #models
    if total == 0 then
        Markers._updateCursor = 1
        return
    end

    local toProcess = math.min(maxPerStep, total)
    local startIndex = Markers._updateCursor
    if startIndex < 1 or startIndex > total then
        startIndex = 1
    end

    for offset = 0, toProcess - 1 do
        local index = ((startIndex - 1 + offset) % total) + 1
        local model = models[index]
        local data = npcManager:getActiveNPCs()[model]

        if data and data.head and data.head.Parent then
            if hasBallSocketConstraint(model) then
                Markers.destroyBoxForPart(data.head)
            else
                local box = data.head:FindFirstChild("Marker_Box")
                if box then
                    local result = workspace:Raycast(origin, data.head.Position - origin, rp)
                    local isVisible = (not result or result.Instance:IsDescendantOf(model))
                    box.Color3 = isVisible and config.visibleColor or config.hiddenColor
                    box.Transparency = Markers.boxTransparency
                end
            end
        end
    end

    Markers._updateCursor = ((startIndex - 1 + toProcess) % total) + 1
end

-- Enables visibility markers
function Markers.enable(npcManager, config)
    Markers.enabled = true
    for _, data in pairs(npcManager:getActiveNPCs()) do 
        Markers.createBoxForPart(data.head, config) 
    end
end

-- Disables visibility markers
function Markers.disable()
    Markers.enabled = false
    Markers.destroyAllBoxes()
end

-- Check if markers are enabled
function Markers.isEnabled()
    return Markers.enabled
end

return Markers
