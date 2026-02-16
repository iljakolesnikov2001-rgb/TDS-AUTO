-- TDS Auto-Strat [Build 5.0]
local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

print("[1] СИСТЕМА: Инициализация списка башен...")

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

print("[2] ЗАГРУЗКА: Подключение внешнего модуля экипировки...")
shared.TDS_Table = nil -- Сброс для чистого запуска

task.spawn(function()
    local ok, code = pcall(game.HttpGet, game, "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download")
    if ok then
        local func = loadstring(code)
        if func then
            pcall(func) -- Запускаем код, он сам создаст shared.TDS_Table
            
            -- Ждем появления таблицы в памяти (до 5 секунд)
            local timeout = 0
            while type(shared.TDS_Table) ~= "table" and timeout < 50 do
                task.wait(0.1)
                timeout = timeout + 1
            end
            
            if type(shared.TDS_Table) == "table" then
                print("[3] УСПЕХ: Модуль экипировки готов.")
            else
                warn("[3] ВНИМАНИЕ: Модуль не создал таблицу функций.")
            end
        end
    else
        warn("[!] ОШИБКА: Не удалось скачать код экипировщика.")
    end
end)

-- === СОЗДАНИЕ ИНТЕРФЕЙСА ===
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

-- Навигация (Вкладки)
local tabHolder = Instance.new("Frame", main)
tabHolder.Size = UDim2.new(1, -20, 0, 35)
tabHolder.Position = UDim2.new(0, 10, 0, 40)
tabHolder.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", tabHolder)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 5)

local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1

local tabs = {}
local names = {"Инфо", "Стратегии", "Discord"}

for i, n in ipairs(names) do
    local f = Instance.new("Frame", content)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i ==
