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
        end
        return
    end

    if self.fullBrightApplied then
        self:restoreOriginal(lightingService)
    end
end

return Lighting
