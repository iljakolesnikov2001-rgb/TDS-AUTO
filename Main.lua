-- Main.lua - 4 вкладки + recorder + equip с нормализацией
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.Active = true
mainFrame.Draggable = true
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

-- Закрытие
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -55, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 100)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Панель вкладок
local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(1, -20, 0, 60)
tabPanel.Position = UDim2.new(0, 10, 0, 60)
tabPanel.BackgroundTransparency = 1
tabPanel.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 15)
tabLayout.Parent = tabPanel

-- Контент
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -130)
contentFrame.Position = UDim2.new(0, 10, 0, 120)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local contents = {}
for i = 1, 4 do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (i == 1)
    f.Parent = contentFrame
    contents[i] = f
end

-- Текст для вкладок
local tabTexts = {
    "Основное\nДобро пожаловать!",
    "Стратегии\nRecorder и equip ниже.",
    "Настройки\nПока пусто.",
    "Discord\nhttps://discord.gg/7gXbJEvadu"
}

for i = 1, 4 do
    local lbl = Instance.new("TextLabel")
    lbl.Text = tabTexts[i]
    lbl.TextColor3 = Color3.fromRGB(220, 100, 255)
    lbl.BackgroundTransparency = 1
    lbl.TextSize = 22
    lbl.TextWrapped = true
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Parent = contents[i]
end

-- Кнопки вкладок
local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.22, 0, 1, -10)
    btn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.Text = name

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 12)
    bc.Parent = btn

    local bs = Instance.new("UIStroke")
    bs.Thickness = 2
    bs.Color = Color3.fromRGB(220, 100, 255)
    bs.Parent = btn

    btn.MouseButton1Click:Connect(function()
        for j = 1, 4 do contents[j].Visible = (j == index) end
    end)

    btn.Parent = tabPanel
end

local names = {"Основное", "Стратегии", "Настройки", "Discord"}
for i, n in ipairs(names) do createTabButton(n, i) end

-- Recorder в Стратегии
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder"
recorderBtn.Size = UDim2.new(0, 400, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 100)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Parent = contents[2]

recorderBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- Equip в Стратегии (твой код, починил)
local Towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Slasher","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local function normalize(s)
    return s:lower():gsub("[^a-z0-9]", "")
end

local Normalized = {}
for _, name in ipairs(Towers) do
    Normalized[#Normalized + 1] = {
        raw = name,
        norm = normalize(name),
        words = name:lower():split(" ")
    }
end

local function resolveTower(input)
    if input == "" then return end
    local n = normalize(input)
    for _, t in ipairs(Normalized) do
        if t.norm == n then return t.raw end
    end
    for _, t in ipairs(Normalized) do
        if t.norm:sub(1, #n) == n then return t.raw end
    end
    for _, t in ipairs(Normalized) do
        for _, w in ipairs(t.words) do
            if w:sub(1, #n) == n then return t.raw end
        end
    end
end

-- Textbox для ввода
local textbox = Instance.new("TextBox")
textbox.PlaceholderText = "Введи имя башни (можно частично)"
textbox.Size = UDim2.new(0, 400, 0, 50)
textbox.Position = UDim2.new(0.5, -200, 0, 180)
textbox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
textbox.TextColor3 = Color3.fromRGB(230, 230, 230)
textbox.TextSize = 20
textbox.Parent = contents[2]

local textboxCorner = Instance.new("UICorner")
textboxCorner.CornerRadius = UDim.new(0, 8)
textboxCorner.Parent = textbox

textbox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    local tower = resolveTower(textbox.Text)
    if tower then
        if game.PlaceId ~= 3260590327 then
            print("Только в лобби TDS!")
            return
        end
        game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", tower)
        print("Экипировано: " .. tower)
    else
        print("Башня не найдена")
    end
    textbox.Text = ""
end)

print("Equip готов! Введи имя башни (можно частично), Enter.")
