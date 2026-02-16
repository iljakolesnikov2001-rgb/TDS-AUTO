-- Main.lua - Исправленная версия
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false -- Чтобы GUI не пропадал при смерти
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.Active = true
mainFrame.Draggable = true -- Внимание: официально устарело, но в большинстве инжекторов работает
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

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 100)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Панель вкладок
local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(1, -20, 0, 50)
tabPanel.Position = UDim2.new(0, 10, 0, 70)
tabPanel.BackgroundTransparency = 1
tabPanel.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabPanel

-- Контент
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -140)
contentFrame.Position = UDim2.new(0, 10, 0, 130)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local contents = {}
local tabTexts = {
    "Добро пожаловать в TDS Auto-Strat!\nИспользуйте вкладки выше для навигации.",
    "Настройки записи и экипировки:",
    "Настройки скрипта (В разработке).",
    "Наш Discord:\ndiscord.gg/7gXbJEvadu"
}

for i = 1, 4 do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    f.Parent = contentFrame
    contents[i] = f
    
    -- Текст-заголовок для каждой вкладки (уменьшен размер, чтобы не перекрывать кнопки)
    local lbl = Instance.new("TextLabel")
    lbl.Text = tabTexts[i]
    lbl.Size = UDim2.new(1, 0, 0, 60) -- Ограничил высоту текста
    lbl.TextColor3 = Color3.fromRGB(220, 100, 255)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 18
    lbl.TextWrapped = true
    lbl.Parent = f
end

-- Создание кнопок переключения вкладок
local names = {"Главная", "Стратегии", "Настройки", "Discord"}
for i, n in ipairs(names) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.Text = n
    btn.Parent = tabPanel

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 10)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        for j = 1, 4 do contents[j].Visible = (j == i) end
    end)
end

--- ЭЛЕМЕНТЫ ВКЛАДКИ СТРАТЕГИИ ---

-- Кнопка Recorder
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder"
recorderBtn.Size = UDim2.new(0, 300, 0, 50)
recorderBtn.Position = UDim2.new(0.5, -150, 0, 70)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Font = Enum.Font.GothamBold
recorderBtn.Parent = contents[2]

local rCorner = Instance.new("UICorner")
rCorner.Parent = recorderBtn

recorderBtn.MouseButton1Click:Connect(function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
    end)
    if not success then warn("Ошибка загрузки рекордера: " .. err) end
end)

-- Выбор башни
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}
local selectedIndex = 1

local towerBtn = Instance.new("TextButton")
towerBtn.Text = "Выбрать: " .. towers[selectedIndex]
towerBtn.Size = UDim2.new(0, 300, 0, 40)
towerBtn.Position = UDim2.new(0.5, -150, 0, 140)
towerBtn.BackgroundColor3 = Color3.fromRGB(70, 0, 130)
towerBtn.TextColor3 = Color3.new(1,1,1)
towerBtn.Font = Enum.Font.Gotham
towerBtn.Parent = contents[2]

towerBtn.MouseButton1Click:Connect(function()
    selectedIndex = selectedIndex % #towers + 1
    towerBtn.Text = "Выбрать: " .. towers[selectedIndex]
end)

-- Кнопка Экипировать
local equipBtn = Instance.new("TextButton")
equipBtn.Text = "ЭКИПИРОВАТЬ"
equipBtn.Size = UDim2.new(0, 200, 0, 50)
equipBtn.Position = UDim2.new(0.5, -100, 0, 200)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.Parent = contents[2]

local eCorner = Instance.new("UICorner")
eCorner.Parent = equipBtn

equipBtn.MouseButton1Click:Connect(function()
    if game.PlaceId ~= 3260590327 then
        print("Ошибка: Экипировка доступна только в лобби!")
        return
    end
    
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvent")
    if remote then
        remote:FireServer("Towers", "Equip", towers[selectedIndex])
        print("Запрос отправлен: " .. towers[selectedIndex])
    else
        warn("RemoteEvent не найден. Возможно, TDS обновили.")
    end
end)

print("TDS Auto-Strat успешно загружен!")
