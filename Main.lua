-- Main.lua - Интерфейс
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/iljakolesnikov2001-rgb/TDS-AUTO/main/Library.lua"))()

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

local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat"
title.Size = UDim2.new(1, -60, 0, 60)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220, 100, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.Parent = mainFrame

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

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- Кнопка Recorder
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder"
recorderBtn.Size = UDim2.new(0, 400, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 20)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Parent = content

recorderBtn.MouseButton1Click:Connect(Library.StartRecorder)

-- Кнопка Equip
local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать башню"
equipBtn.Size = UDim2.new(0, 400, 0, 60)
equipBtn.Position = UDim2.new(0.5, -200, 0, 100)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = content

equipBtn.MouseButton1Click:Connect(Library.EquipTower)

print("Интерфейс готов! Функции в Library.lua")
