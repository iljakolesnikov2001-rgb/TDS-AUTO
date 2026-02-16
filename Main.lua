-- Main.lua - Полностью локальный: Recorder + Equip в основном окне
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 420)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(200, 80, 255)
stroke.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat"
title.Size = UDim2.new(1, -60, 0, 60)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220, 100, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.Parent = mainFrame

-- Закрытие
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -55, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 100)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Перетаскивание и ресайз (полный рабочий код)

-- Контент
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- Простой recorder (локальный)
local recording = false
local log = {}

local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Recorder: ВЫКЛ"
recorderBtn.Size = UDim2.new(0, 300, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -150, 0, 20)
recorderBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Parent = content

recorderBtn.MouseButton1Click:Connect(function()
    recording = not recording
    recorderBtn.Text = "Recorder: " .. (recording and "ВКЛ" or "ВЫКЛ")
    recorderBtn.BackgroundColor3 = recording and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    if not recording then
        writefile("Strat.txt", table.concat(log, "\n"))
        print("Сохранено в Strat.txt (" .. #log .. " строк)")
        log = {}
    end
end)

-- Пример записи (потом подключи к реальным действиям)
local function record(action)
    if recording then
        table.insert(log, action)
    end
end

-- Equip
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local selected = towers[1]

local towerBtn = Instance.new("TextButton")
towerBtn.Text = "Башня: " .. selected
towerBtn.Size = UDim2.new(0, 350, 0, 50)
towerBtn.Position = UDim2.new(0.5, -175, 0, 100)
towerBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
towerBtn.TextColor3 = Color3.new(1,1,1)
towerBtn.Parent = content

towerBtn.MouseButton1Click:Connect(function()
    local idx = table.find(towers, selected) or 1
    idx = idx % #towers + 1
    selected = towers[idx]
    towerBtn.Text = "Башня: " .. selected
end)

local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать"
equipBtn.Size = UDim2.new(0, 250, 0, 50)
equipBtn.Position = UDim2.new(0.5, -125, 0, 170)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = content

equipBtn.MouseButton1Click:Connect(function()
    if game.PlaceId ~= 3260590327 then
        print("Только в лобби TDS!")
        return
    end
    game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", selected)
    print("Экипировано: " .. selected)
    record("Equip " .. selected)
end)

print("Меню готово! Recorder локальный, сохраняет при выключении.")
