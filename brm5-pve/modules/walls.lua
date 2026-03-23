
local Markers = {}

Markers.trackedParts = {} -- List of body parts we are watching
Markers.enabled = false
Markers.boxTransparency = 0.3

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

    local processed = 0
    local maxPerStep = config.MARKER_MAX_PER_STEP or 12
    local origin = camera.CFrame.Position
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances = character and {character} or {}

    for model, data in pairs(npcManager:getActiveNPCs()) do
        if processed >= maxPerStep then
            break
        end
        if data.head and data.head:FindFirstChild("Marker_Box") then
            local result = workspace:Raycast(origin, data.head.Position - origin, rp)
            local isVisible = (not result or result.Instance:IsDescendantOf(model))
            data.head.Marker_Box.Color3 = isVisible
                and config.visibleColor
                or config.hiddenColor
            data.head.Marker_Box.Transparency = Markers.boxTransparency
            processed = processed + 1
        end
    end
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
