local env = _G
if typeof(getgenv) == "function" then
    env = getgenv()
end

env.BRM5_BRANCH = "developer"

loadstring(game:HttpGet("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/main/loader.lua"))()