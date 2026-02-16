-- TDS Auto-Strat + Working Equipper
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- === 1. ПОДГОТОВКА ТАБЛИЦЫ БАШЕН (ТВОЯ ЛОГИКА) ===
local Towers = {
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
local Normalized = {}
for _, name in ipairs(Towers) do
    table.insert(Normalized, {
        raw = name,
        norm = normalize(name),
        words = name:lower():split(" ")
    })
end

local function resolveTower(input)
    if not input or input == "" then return end
    local n = normalize(input)
    for _, t in ipairs(Normalized) do if t.norm == n then return t.raw end end
    for _, t in ipairs(Normalized) do if t.norm:sub(1, #n) == n then return t.raw end end
    for _, t in ipairs(Normalized) do
        for _, w in ipairs(t.words) do if w:sub(1, #n) == n then return t.raw end end
    end
end

-- === 2. ЗАГРУЗКА TDS API (ОТКУДА БЕРЕТСЯ EQUIP) ===
local TDS = {}
task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        -- Выполняем код и сохраняем результат в TDS
        local loaded = loadstring(code)
        if loaded then
            TDS = loaded() or shared.TDS_Table or {}
            print("TDS API успешно загружен!")
        end
    else
        warn("Ошибка загрузки API для экипировки")
    end
end)

-- === 3. СОЗДАНИЕ ИНТЕРФЕЙСА ===
if PlayerGui:FindFirstChild("TDSAutoStrat") then PlayerGui.TDSAutoStrat:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 10, 50)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(180, 50, 255)

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -40, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 70)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", closeBtn)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Вкладки
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -20, 1, -120)
contentFrame.Position = UDim2.new(0, 10, 0, 100)
contentFrame.BackgroundTransparency = 1

local contents = {}
local tabContainer = Instance.new("Frame", mainFrame)
tabContainer.Size = UDim2.new(1, -20, 0, 40)
tabContainer.Position = UDim2.new(0, 10, 0, 50)
tabContainer.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", tabContainer)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 5)

local names = {"Главная", "Стратегии", "Настройки", "Discord"}
for i, n in ipairs(names) do
    local f = Instance.new("Frame", contentFrame)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    contents[i] = f

    local b = Instance.new("TextButton", tabContainer)
    b.Size = UDim2.new(0, 140, 1, 0)
    b.Text = n
    b.BackgroundColor3 = Color3.fromRGB(60, 20, 120)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, c in ipairs(contents) do c.Visible = (i == j) end
    end)
end

-- === ВКЛАДКА СТРАТЕГИИ (RECORDER + EQUIP) ===

-- 1. Кнопка Recorder
local recBtn = Instance.new("TextButton", contents[2])
recBtn.Text = "ЗАПУСТИТЬ RECORDER"
recBtn.Size = UDim2.new(1, -40, 0, 50)
recBtn.Position = UDim2.new(0, 20, 0, 10)
recBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
recBtn.TextColor3 = Color3.new(1,1,1)
recBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", recBtn)

recBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- 2. Поле поиска (TextBox)
local inputField = Instance.new("TextBox", contents[2])
inputField.PlaceholderText = "Введите название башни (напр. Accel)"
inputField.Size = UDim2.new(1, -40, 0, 50)
inputField.Position = UDim2.new(0, 20, 0, 80)
inputField.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
inputField.TextColor3 = Color3.new(1,1,1)
inputField.Font = Enum.Font.Gotham
inputField.TextSize = 18
Instance.new("UICorner", inputField)

-- 3. Кнопка Экипировать
local equipBtn = Instance.new("TextButton", contents[2])
equipBtn.Text = "ЭКИПИРОВАТЬ"
equipBtn.Size = UDim2.new(1, -40, 0, 60)
equipBtn.Position = UDim2.new(0, 20, 0, 150)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Font = Enum.Font.GothamBold
equipBtn.TextSize = 20
Instance.new("UICorner", equipBtn)

equipBtn.MouseButton1Click:Connect(function()
    local found = resolveTower(inputField.Text)
    if found then
        if TDS and TDS.Equip then
            local success, err = pcall(function() TDS:Equip(found) end)
            if success then
                inputField.Text = "Экипировано: " .. found
                -- Связь с рекордером
                local recordFunc = getgenv and getgenv().__tds_record_equip
                if type(recordFunc) == "function" then recordFunc(found) end
            else
                inputField.Text = "Ошибка API: " .. tostring(err)
            end
        else
            inputField.Text = "API не загружено! Ждите..."
        end
    else
        inputField.Text = "Башня не найдена!"
        task.wait(1)
        inputField.Text = ""
    end
end)

print("TDS Auto-Strat: Интерфейс и Экипировщик готовы!")
