-- TDS Auto-Strat [Build 2.0]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[1] СТАРТ: Инициализация таблиц башен...")

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

-- Функция поиска (твоя логика)
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

print("[2] ЗАГРУЗКА: Подключение внешнего API экипировки...")
local TDS_API = {}

task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then
            local result = func()
            -- ИСПРАВЛЕНИЕ: Проверяем, что получили таблицу, а не число 1
            if type(result) == "table" then
                TDS_API = result
            elseif type(shared.TDS_Table) == "table" then
                TDS_API = shared.TDS_Table
            end
            print("[3] ГОТОВО: API успешно подвязано.")
        end
    else
        warn("[!] ОШИБКА: Не удалось скачать API.")
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
local border = Instance.new("UIStroke", main)
border.Thickness = 3
border.Color = Color3.fromRGB(160, 60, 255)

-- Кнопка закрытия
local close = Instance.new("TextButton", main)
close.Text = "X"
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(120, 0, 50)
close.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", close)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Навигация
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1

local tabs = {}
local btnHolder = Instance.new("Frame", main)
btnHolder.Size = UDim2.new(1, -20, 0, 35)
btnHolder.Position = UDim2.new(0, 10, 0, 40)
btnHolder.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", btnHolder)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 5)

local names = {"Инфо", "Стратегии", "Дискорд"}
for i, n in ipairs(names) do
    local f = Instance.new("Frame", content)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    tabs[i] = f

    local b = Instance.new("TextButton", btnHolder)
    b.Size = UDim2.new(0, 156, 1, 0)
    b.Text = n
    b.BackgroundColor3 = Color3.fromRGB(50, 20, 100)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, t in ipairs(tabs) do t.Visible = (i == j) end
    end)
end

print("[4] ИНТЕРФЕЙС: Вкладки созданы.")

-- === ВКЛАДКА СТРАТЕГИИ ===

-- 1. Recorder
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

-- 2. ТЕКСТОВОЕ ПОЛЕ (TextBox)
local input = Instance.new("TextBox", tabs[2])
input.PlaceholderText = "Введите название (напр. Accel)"
input.Size = UDim2.new(1, -40, 0, 45)
input.Position = UDim2.new(0, 20, 0, 65)
input.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
input.TextColor3 = Color3.new(1,1,1)
input.Font = Enum.Font.Gotham
input.TextSize = 16
Instance.new("UICorner", input)

-- 3. Кнопка Экипировки
local eqBtn = Instance.new("TextButton", tabs[2])
eqBtn.Text = "ЭКИПИРОВАТЬ"
eqBtn.Size = UDim2.new(1, -40, 0, 55)
eqBtn.Position = UDim2.new(0, 20, 0, 125)
eqBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
eqBtn.TextColor3 = Color3.new(1,1,1)
eqBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", eqBtn)

eqBtn.MouseButton1Click:Connect(function()
    local tower = resolveTower(input.Text)
    if tower then
        -- Проверяем наличие функции в API
        local targetFunc = TDS_API.Equip or (shared.TDS_Table and shared.TDS_Table.Equip)
        
        if type(targetFunc) == "function" then
            local success, err = pcall(function()
                targetFunc(TDS_API, tower)
            end)
            
            if success then
                input.Text = "УСПЕХ: " .. tower
                -- Интеграция с рекордером
                local rFunc = getgenv and getgenv().__tds_record_equip
                if type(rFunc) == "function" then rFunc(tower) end
            else
                input.Text = "ОШИБКА API!"
                warn("Ошибка вызова Equip:", err)
            end
        else
            input.Text = "API НЕ ЗАГРУЖЕНО!"
        end
    else
        input.Text = "БАШНЯ НЕ НАЙДЕНА!"
        task.wait(1)
        input.Text = ""
    end
end)

print("[5] ФИНИШ: Скрипт готов к работе.")
