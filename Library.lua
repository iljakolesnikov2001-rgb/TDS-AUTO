-- Library.lua
local Library = {}

function Library:GetGameState()
    local gui = game.Players.LocalPlayer.PlayerGui
    if gui:FindFirstChild("ReactLobbyHud") then return "LOBBY" end
    if gui:FindFirstChild("ReactUniversalHotbar") then return "GAME" end
    return "UNKNOWN"
end

function Library:PlaceTower(tower, pos)
    game:GetService("ReplicatedStorage").Events.PlaceTower:FireServer(tower, pos)
end

function Library:UpgradeTower(tower)
    game:GetService("ReplicatedStorage").Events.UpgradeTower:FireServer(tower)
end

function Library:SellTower(tower)
    game:GetService("ReplicatedStorage").Events.SellTower:FireServer(tower)
end

function Library:SkipWave()
    game:GetService("ReplicatedStorage").Events.SkipWave:FireServer()
end

return Library
