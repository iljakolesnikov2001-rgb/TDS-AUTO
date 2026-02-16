-- TDS Auto-Strat [Build 7.0 - KEY COMPATIBLE]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[1] СИСТЕМА: Запуск базы данных башен...")

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

print("[2] ЗАГРУЗКА: Ожидание API (нужен ввод ключа в окне Junkie)...")

-- Загружаем внешний скрипт. ВАЖНО: Тебе нужно ввести ключ в окне, которое появится!
task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then pcall(func) end
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
main.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main)
Instance.new("UIStroke", main).Color = Color3.fromRGB(150, 80, 255)

-- Навигация
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -80)
content.Position = UDim2.new(0, 10, 0, 70)
content.BackgroundTransparency = 1

local tabs = {}
local btnH = Instance.new("Frame", main)
btnH.Size = UDim2.new(1, -20, 0, 35)
btnH.Position = UDim2.new(0, 10, 0, 30)
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
    b.BackgroundColor3 = Color3.fromRGB(50, 30, 90)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = "GothamBold"
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        for j, t in ipairs(tabs) do t.Visible = (i == j) end
    end)
end

print("[4] ГРАФИКА: Меню создано.")

-- === ВКЛАДКА СТРАТЕГИИ ===
local towerBox = Instance.new("TextBox", tabs[2])
towerBox.PlaceholderText = "Введите название (напр. mini)"
towerBox.Size = UDim2.new(1, -40, 0, 45)
towerBox.Position = UDim2.new(0, 20, 0, 10)
towerBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
towerBox.TextColor3 = Color3.new(1,1,1)
towerBox.Font = "Gotham"
Instance.new("UICorner", towerBox)

local eqBtn = Instance.new("TextButton", tabs[2])
eqBtn.Text = "ЭКИПИРОВАТЬ"
eqBtn.Size = UDim2.new(1, -40, 0, 55)
eqBtn.Position = UDim2.new(0, 20, 0, 65)
eqBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
eqBtn.TextColor3 = Color3.new(1,1,1)
eqBtn.Font = "GothamBold"
Instance.new("UICorner", eqBtn)

eqBtn.MouseButton1Click:Connect(function()
    local name = resolveTower(towerBox.Text)
    if name then
        -- ЖЕСТКАЯ ПРОВЕРКА: Если shared.TDS_Table еще не таблица — значит ключ не введен
        if type(shared.TDS_Table) == "table" and type(shared.TDS_Table.Equip) == "function" then
            local s, e = pcall(function() shared.TDS_Table:Equip(name) end)
            if s then 
                towerBox.Text = "УСПЕХ: " .. name
                local rFunc = getgenv and getgenv().__tds_record_equip
                if type(rFunc) == "function" then rFunc(name) end
            else 
                warn("Ошибка API:", e)
                towerBox.Text = "ОШИБКА ВЫПОЛНЕНИЯ"
            end
        else
            towerBox.Text = "ВВЕДИТЕ КЛЮЧ В ОКНЕ JUNKIE!"
        end
    else
        towerBox.Text = "БАШНЯ НЕ НАЙДЕНА"
        task.wait(1)
        towerBox.Text = ""
    end
end)

print("[5] ФИНИШ: Скрипт 7.0 готов.")
