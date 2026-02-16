-- Исправленный TDS Auto-Strat с рабочей системой экипировки
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- === Инициализация системы экипировки (Твой метод) ===
local TDS = {}
shared.TDS_Table = TDS

-- Загрузка внешнего модуля экипировки
task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        loadstring(code)()
        print("TDS API успешно загружен")
    else
        warn("Не удалось загрузить TDS API")
    end
end)

-- Список башен и логика поиска
local TowersList = {
    "Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Slasher","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"
}

local function normalize(s) return s:lower():gsub("[^a-z0-9]", "") end
local function resolveTower(input)
    if input == "" then return nil end
    local n = normalize(input)
    for _, name in ipairs(TowersList) do
        if normalize(name):sub(1, #n) == n then return name end
    end
    return nil
end

-- === Создание GUI ===
if PlayerGui:FindFirstChild("TDSAutoStrat") then PlayerGui.TDSAutoStrat:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(200, 80, 255)

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 100)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Панель вкладок
local tabPanel = Instance.new("Frame", mainFrame)
tabPanel.Size = UDim2.new(1, -20, 0, 50)
tabPanel.Position = UDim2.new(0, 10, 0, 60)
tabPanel.BackgroundTransparency = 1
local tabLayout = Instance.new("UIListLayout", tabPanel)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)

-- Контент
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -20, 1, -130)
contentFrame.Position = UDim2.new(0, 10, 0, 120)
contentFrame.BackgroundTransparency = 1

local contents = {}
local names = {"Основное", "Стратегии", "Настройки", "Discord"}
for i, name in ipairs(names) do
    local f = Instance.new("Frame", contentFrame)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    contents[i] = f

    local btn = Instance.new("TextButton", tabPanel)
    btn.Size = UDim2.new(0, 135, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
    btn.Text = name
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.MouseButton1Click:Connect(function()
        for j, c in ipairs(contents) do c.Visible = (j == i) end
    end)
end

-- === ВКЛАДКА СТРАТЕГИИ ===

-- Recorder
local recorderBtn = Instance.new("TextButton", contents[2])
recorderBtn.Text = "Запустить Recorder"
recorderBtn.Size = UDim2.new(0, 400, 0, 50)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 20)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", recorderBtn)
recorderBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- Поле ввода башни (TextBox)
local towerInput = Instance.new("TextBox", contents[2])
towerInput.PlaceholderText = "Введите название башни (напр. Accel)..."
towerInput.Size = UDim2.new(0, 400, 0, 50)
towerInput.Position = UDim2.new(0.5, -200, 0, 100)
towerInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
towerInput.TextColor3 = Color3.new(1,1,1)
towerInput.Font = Enum.Font.Gotham
towerInput.TextSize = 18
Instance.new("UICorner", towerInput)

-- Кнопка Экипировать
local equipBtn = Instance.new("TextButton", contents[2])
equipBtn.Text = "ЭКИПИРОВАТЬ"
equipBtn.Size = UDim2.new(0, 300, 0, 60)
equipBtn.Position = UDim2.new(0.5, -150, 0, 180)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.TextSize = 22
Instance.new("UICorner", equipBtn)

equipBtn.MouseButton1Click:Connect(function()
    local towerName = resolveTower(towerInput.Text)
    if towerName then
        if TDS.Equip then
            local ok = pcall(TDS.Equip, TDS, towerName)
            if ok then
                print("Успешно экипировано: " .. towerName)
                -- Передаем данные рекордеру, если он активен
                local globals = getgenv and getgenv() or nil
                local record = globals and globals.__tds_record_equip
                if type(record) == "function" then record(towerName) end
                towerInput.Text = "Успех: " .. towerName
            else
                warn("Ошибка при вызове TDS:Equip")
            end
        else
            towerInput.Text = "Ошибка: API еще грузится..."
        end
    else
        towerInput.Text = "Башня не найдена!"
        task.wait(1)
        towerInput.Text = ""
    end
end)

-- Discord (вкладка 4)
local dsLabel = Instance.new("TextLabel", contents[4])
dsLabel.Text = "Наш Дискорд:\ndiscord.gg/7gXbJEvadu"
dsLabel.Size = UDim2.new(1, 0, 1, 0)
dsLabel.BackgroundTransparency = 1
dsLabel.TextColor3 = Color3.new(1,1,1)
dsLabel.Font = Enum.Font.GothamBold
dsLabel.TextSize = 24

print("Скрипт готов. Экипировка работает через внешний TDS API.")
