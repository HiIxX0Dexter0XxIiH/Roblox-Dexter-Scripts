local Aim = {
    fovGui = nil,
    fovCircle = nil,
    fovStroke = nil,
    holdingRightClick = false
}

local Players = game:GetService("Players")

-- The FOV circle is drawn with Roblox UI rather than Drawing so it behaves
-- consistently across executors and stays aligned with the viewport center.
local function getPlayerGui()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        return nil
    end

    return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function ensureFOVCircle()
    if Aim.fovCircle then
        return
    end

    local playerGui = getPlayerGui()
    if not playerGui then
        return
    end

    local existing = playerGui:FindFirstChild("BRM5_PVP_FOV_GUI")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BRM5_PVP_FOV_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 100000
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local circle = Instance.new("Frame")
    circle.Name = "BRM5_PVP_FOV"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Visible = false
    circle.ZIndex = 99999
    circle.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 2
    stroke.Parent = circle

    Aim.fovGui = screenGui
    Aim.fovCircle = circle
    Aim.fovStroke = stroke
end

local function getScreenCenter(camera)
    return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

function Aim:setHoldingRightClick(isHeld)
    self.holdingRightClick = isHeld and true or false
end

function Aim:updateFOVCircle(camera, config)
    ensureFOVCircle()
    if not self.fovCircle or not camera then
        return
    end

    -- The circle is a square frame with a full UICorner, so diameter controls
    -- both the visual size and the effective radius shown to the user.
    local radius = math.max(config.fovRadius, 0)
    local diameter = radius * 2
    local screenCenter = getScreenCenter(camera)
    self.fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    self.fovCircle.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
    self.fovCircle.Visible = config.fovEnabled and not config.isUnloaded and radius > 0
end

function Aim:getClosestValidHead(walls, camera, config)
    if not walls or not camera then
        return nil
    end

    local closestTarget, minDistance = nil, math.huge
    local screenCenter = getScreenCenter(camera)

    -- Visibility is derived from the Wall_Box color, so aim only locks to
    -- targets the wall system currently considers visible.
    for head in pairs(walls.trackedHeads) do
        local box = head and head:FindFirstChild(config.REQUIRED_CHILD)
        if head and head.Parent and box and box:IsA("BoxHandleAdornment") and box.Color3 == config.visibleColor then
            local targetPosition, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local distanceToCenter = (Vector2.new(targetPosition.X, targetPosition.Y) - screenCenter).Magnitude
                if (not config.fovEnabled or distanceToCenter <= config.fovRadius) and distanceToCenter < minDistance then
                    closestTarget = head
                    minDistance = distanceToCenter
                end
            end
        end
    end

    return closestTarget
end

function Aim:aimAtTarget(target, camera, config)
    if not target or not camera or type(mousemoverel) ~= "function" then
        return
    end

    local targetPosition = camera:WorldToViewportPoint(target.Position)
    local screenCenter = getScreenCenter(camera)
    local delta = targetPosition - Vector3.new(screenCenter.X, screenCenter.Y, targetPosition.Z)

    if math.abs(delta.X) < config.DEADZONE and math.abs(delta.Y) < config.DEADZONE then
        return
    end

    -- Higher smoothing values intentionally produce smaller mouse deltas.
    local smoothingFactor = math.clamp(1 - (config.smoothing / 100), 0, 1)
    mousemoverel(
        math.clamp(delta.X * smoothingFactor, -25, 25),
        math.clamp(delta.Y * smoothingFactor, -25, 25)
    )
end

function Aim:cleanup()
    if self.fovGui then
        self.fovGui:Destroy()
    end

    if self.fovCircle then
        self.fovCircle = nil
    end
    self.fovGui = nil
    self.fovCircle = nil
    self.fovStroke = nil
    self.holdingRightClick = false
end

return Aim
