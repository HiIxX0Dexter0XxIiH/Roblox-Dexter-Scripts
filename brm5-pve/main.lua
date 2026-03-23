-- BRM5 v7.0 by dexter 
-- Credits to ryknuq and their overvoltage script, which helped me understand how to integrate the Aim into my script. Without their script, I don't think I could have done this.
-- Coordinates all modules

if typeof(clear) == "function" then
    clear()
end

local function resolveBranch()
    local env = _G
    if typeof(getgenv) == "function" then
        env = getgenv()
    end

    local branch = env and env.BRM5_BRANCH
    if type(branch) == "string" and branch ~= "" then
        return branch
    end

    return "main"
end

local MAIN_VERSION = "cache-bust-2026-03-23-06"
local GITHUB_BASE = "https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/" .. resolveBranch() .. "/brm5-pve/modules/"
local CACHE_BUSTER = MAIN_VERSION .. "-" .. tostring(os.time())

local function loadModule(moduleName)
    local url = GITHUB_BASE .. moduleName .. ".lua?v=" .. CACHE_BUSTER

    local okResponse, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not okResponse then
        warn("Failed to download module: " .. moduleName)
        warn("URL: " .. url)
        warn("HttpGet error: " .. tostring(response))
        return nil
    end

    if type(response) ~= "string" or response == "" then
        warn("Module download returned empty content: " .. moduleName)
        warn("URL: " .. url)
        return nil
    end

    local chunk, compileError = loadstring(response)
    if not chunk then
        warn("Failed to compile module: " .. moduleName)
        warn("URL: " .. url)
        warn("Compile error: " .. tostring(compileError))
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        warn("Failed to execute module: " .. moduleName)
        warn("URL: " .. url)
        warn("Runtime error: " .. tostring(result))
        return nil
    end

    return result
end

local Services = loadModule("services")
local Config = loadModule("config")
local NPCManager = loadModule("npc_manager")
local TargetSizing = loadModule("silent")
local Markers = loadModule("walls")
local Lighting = loadModule("fullbright")
local Weapons = loadModule("norecoil")
local GUI = loadModule("gui")

if not (Services and Config and NPCManager and TargetSizing and Markers and Lighting and Weapons and GUI) then
    error("Failed to load one or more modules. Please verify the remote module files.")
end

Config:load()
Lighting:storeOriginalSettings(Services.Lighting)

local runtimeConnections = {}

local function saveConfig()
    Config:save()
end

local function syncMouseState()
    if Config.guiVisible then
        Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        Services.UserInputService.MouseIconEnabled = true
    end
end

local function forceMouseLock()
    Services.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    Services.UserInputService.MouseIconEnabled = false
end

local function toggleGUIVisibility()
    local wasVisible = Config.guiVisible
    Config.guiVisible = GUI:toggleVisibility()
    if Config.guiVisible then
        syncMouseState()
    elseif wasVisible then
        forceMouseLock()
    end
    return Config.guiVisible
end

local function disconnectRuntimeConnections()
    for _, connection in ipairs(runtimeConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    runtimeConnections = {}
end

local callbacks = {
    onSizingToggle = function(enabled)
        Config.sizingEnabled = enabled
        if not enabled then
            TargetSizing:cleanup(NPCManager)
        end
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onShowTargetBoxToggle = function(enabled)
        Config.showTargetBox = enabled
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onHighlightsToggle = function(enabled)
        Config.highlightEnabled = enabled
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        if enabled then
            Markers.enable(NPCManager, Config)
        else
            Markers.disable()
        end
        saveConfig()
    end,

    onFullBrightToggle = function(enabled)
        Config.fullBrightEnabled = enabled
        if not enabled then
            Lighting:restoreOriginal(Services.Lighting)
        end
        saveConfig()
    end,

    onStabilityToggle = function(enabled)
        Config.patchOptions.recoil = enabled
        Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
        saveConfig()
    end,

    onFiremodeOptionsToggle = function(enabled)
        Config.patchOptions.firemodes = enabled
        Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
        saveConfig()
    end,

    onVisibleRChange = function(value)
        Config:updateVisibleColor(value, nil, nil)
        saveConfig()
    end,

    onVisibleGChange = function(value)
        Config:updateVisibleColor(nil, value, nil)
        saveConfig()
    end,

    onVisibleBChange = function(value)
        Config:updateVisibleColor(nil, nil, value)
        saveConfig()
    end,

    onHiddenRChange = function(value)
        Config:updateHiddenColor(value, nil, nil)
        saveConfig()
    end,

    onHiddenGChange = function(value)
        Config:updateHiddenColor(nil, value, nil)
        saveConfig()
    end,

    onHiddenBChange = function(value)
        Config:updateHiddenColor(nil, nil, value)
        saveConfig()
    end,

    onNPCDetectionRadiusChange = function(value)
        Config:updateNPCDetectionRadius(value)
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onVisibilityToggle = function()
        toggleGUIVisibility()
    end,

    onUnload = function()
        if Config.isUnloaded then
            return
        end

        Config.isUnloaded = true
        disconnectRuntimeConnections()
        Markers.disable()
        TargetSizing:cleanup(NPCManager)
        NPCManager:cleanup()
        Lighting:restoreOriginal(Services.Lighting)
        Config.guiVisible = false
        saveConfig()
        forceMouseLock()
        GUI:destroy()
    end
}

GUI:init(Services, Config, callbacks)
syncMouseState()

NPCManager:scanWorkspace(Services.Workspace, Markers, Config)
NPCManager:setupListener(Services.Workspace, Markers, Config)
if Config.highlightEnabled then
    Markers.enable(NPCManager, Config)
end
if Config.patchOptions.recoil or Config.patchOptions.firemodes then
    Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
end

local markerAccumulator = 0
local targetAccumulator = 0
local npcAccumulator = 0

table.insert(runtimeConnections, Services.RunService.Heartbeat:Connect(function(dt)
    if Config.isUnloaded then
        return
    end

    if Config.guiVisible then
        syncMouseState()
    end
    Lighting:update(Services.Lighting, Config)

    npcAccumulator = npcAccumulator + dt
    if npcAccumulator >= Config.NPC_REFRESH_INTERVAL then
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        npcAccumulator = 0
    end

    markerAccumulator = markerAccumulator + dt
    if markerAccumulator >= Config.RAYCAST_COOLDOWN then
        local okMarkers, markerError = pcall(
            Markers.updateColors,
            NPCManager,
            Services.Workspace.CurrentCamera or Services.camera,
            Services.Workspace,
            Services.localPlayer,
            Config
        )
        if not okMarkers then
            warn("Markers.updateColors failed: " .. tostring(markerError))
        end
        markerAccumulator = 0
    end

    targetAccumulator = targetAccumulator + dt
    if targetAccumulator >= Config.TARGET_SYNC_INTERVAL then
        TargetSizing:updateAllTargets(NPCManager, Config)
        targetAccumulator = 0
    end
end))

table.insert(runtimeConnections, Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Config.isUnloaded then
        return
    end

    if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
        toggleGUIVisibility()
    end
end))
