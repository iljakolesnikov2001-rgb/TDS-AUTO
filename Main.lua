-- Main.lua - Только интерфейс
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

-- Перетаскивание и ресайз (полный код из предыдущей рабочей версии — скопируй его сюда, если нужно)

-- Контент
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -100)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- Кнопки вызова функций из Library
local recorderBtn = Instance.new("TextButton")
recorderBtn.Text = "Запустить Recorder"
recorderBtn.Size = UDim2.new(0, 400, 0, 60)
recorderBtn.Position = UDim2.new(0.5, -200, 0, 20)
recorderBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
recorderBtn.TextColor3 = Color3.new(1,1,1)
recorderBtn.Parent = content

recorderBtn.MouseButton1Click:Connect(function()
    Library:StartRecorder()
end)

local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать башню"
equipBtn.Size = UDim2.new(0, 400, 0, 60)
equipBtn.Position = UDim2.new(0.5, -200, 0, 100)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = content

equipBtn.MouseButton1Click:Connect(function()
    Library:EquipTower()
end)

print("Интерфейс загружен! Функции в Library.lua")
