local Config = {}
local HttpService = game:GetService("HttpService")

-- Centralized runtime state and persisted settings for the PVP script.
Config.CONFIG_FILE = "brm5_pvp_config.json"

Config.TARGET_NAME = "Male"
Config.TARGET_PART = "Head"
Config.REQUIRED_CHILD = "Wall_Box"
Config.DEADZONE = 1.5
Config.ALLY_SCAN_DURATION = 3
Config.ALLY_SCAN_CHECK_INTERVAL = 0.5
Config.BOX_TRANSPARENCY = 0.3
Config.TARGET_REFRESH_INTERVAL = 0.75
Config.COLOR_UPDATE_INTERVAL = 0.08
Config.MAX_FOV_RADIUS = 500
Config.MAX_SMOOTHING = 100

Config.guiVisible = true
Config.isUnloaded = false
Config.wallEnabled = false
Config.aimEnabled = false
Config.fovEnabled = false
Config.fullBrightEnabled = false
Config.fovRadius = 100
Config.smoothing = 95

Config.patchOptions = {
    recoil = false,
    firemodes = false
}

Config.visibleR, Config.visibleG, Config.visibleB = 0, 255, 0
Config.hiddenR, Config.hiddenG, Config.hiddenB = 255, 0, 0
Config.visibleColor = Color3.fromRGB(Config.visibleR, Config.visibleG, Config.visibleB)
Config.hiddenColor = Color3.fromRGB(Config.hiddenR, Config.hiddenG, Config.hiddenB)

function Config:updateVisibleColor(r, g, b)
    if r ~= nil then self.visibleR = math.clamp(math.floor(r), 0, 255) end
    if g ~= nil then self.visibleG = math.clamp(math.floor(g), 0, 255) end
    if b ~= nil then self.visibleB = math.clamp(math.floor(b), 0, 255) end
    self.visibleColor = Color3.fromRGB(self.visibleR, self.visibleG, self.visibleB)
end

function Config:updateHiddenColor(r, g, b)
    if r ~= nil then self.hiddenR = math.clamp(math.floor(r), 0, 255) end
    if g ~= nil then self.hiddenG = math.clamp(math.floor(g), 0, 255) end
    if b ~= nil then self.hiddenB = math.clamp(math.floor(b), 0, 255) end
    self.hiddenColor = Color3.fromRGB(self.hiddenR, self.hiddenG, self.hiddenB)
end

function Config:updateFOVRadius(value)
    self.fovRadius = math.clamp(math.floor(value or self.fovRadius), 0, self.MAX_FOV_RADIUS)
end

function Config:updateSmoothing(value)
    self.smoothing = math.clamp(math.floor(value or self.smoothing), 0, self.MAX_SMOOTHING)
end

function Config:serialize()
    -- Only persist user-facing settings. Transient runtime state stays in
    -- memory so unloading/reloading starts from a clean execution state.
    return {
        wallEnabled = self.wallEnabled,
        aimEnabled = self.aimEnabled,
        fovEnabled = self.fovEnabled,
        fullBrightEnabled = self.fullBrightEnabled,
        fovRadius = self.fovRadius,
        smoothing = self.smoothing,
        patchOptions = {
            recoil = self.patchOptions.recoil,
            firemodes = self.patchOptions.firemodes
        },
        visibleR = self.visibleR,
        visibleG = self.visibleG,
        visibleB = self.visibleB,
        hiddenR = self.hiddenR,
        hiddenG = self.hiddenG,
        hiddenB = self.hiddenB
    }
end

function Config:applySavedData(data)
    if type(data) ~= "table" then
        return
    end

    if data.wallEnabled ~= nil then self.wallEnabled = data.wallEnabled end
    if data.aimEnabled ~= nil then self.aimEnabled = data.aimEnabled end
    if data.fovEnabled ~= nil then self.fovEnabled = data.fovEnabled end
    if data.fullBrightEnabled ~= nil then self.fullBrightEnabled = data.fullBrightEnabled end
    if type(data.patchOptions) == "table" then
        if data.patchOptions.recoil ~= nil then
            self.patchOptions.recoil = data.patchOptions.recoil
        end
        if data.patchOptions.firemodes ~= nil then
            self.patchOptions.firemodes = data.patchOptions.firemodes
        end
    end

    self:updateFOVRadius(data.fovRadius)
    self:updateSmoothing(data.smoothing)
    self:updateVisibleColor(data.visibleR, data.visibleG, data.visibleB)
    self:updateHiddenColor(data.hiddenR, data.hiddenG, data.hiddenB)
end

function Config:save()
    if type(writefile) ~= "function" then
        return false
    end

    local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, self:serialize())
    if not okEncode then
        return false
    end

    local okWrite = pcall(writefile, self.CONFIG_FILE, encoded)
    return okWrite
end

function Config:load()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(self.CONFIG_FILE) then
        return false
    end

    local okRead, raw = pcall(readfile, self.CONFIG_FILE)
    if not okRead or type(raw) ~= "string" or raw == "" then
        return false
    end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode then
        return false
    end

    self:applySavedData(data)
    return true
end

return Config
