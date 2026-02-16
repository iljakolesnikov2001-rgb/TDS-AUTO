-- TDS Auto-Strat [Build 1.2]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[1] Инициализация систем...")

-- === ЛОГИКА ПОИСКА (ТВОЯ) ===
local TowersList = {
    "Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant",
    "Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm",
    "Rocketeer","Trapper","Military Base","Crook Boss",
    "Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner",
    "Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base",
    "Brawler","Necromancer","Accelerator","Engineer","Hacker",
    "Gladiator","Commando","Slasher","Frost Blaster","Archer","Swarmer",
    "Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer",
    "Hallow Punk","Harvester","Snowballer","Elementalist",
    "Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"
}

local function normalize(s) return s:lower():gsub("[^a-z0-9]", "") end
local function resolveTower(input)
    if not input or input == "" then return nil end
    local n = normalize(input)
    for _, name in ipairs(TowersList) do
        if normalize(name) == n then return name end
    end
    for _, name in ipairs(TowersList) do
        if normalize(name):sub(1, #n) == n then return name end
    end
    return nil
end

print("[2] Загрузка внешнего API экипировки...")
local TDS = {}
task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then
            local result = func()
            -- Проверяем, где лежит функция Equip
            TDS = result or shared.TDS_Table or _G.TDS or {}
            print("[3] API успешно загружено и привязано.")
        end
    else
        warn("[!] Ошибка загрузки API. Экипировка может не работать.")
    end
end)

-- === ИНТЕРФЕЙС ===
if PlayerGui:FindFirstChild("TDSAutoStrat") then PlayerGui.TDSAutoStrat:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 550, 0, 400)
main.Position = UDim2.new(0.5, -275, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(25, 10, 45)
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 15)
local strk = Instance.new("UIStroke", main)
strk.Thickness = 3
strk.Color = Color3.fromRGB(180, 80, 255)

-- Вкладки
local contentFrame = Instance.new("Frame", main)
contentFrame.Size = UDim2.new(1, -20, 1, -110)
contentFrame.Position = UDim2.new(0, 10, 0, 90)
contentFrame.BackgroundTransparency = 1

local contents = {}
local tabHolder = Instance.new("Frame", main)
tabHolder.Size = UDim2.new(1, -20, 0, 40)
tabHolder.Position = UDim2.new(0, 10, 0, 40)
tabHolder.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", tabHolder)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)

local names = {"Инфо", "Стратегии", "Настройки", "Discord"}
for i, name in ipairs(names) do
    local f = Instance.new("Frame", contentFrame)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    contents[i] = f

    local b = Instance.new("TextButton", tabHolder)
    b.Size = UDim2.new(0, 125, 1, 0)
    b.Text = name
    b.BackgroundColor3 = Color3.fromRGB(60, 30, 110)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, c in ipairs(contents) do c.Visible = (i == j) end
    end)
end

print("[4] Сборка интерфейса завершена.")

-- === ВКЛАДКА СТРАТЕГИИ ===

-- Recorder
local rec = Instance.new("TextButton", contents[2])
rec.Text = "Запустить Recorder"
rec.Size = UDim2.new(1, -40, 0, 50)
rec.Position = UDim2.new(0, 20, 0, 10)
rec.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
rec.TextColor3 = Color3.new(1,1,1)
rec.Font = Enum.Font.GothamBold
Instance.new("UICorner", rec)
rec.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- Поле ввода названия башни
local towerInput = Instance.new("TextBox", contents[2])
towerInput.PlaceholderText = "Введите название башни (напр. Scout)..."
towerInput.Size = UDim2.new(1, -40, 0, 50)
towerInput.Position = UDim2.new(0, 20, 0, 80)
towerInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
towerInput.TextColor3 = Color3.new(1,1,1)
towerInput.Font = Enum.Font.Gotham
towerInput.TextSize = 18
Instance.new("UICorner", towerInput)

-- Кнопка Экипировки
local equip = Instance.new("TextButton", contents[2])
equip.Text = "ЭКИПИРОВАТЬ"
equip.Size = UDim2.new(1, -40, 0, 60)
equip.Position = UDim2.new(0, 20, 0, 150)
equip.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
equip.TextColor3 = Color3.new(1,1,1)
equip.Font = Enum.Font.GothamBold
Instance.new("UICorner", equip)

equip.MouseButton1Click:Connect(function()
    local target = resolveTower(towerInput.Text)
    if target then
        -- Пробуем разные способы вызова Equip из API
        local equipFunc = TDS.Equip or (shared.TDS_Table and shared.TDS_Table.Equip)
        
        if equipFunc then
            local success, err = pcall(function()
                equipFunc(TDS, target) -- Вызов через двоеточие (TDS:Equip)
            end)
            
            if success then
                towerInput.Text = "Успешно: " .. target
                -- Отправка данных рекордеру
                local rFunc = getgenv and getgenv().__tds_record_equip
                if type(rFunc) == "function" then rFunc(target) end
            else
                towerInput.Text = "Ошибка API!"
                warn("Ошибка Equip:", err)
            end
        else
            towerInput.Text = "API еще загружается..."
        end
    else
        towerInput.Text = "Башня не найдена!"
        task.wait(1)
        towerInput.Text = ""
    end
end)

print("[5] Скрипт полностью готов к работе!")
