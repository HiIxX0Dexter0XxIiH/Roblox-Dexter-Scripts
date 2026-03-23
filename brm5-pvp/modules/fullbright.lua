local Lighting = {}

Lighting.originalLighting = {}
Lighting.fullBrightApplied = false

-- Lighting changes are reversible, so we capture the pre-script values once
-- and reuse them whenever FullBright is disabled or the script unloads.
function Lighting:storeOriginalSettings(lightingService)
    self.originalLighting = {
        Brightness = lightingService.Brightness,
        ClockTime = lightingService.ClockTime,
        FogEnd = lightingService.FogEnd,
        GlobalShadows = lightingService.GlobalShadows,
        Ambient = lightingService.Ambient
    }
end

function Lighting:applyFullBright(lightingService)
    lightingService.Brightness = 2
    lightingService.ClockTime = 12
    lightingService.FogEnd = 100000
    lightingService.GlobalShadows = false
    lightingService.Ambient = Color3.new(1, 1, 1)
    self.fullBrightApplied = true
end

function Lighting:enforceFullBright(lightingService)
    if lightingService.Brightness ~= 2 then
        lightingService.Brightness = 2
    end
    if lightingService.ClockTime ~= 12 then
        lightingService.ClockTime = 12
    end
    if lightingService.FogEnd ~= 100000 then
        lightingService.FogEnd = 100000
    end
    if lightingService.GlobalShadows ~= false then
        lightingService.GlobalShadows = false
    end
    if lightingService.Ambient ~= Color3.new(1, 1, 1) then
        lightingService.Ambient = Color3.new(1, 1, 1)
    end
end

function Lighting:restoreOriginal(lightingService)
    for property, value in pairs(self.originalLighting) do
        lightingService[property] = value
    end
    self.fullBrightApplied = false
end

function Lighting:update(lightingService, config)
    if config.fullBrightEnabled then
        if not self.fullBrightApplied then
            self:applyFullBright(lightingService)
        else
            self:enforceFullBright(lightingService)
        end
        return
    end

    if self.fullBrightApplied then
        self:restoreOriginal(lightingService)
    end
end

return Lighting
