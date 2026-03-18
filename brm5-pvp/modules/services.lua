local Services = {}

-- Shared service lookup lives here so the rest of the code can depend on one
-- small table instead of repeating game:GetService calls everywhere.
Services.Players = game:GetService("Players")
Services.RunService = game:GetService("RunService")
Services.UserInputService = game:GetService("UserInputService")
Services.GuiService = game:GetService("GuiService")
Services.Workspace = game:GetService("Workspace")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.Lighting = game:GetService("Lighting")

Services.localPlayer = Services.Players.LocalPlayer
Services.camera = Services.Workspace.CurrentCamera

return Services
