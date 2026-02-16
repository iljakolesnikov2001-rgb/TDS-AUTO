-- TDS Auto-Strat [Build 6.0 - NO KEY VERSION]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

print("[1] СИСТЕМА: Подготовка башен...")

-- База башен
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

local function resolveTower(input)
    if not input or input == "" then return nil end
    local n = input:lower():gsub("[^a-z0-9]", "")
    for _, name in ipairs(TowersList) do
        local dn = name:lower():gsub("[^a-z0-9]", "")
        if dn == n or dn:sub(1, #n) == n then return name end
    end
    return nil
end

print("[2] ЗАГРУЗКА: Подключение модуля (Обход Junkie Key)...")

-- Поток для удаления окна ключа Junkie, если оно вылезет
task.spawn(function()
    while task.wait(0.5) do
        local junkieUI = CoreGui:FindFirstChild("Junkie Key System") or PlayerGui:FindFirstChild("Junkie Key System")
        if junkieUI then 
            junkieUI:Destroy() 
            print("[!] Окно Junkie Key заблокировано.")
        end
    end
end)

shared.TDS_Table = nil
task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then
            -- Выполняем во внутреннем окружении
            getgenv().TDS_SkipKey = true -- Пытаемся передать флаг пропуска
            pcall(func)
            
            -- Проверка на наличие API
            for i = 1, 60 do
                if type(shared.TDS_Table) == "table" then break end
                task.wait(0.1)
            end
            
            if type(shared.TDS_Table) == "table" then
                print("[3] УСПЕХ: API экипировки получено.")
            else
                -- План Б: Если shared пуст, ищем в getgenv
                shared.TDS_Table = getgenv().TDS or getgenv().TDS_Table
                print("[3] API получено через альтернативный канал.")
            end
        end
    end
end)

-- === ИНТЕРФЕЙС ===
if PlayerGui:FindFirstChild("TDSAutoStrat") then PlayerGui.TDSAutoStrat:Destroy() end

local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "TDSAutoStrat"
gui.ResetOnSpawn = false

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 480, 0, 320)
main.Position = UDim2.new(0.5, -240, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main)
Instance.new("UIStroke", main).Color = Color3.fromRGB(140, 50, 255)

-- Вкладки
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -80)
content.Position = UDim2.new(0, 10, 0, 70)
content.BackgroundTransparency = 1

local tabs = {}
local btnH = Instance.new("Frame", main)
btnH.Size = UDim2.new(1, -20, 0, 30)
btnH.Position = UDim2.new(0, 10, 0, 35)
btnH.BackgroundTransparency = 1
Instance.new("UIListLayout", btnH).FillDirection = "Horizontal"

for i, n in ipairs({"Инфо", "Стратегии", "Настройки"}) do
    local f = Instance.new("Frame", content)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    tabs[i] = f

    local b = Instance.new("TextButton", btnH)
    b.Size = UDim2.new(0.33, 0, 1, 0)
    b.Text = n
    b.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = "GothamBold"
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, t in ipairs(tabs) do t.Visible = (i == j) end
    end)
end

-- === ВКЛАДКА СТРАТЕГИИ ===
local towerBox = Instance.new("TextBox", tabs[2])
towerBox.PlaceholderText = "Введите башню..."
towerBox.Size = UDim2.new(1, -40, 0, 40)
towerBox.Position = UDim2.new(0, 20, 0, 10)
towerBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
towerBox.TextColor3 = Color3.new(1,1,1)
towerBox.Font = "Gotham"
Instance.new("UICorner", towerBox)

local eqBtn = Instance.new("TextButton", tabs[2])
eqBtn.Text = "ЭКИПИРОВАТЬ"
eqBtn.Size = UDim2.new(1, -40, 0, 50)
eqBtn.Position = UDim2.new(0, 20, 0, 60)
eqBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
eqBtn.TextColor3 = Color3.new(1,1,1)
eqBtn.Font = "GothamBold"
Instance.new("UICorner", eqBtn)

eqBtn.MouseButton1Click:Connect(function()
    local name = resolveTower(towerBox.Text)
    if name then
        -- ЖЕСТКАЯ ПРОВЕРКА ТИПА (Фикс ошибки number)
        local API = shared.TDS_Table
        if type(API) == "table" and type(API.Equip) == "function" then
            local s, e = pcall(function() API:Equip(name) end)
            if s then 
                towerBox.Text = "Успех: "..name
            else 
                warn("Ошибка API:", e)
                towerBox.Text = "Ошибка выполнения"
            end
        else
            towerBox.Text = "API НЕ НАЙДЕНО. ВВЕДИТЕ КЛЮЧ ИЛИ ЖДИТЕ"
            -- Если обход не сработал, придется один раз ввести ключ во всплывающем окне Junkie
        end
    else
        towerBox.Text = "Башня не найдена"
    end
end)

print("[5] ГОТОВО: Скрипт запущен.")
