-- Configuration Module
-- Contains all settings, constants, and state variables

local Config = {}
local HttpService = game:GetService("HttpService")

-- CONSTANTS
Config.RAYCAST_COOLDOWN = 0.2
Config.MARKER_MAX_PER_STEP = 12
Config.TARGET_SYNC_INTERVAL = 0.25
Config.NPC_REFRESH_INTERVAL = 0.5
Config.TARGET_BOX_SIZE = Vector3.new(15, 15, 15) -- Size of the adjusted target bounds
Config.MAX_NPC_DETECTION_RADIUS = 3000
Config.npcDetectionRadius = Config.MAX_NPC_DETECTION_RADIUS
Config.CONFIG_FILE = "brm5_pve_config.json"

-- TOGGLES (State)
Config.highlightEnabled = false  -- Visibility markers
Config.sizingEnabled = false     -- Target sizing
Config.showTargetBox = false     -- Shows target bounds
Config.fullBrightEnabled = false -- Removes shadows/darkness
Config.guiVisible = true         -- Menu visibility
Config.isUnloaded = false        -- To stop the script

-- WEAPON PATCHES
Config.patchOptions = { 
    recoil = false, 
    firemodes = false 
}

-- COLORS (RGB: 0 to 255)
Config.visibleR, Config.visibleG, Config.visibleB = 0, 255, 0    -- Green for visible targets
Config.hiddenR, Config.hiddenG, Config.hiddenB = 255, 0, 0       -- Red for occluded targets
Config.visibleColor = Color3.fromRGB(Config.visibleR, Config.visibleG, Config.visibleB)
Config.hiddenColor = Color3.fromRGB(Config.hiddenR, Config.hiddenG, Config.hiddenB)

-- Update color function
function Config:updateVisibleColor(r, g, b)
    if r then self.visibleR = r end
    if g then self.visibleG = g end
    if b then self.visibleB = b end
    self.visibleColor = Color3.fromRGB(self.visibleR, self.visibleG, self.visibleB)
end

function Config:updateHiddenColor(r, g, b)
    if r then self.hiddenR = r end
    if g then self.hiddenG = g end
    if b then self.hiddenB = b end
    self.hiddenColor = Color3.fromRGB(self.hiddenR, self.hiddenG, self.hiddenB)
end

function Config:updateNPCDetectionRadius(value)
    self.npcDetectionRadius = math.clamp(
        math.floor(value or self.npcDetectionRadius),
        0,
        self.MAX_NPC_DETECTION_RADIUS
    )
end

function Config:isNPCDetectionEnabled()
    return self.sizingEnabled or self.showTargetBox or self.highlightEnabled
end

function Config:serialize()
    return {
        highlightEnabled = self.highlightEnabled,
        sizingEnabled = self.sizingEnabled,
        showTargetBox = self.showTargetBox,
        fullBrightEnabled = self.fullBrightEnabled,
        npcDetectionRadius = self.npcDetectionRadius,
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

    if data.highlightEnabled ~= nil then self.highlightEnabled = data.highlightEnabled end
    if data.sizingEnabled ~= nil then self.sizingEnabled = data.sizingEnabled end
    if data.showTargetBox ~= nil then self.showTargetBox = data.showTargetBox end
    if data.fullBrightEnabled ~= nil then self.fullBrightEnabled = data.fullBrightEnabled end
    if type(data.patchOptions) == "table" then
        if data.patchOptions.recoil ~= nil then self.patchOptions.recoil = data.patchOptions.recoil end
        if data.patchOptions.firemodes ~= nil then self.patchOptions.firemodes = data.patchOptions.firemodes end
    end

    self:updateVisibleColor(data.visibleR, data.visibleG, data.visibleB)
    self:updateHiddenColor(data.hiddenR, data.hiddenG, data.hiddenB)
    self:updateNPCDetectionRadius(data.npcDetectionRadius)
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
