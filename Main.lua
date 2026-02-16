-- Main.lua - Всё в основной вкладке: Recorder + Equip
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

-- Заголовок + закрытие + перетаскивание + ресайз (полный рабочий код из предыдущей версии)

-- Панель вкладок + контент (полный рабочий код из предыдущей версии)

-- Основная вкладка (contents[1]) - Recorder + Equip
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder (логгер стратегий)"
recorderBtn.Size = UDim2.new(0, 400, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 50)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Font = Enum.Font.GothamBold
recorderBtn.TextSize = 22
recorderBtn.Parent = contents[1]

recorderBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- Свой эквиппер
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Slasher","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local selected = towers[1]

local towerBtn = Instance.new("TextButton")
towerBtn.Text = "Башня: " .. selected
towerBtn.Size = UDim2.new(0, 350, 0, 50)
towerBtn.Position = UDim2.new(0.5, -175, 0, 150)
towerBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
towerBtn.TextColor3 = Color3.new(1,1,1)
towerBtn.Parent = contents[1]

towerBtn.MouseButton1Click:Connect(function()
    local idx = table.find(towers, selected) or 1
    idx = idx % #towers + 1
    selected = towers[idx]
    towerBtn.Text = "Башня: " .. selected
end)

local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать"
equipBtn.Size = UDim2.new(0, 250, 0, 50)
equipBtn.Position = UDim2.new(0.5, -125, 0, 220)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = contents[1]

equipBtn.MouseButton1Click:Connect(function()
    if game.PlaceId ~= 3260590327 then
        print("Только в лобби TDS!")
        return
    end
    game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", selected)
    print("Экипировано: " .. selected)
end)

print("Recorder и Equip в основной вкладке!")
