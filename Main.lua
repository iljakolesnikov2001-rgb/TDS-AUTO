-- Main.lua - Простое меню без библиотек
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Parent = player:WaitForChild("PlayerGui")
gui.Name = "TDSAutoStrat"

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 400, 0, 300)
frame.Position = UDim2.new(0.5, -200, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 2
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat | iljakolesnikov2001-rgb"
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = frame

local label1 = Instance.new("TextLabel")
label1.Text = "Добро пожаловать! Версия 1.0"
label1.Position = UDim2.new(0, 10, 0, 60)
label1.Size = UDim2.new(1, -20, 0, 30)
label1.BackgroundTransparency = 1
label1.TextColor3 = Color3.fromRGB(200, 200, 200)
label1.Parent = frame

local label2 = Instance.new("TextLabel")
label2.Text = "Вкладка: Основная"
label2.Position = UDim2.new(0, 10, 0, 100)
label2.Size = UDim2.new(1, -20, 0, 30)
label2.BackgroundTransparency = 1
label2.TextColor3 = Color3.fromRGB(200, 200, 200)
label2.Parent = frame

local button = Instance.new("TextButton")
button.Text = "Тест кнопка (кликни)"
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0.5, -100, 1, -70)
button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
button.TextColor3 = Color3.new(1,1,1)
button.Parent = frame

button.MouseButton1Click:Connect(function()
    label2.Text = "Кнопка работает!"
end)

print("Меню загружено!")
