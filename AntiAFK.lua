-- Anti-AFK для Drill to Earth's Core
local Players     = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Camera      = workspace.CurrentCamera
local player      = Players.LocalPlayer

local INTERVAL = 19 * 60 -- 19 минут

local function jump()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Jump = true end
end

local function randomClicks()
    local size = Camera.ViewportSize
    VirtualUser:CaptureController()
    for _ = 1, math.random(2, 4) do
        local pos = Vector2.new(math.random(100, size.X - 100), math.random(100, size.Y - 100))
        VirtualUser:ClickButton1(pos, Camera.CFrame)
        task.wait(math.random(3, 10) / 10)
    end
end

local function antiAfk()
    jump()
    task.wait(0.5)
    randomClicks()
    print("[Anti-AFK] Активность в " .. os.date("%H:%M:%S"))
end

-- Если Roblox засчитал простой, кликаем сразу
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Основной цикл
task.spawn(function()
    while true do
        task.wait(INTERVAL)
        pcall(antiAfk)
    end
end)

print("[Anti-AFK] Запущен, интервал 19 мин")
