local Walls = {
    trackedHeads = {},
    trackedModels = {},
    connections = {},
    pendingModelConnections = {}
}

local function isTargetModel(instance, config)
    return instance and instance:IsA("Model") and instance.Name == config.TARGET_NAME
end

local function disconnectPendingConnection(self, model)
    local connection = self.pendingModelConnections[model]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        self.pendingModelConnections[model] = nil
    end
end

-- Heads are the canonical tracked parts for both ESP coloring and aim target
-- selection, so every public function in this module maintains that set.
function Walls:destroyAllBoxes()
    for head in pairs(self.trackedHeads) do
        if head and head.Parent then
            local box = head:FindFirstChild("Wall_Box")
            if box then
                box:Destroy()
            end
        end
    end
    self.trackedHeads = {}
end

function Walls:untrackHead(head)
    if not head then
        return
    end

    self.trackedHeads[head] = nil
    local box = head:FindFirstChild("Wall_Box")
    if box then
        box:Destroy()
    end
end

function Walls:watchModelForHead(model, config)
    if not isTargetModel(model, config) or self.pendingModelConnections[model] then
        return
    end

    self.pendingModelConnections[model] = model.ChildAdded:Connect(function(child)
        if config.isUnloaded then
            disconnectPendingConnection(self, model)
            return
        end

        if child.Name == config.TARGET_PART and child:IsA("BasePart") then
            self:registerModel(model, config)
            disconnectPendingConnection(self, model)
        end
    end)
end

function Walls:createBoxForHead(head, config)
    if not head or not head:IsA("BasePart") or head.Parent == nil then
        return
    end

    -- Reuse existing adornments so toggling Walls does not constantly rebuild
    -- instances for already tracked targets.
    local existing = head:FindFirstChild("Wall_Box")
    if existing and existing:IsA("BoxHandleAdornment") then
        existing.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
        self.trackedHeads[head] = true
        return
    end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Wall_Box"
    box.Size = head.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Adornee = head
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Color3 = config.hiddenColor
    box.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
    box.Visible = true
    box.Parent = head

    self.trackedHeads[head] = true
end

function Walls:registerModel(model, config)
    if not isTargetModel(model, config) then
        return
    end

    self.trackedModels[model] = true
    local head = model:FindFirstChild(config.TARGET_PART)
    if not head or not head:IsA("BasePart") then
        self:watchModelForHead(model, config)
        return
    end

    disconnectPendingConnection(self, model)
    self.trackedHeads[head] = true
    self:createBoxForHead(head, config)
end

function Walls:refreshTrackedTargets(workspace, config)
    for _, instance in ipairs(workspace:GetDescendants()) do
        if isTargetModel(instance, config) then
            self:registerModel(instance, config)
        end
    end
end

function Walls:setupListener(workspace, config)
    table.insert(self.connections, workspace.DescendantAdded:Connect(function(instance)
        if not isTargetModel(instance, config) then
            return
        end

        self:registerModel(instance, config)
    end))

    table.insert(self.connections, workspace.DescendantRemoving:Connect(function(instance)
        if instance and instance:IsA("BasePart") and self.trackedHeads[instance] then
            self:untrackHead(instance)
            return
        end

        if instance and instance:IsA("Model") and self.trackedModels[instance] then
            disconnectPendingConnection(self, instance)
            self.trackedModels[instance] = nil
        end
    end))
end

function Walls:setWallEnabled(enabled, config)
    config.wallEnabled = enabled

    for head in pairs(self.trackedHeads) do
        if head and head.Parent then
            local box = head:FindFirstChild("Wall_Box")
            if box then
                box.Transparency = enabled and config.BOX_TRANSPARENCY or 1
            end
        else
            self.trackedHeads[head] = nil
        end
    end
end

function Walls:updateColors(camera, workspace, localPlayer, config)
    if not camera then
        return
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {}
    if localPlayer and localPlayer.Character then
        table.insert(raycastParams.FilterDescendantsInstances, localPlayer.Character)
    end

    -- Colors are refreshed by raycasting from the camera to each tracked head.
    -- The box stays hidden for ragdolled/dead models that expose constraints.
    local cameraPosition = camera.CFrame.Position
    for head in pairs(self.trackedHeads) do
        if not head or not head.Parent or not head:IsDescendantOf(workspace) then
            self.trackedHeads[head] = nil
        else
            local model = head.Parent
            if model:FindFirstChildWhichIsA("BallSocketConstraint", true) then
                local hiddenBox = head:FindFirstChild("Wall_Box")
                if hiddenBox then
                    hiddenBox.Visible = false
                end
            else
                local box = head:FindFirstChild("Wall_Box")
                if not box then
                    self:createBoxForHead(head, config)
                    box = head:FindFirstChild("Wall_Box")
                end

                if box then
                    local result = workspace:Raycast(cameraPosition, head.Position - cameraPosition, raycastParams)
                    local isVisible = not result or result.Instance:IsDescendantOf(model)
                    box.Visible = true
                    box.Color3 = isVisible and config.visibleColor or config.hiddenColor
                    box.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
                end
            end
        end
    end
end

function Walls:cleanup()
    for _, connection in ipairs(self.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.connections = {}
    for model in pairs(self.pendingModelConnections) do
        disconnectPendingConnection(self, model)
    end
    self.trackedModels = {}
    self:destroyAllBoxes()
end

return Walls
