-- Main.lua - Всё работает: Recorder + Equip в основной вкладке
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
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 28
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Перетаскивание
local dragging = false
local dragInput, dragStart, startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Ресайз
local resizeGrip = Instance.new("Frame")
resizeGrip.Size = UDim2.new(0, 25, 0, 25)
resizeGrip.Position = UDim2.new(1, -25, 1, -25)
resizeGrip.BackgroundColor3 = Color3.fromRGB(200, 80, 255)
resizeGrip.Parent = mainFrame

local gripCorner = Instance.new("UICorner")
gripCorner.CornerRadius = UDim.new(0, 8)
gripCorner.Parent = resizeGrip

local resizing = false
local resizeStart, resizeStartSize

resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        resizeStart = input.Position
        resizeStartSize = mainFrame.Size
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - resizeStart
        mainFrame.Size = UDim2.new(resizeStartSize.X.Scale, math.max(450, resizeStartSize.X.Offset + delta.X),
                                  resizeStartSize.Y.Scale, math.max(320, resizeStartSize.Y.Offset + delta.Y))
    end
end)

resizeGrip.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

-- Контент (без вкладок, всё в основном окне)
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- Recorder кнопка
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder (логгер стратегий)"
recorderBtn.Size = UDim2.new(0, 400, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 20)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Font = Enum.Font.GothamBold
recorderBtn.TextSize = 22
recorderBtn.Parent = content

recorderBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/tds-recorder/refs/heads/main/recorder.lua"))()
end)

-- Equip
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local selected = towers[1]

local towerBtn = Instance.new("TextButton")
towerBtn.Text = "Башня: " .. selected
towerBtn.Size = UDim2.new(0, 350, 0, 50)
towerBtn.Position = UDim2.new(0.5, -175, 0, 100)
towerBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
towerBtn.TextColor3 = Color3.new(1,1,1)
towerBtn.Parent = content

towerBtn.MouseButton1Click:Connect(function()
    local idx = table.find(towers, selected) or 1
    idx = idx % #towers + 1
    selected = towers[idx]
    towerBtn.Text = "Башня: " .. selected
end)

local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать"
equipBtn.Size = UDim2.new(0, 250, 0, 50)
equipBtn.Position = UDim2.new(0.5, -125, 0, 170)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = content

equipBtn.MouseButton1Click:Connect(function()
    if game.PlaceId ~= 3260590327 then
        print("Только в лобби TDS!")
        return
    end
    game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", selected)
    print("Экипировано: " .. selected)
end)

print("Меню готово! Recorder и Equip в основном окне.")
