-- TDS Auto-Strat [Build 4.0]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[1] СТАРТ: Подготовка базы данных башен...")

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

-- Умный поиск (твоя логика)
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

print("[2] ЗАГРУЗКА: Подключение внешнего модуля экипировки...")

-- Очистка старой таблицы перед загрузкой для чистого теста
shared.TDS_Table = nil

task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then
            -- Выполняем. Нам не важно, что функция вернет (1 или таблицу), 
            -- так как она сама запишет данные в shared.TDS_Table
            pcall(func) 
            
            -- Ждем, пока таблица появится в памяти
            for i = 1, 50 do
                if type(shared.TDS_Table) == "table" then break end
                task.wait(0.1)
            end
            
            if type(shared.TDS_Table) == "table" then
                print("[3] ГОТОВО: Модуль экипировки успешно инициализирован.")
            else
                warn("[3] ОШИБКА: Модуль загружен, но функции Equip не найдены.")
            end
        end
    else
        warn("[!] ОШИБКА СЕТИ: Не удалось получить код еквипера.")
    end
end)

-- === ИНТЕРФЕЙС ===
if PlayerGui:FindFirstChild("TDSAutoStrat") then PlayerGui.TDSAutoStrat:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 350)
main.Position = UDim2.new(0.5, -250, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(20, 10, 35)
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", main)
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(160, 60, 255)

-- Навигация
local btnHolder = Instance.new("Frame", main)
btnHolder.Size = UDim2.new(1, -20, 0, 35)
btnHolder.Position = UDim2.new(0, 10, 0, 40)
btnHolder.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", btnHolder)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 5)

local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1

local tabs = {}
local names = {"Инфо", "Стратегии", "Настройки", "Discord"}

for i, n in ipairs(names) do
    local f = Instance.new("Frame", content)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    tabs[i] = f

    local b = Instance.new("TextButton", btnHolder)
    b.Size = UDim2.new(0.24, 0, 1, 0)
    b.Text = n
    b.BackgroundColor3 = Color3.fromRGB(50, 20, 100)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, t in ipairs(tabs) do t.Visible = (i == j) end
    end)
end

print("[4] ИНТЕРФЕЙС: Меню отрисовано.")

-- === ВКЛАДКА СТРАТЕГИИ ===

-- 1. Кнопка Рекордера
local rec = Instance.new("TextButton", tabs[2])
rec.Text = "ЗАПУСТИТЬ RECORDER"
rec.Size = UDim2.new(1, -40, 0, 45)
rec.Position = UDim2.new(0, 20, 0, 10)
rec.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
rec.TextColor3 = Color3.new(1,1,1)
rec.Font = Enum.Font.GothamBold
Instance.new("UICorner", rec)
rec.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- 2. ПОЛЕ ВВОДА (TextBox)
local towerInput = Instance.new("TextBox", tabs[2])
towerInput.PlaceholderText = "Введите название башни (напр. scout)"
towerInput.Size = UDim2.new(1, -40, 0, 45)
towerInput.Position = UDim2.new(0, 20, 0, 65)
towerInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
towerInput.TextColor3 = Color3.new(1,1,1)
towerInput.Font = Enum.Font.Gotham
towerInput.TextSize = 16
towerInput.Text = ""
Instance.new("UICorner", towerInput)

-- 3. КНОПКА ЭКИПИРОВАТЬ
local eqBtn = Instance.new("TextButton", tabs[2])
eqBtn.Text = "ЭКИПИРОВАТЬ"
eqBtn.Size = UDim2.new(1, -40, 0, 55)
eqBtn.Position = UDim2.new(0, 20, 0, 125)
eqBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
eqBtn.TextColor3 = Color3.new(1,1,1)
eqBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", eqBtn)

eqBtn.MouseButton1Click:Connect(function()
    local tower = resolveTower(towerInput.Text)
    
    if tower then
        -- ОБРАЩАЕМСЯ СТРОГО К SHARED ТАБЛИЦЕ
        local API = shared.TDS_Table
        
        if type(API) == "table" and type(API.Equip) == "function" then
            local success, err = pcall(function()
                API:Equip(tower) -- Используем метод из таблицы
            end)
            
            if success then
                towerInput.Text = "УСПЕШНО: " .. tower
                -- Сообщаем рекордеру
                local rFunc = getgenv and getgenv().__tds_record_equip
                if type(rFunc) == "function" then rFunc(tower) end
            else
                towerInput.Text = "ОШИБКА ВЫПОЛНЕНИЯ"
                warn("Ошибка API.Equip:", err)
            end
        else
            towerInput.Text = "API ЕЩЕ ГРУЗИТСЯ..."
            print("Текущий тип API:", type(API))
        end
    else
        towerInput.Text = "БАШНЯ НЕ НАЙДЕНА"
        task.wait(1)
        towerInput.Text = ""
    end
end)

-- Кнопка закрытия
local close = Instance.new("TextButton", main)
close.Text = "X"
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(150, 0, 50)
close.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", close)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

print("[5] ФИНИШ: Скрипт версии 4.0 готов.")
