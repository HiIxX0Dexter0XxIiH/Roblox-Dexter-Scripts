-- Services Module
-- Provides access to Roblox game services

local Services = {}

Services.Players = game:GetService("Players")
Services.RunService = game:GetService("RunService")
Services.UserInputService = game:GetService("UserInputService")
Services.GuiService = game:GetService("GuiService")
Services.Workspace = game:GetService("Workspace")
Services.TweenService = game:GetService("TweenService")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.Lighting = game:GetService("Lighting")

-- Quick access to common objects
Services.localPlayer = Services.Players.LocalPlayer
Services.camera = Services.Workspace.CurrentCamera

return Services
