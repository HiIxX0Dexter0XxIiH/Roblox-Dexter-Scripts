-- Target Sizing Module
-- Handles adjustment of NPC target bounds for visibility/testing

local TargetSizing = {}

TargetSizing.originalSizes = {} -- Storage for original sizes to restore them later

-- Adjusts the NPC target bounds
function TargetSizing:applyTargetSizing(model, root, config)
    if not self.originalSizes[model] then 
        self.originalSizes[model] = root.Size 
    end
    
    if root.Size ~= config.TARGET_BOX_SIZE then
        root.Size = config.TARGET_BOX_SIZE
    end
    local targetTransparency = config.showTargetBox and 0.85 or 1
    if root.Transparency ~= targetTransparency then
        root.Transparency = targetTransparency -- If showTargetBox is true, you'll see a faint target box
    end
    if not root.CanCollide then
        root.CanCollide = true
    end
end

-- Restores target bounds to their normal size
function TargetSizing:restoreOriginalSize(model, npcManager)
    local data = npcManager:getActiveNPCs()[model]
    local root = data and data.root
    if not root then
        local character = data and data.character
        root = character and npcManager.getRootPart(character) or npcManager.getRootPart(model)
    end
    if root and self.originalSizes[model] then
        root.Size = self.originalSizes[model]
        root.Transparency = 1
        root.CanCollide = false
    end
    self.originalSizes[model] = nil
end

-- Updates target bounds for all NPCs based on config
function TargetSizing:updateAllTargets(npcManager, config)
    if not config.sizingEnabled then
        if next(self.originalSizes) then
            self:cleanup(npcManager)
        end
        return
    end
    for model, data in pairs(npcManager:getActiveNPCs()) do
        if data.root then
            self:applyTargetSizing(model, data.root, config)
        end
    end
end

-- Cleanup all adjusted target bounds
function TargetSizing:cleanup(npcManager)
    for model, _ in pairs(self.originalSizes) do
        self:restoreOriginalSize(model, npcManager)
    end
end

return TargetSizing
