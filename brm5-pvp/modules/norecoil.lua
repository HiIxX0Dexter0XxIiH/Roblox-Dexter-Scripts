local NoRecoil = {}

function NoRecoil.patchWeapons(replicatedStorage, patchOptions)
    local weaponsFolder = replicatedStorage:FindFirstChild("Shared")
        and replicatedStorage.Shared:FindFirstChild("Configs")
        and replicatedStorage.Shared.Configs:FindFirstChild("Weapon")
        and replicatedStorage.Shared.Configs.Weapon:FindFirstChild("Weapons_Player")

    if not weaponsFolder then
        return
    end

    -- Receiver modules are the stable place to override recoil and firemode
    -- tuning across the player weapon config tree.
    for _, platform in pairs(weaponsFolder:GetChildren()) do
        if platform.Name:match("^Platform_") then
            for _, weapon in pairs(platform:GetChildren()) do
                for _, child in pairs(weapon:GetChildren()) do
                    if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                        local success, receiver = pcall(require, child)
                        if success and receiver and receiver.Config and receiver.Config.Tune then
                            local tune = receiver.Config.Tune
                            if patchOptions.recoil then
                                tune.Recoil_X = 0
                                tune.Recoil_Z = 0
                                tune.RecoilForce_Tap = 0
                                tune.RecoilForce_Impulse = 0
                                tune.Recoil_Range = Vector2.zero
                                tune.Recoil_Camera = 0
                                tune.RecoilAccelDamp_Crouch = Vector3.new(1, 1, 1)
                                tune.RecoilAccelDamp_Prone = Vector3.new(1, 1, 1)
                            end
                            if patchOptions.firemodes then
                                tune.Firemodes = {3, 2, 1, 0}
                            end
                        end
                    end
                end
            end
        end
    end
end

return NoRecoil
