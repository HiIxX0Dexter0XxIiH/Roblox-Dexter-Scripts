local AllyScan = {
    active = false,
    connection = nil,
    monitorConnection = nil,
    handledRoundModel = nil,
    monitorAccumulator = 0
}

-- The round monitor watches the first-person WorldModel so ally scanning can
-- restart automatically at the beginning of each round.
local function getCameraWorldModel(services)
    local camera = services.Workspace.CurrentCamera or services.camera
    if not camera then
        return nil
    end

    return camera:FindFirstChild("WorldModel")
end

local function getRoundModelCandidates(services)
    local worldModel = getCameraWorldModel(services)
    if not worldModel then
        return nil, nil
    end

    return worldModel:FindFirstChild("Model"), worldModel:FindFirstChild("Me")
end

function AllyScan:start(duration, services, walls, config)
    if self.active then
        return false
    end

    self.active = true
    local startedAt = tick()

    self.connection = services.RunService.Heartbeat:Connect(function()
        if config.isUnloaded then
            self:stop()
            return
        end

        if tick() - startedAt > duration then
            self:stop()
            return
        end

        -- Allies are inferred from currently visible targets during the short
        -- scan window, then renamed so the wall tracker ignores them.
        for _, model in ipairs(services.Workspace:GetDescendants()) do
            if model:IsA("Model") and model.Name == config.TARGET_NAME then
                local head = model:FindFirstChild(config.TARGET_PART)
                local box = head and head:FindFirstChild(config.REQUIRED_CHILD)
                if box and box:IsA("BoxHandleAdornment") and box.Color3 == config.visibleColor then
                    walls:untrackHead(head)
                    model.Name = "Team"
                end
            end
        end
    end)

    return true
end

function AllyScan:startRoundMonitor(services, walls, config)
    if self.monitorConnection then
        return false
    end

    self.monitorAccumulator = 0
    self.handledRoundModel = nil

    self.monitorConnection = services.RunService.Heartbeat:Connect(function(dt)
        if config.isUnloaded then
            self:stopRoundMonitor()
            return
        end

        self.monitorAccumulator = self.monitorAccumulator + dt
        if self.monitorAccumulator < (config.ALLY_SCAN_CHECK_INTERVAL or 0.5) then
            return
        end
        self.monitorAccumulator = 0

        -- A fresh "Model" under WorldModel means a new round viewmodel is
        -- ready, so we rename it once and trigger a single ally scan.
        local modelCandidate, meCandidate = getRoundModelCandidates(services)
        local activeRoundModel = modelCandidate or meCandidate

        if self.handledRoundModel and not self.handledRoundModel.Parent then
            self.handledRoundModel = nil
        end

        if not activeRoundModel then
            self.handledRoundModel = nil
            return
        end

        if activeRoundModel == self.handledRoundModel then
            return
        end

        if modelCandidate and modelCandidate.Name == "Model" then
            pcall(function()
                modelCandidate.Name = "Me"
            end)
            activeRoundModel = modelCandidate
        end

        self.handledRoundModel = activeRoundModel
        self:start(config.ALLY_SCAN_DURATION, services, walls, config)
    end)

    return true
end

function AllyScan:stopRoundMonitor()
    if self.monitorConnection then
        pcall(function()
            self.monitorConnection:Disconnect()
        end)
    end
    self.monitorConnection = nil
    self.handledRoundModel = nil
    self.monitorAccumulator = 0
end

function AllyScan:stop()
    self.active = false
    if self.connection then
        pcall(function()
            self.connection:Disconnect()
        end)
    end
    self.connection = nil
end

return AllyScan
