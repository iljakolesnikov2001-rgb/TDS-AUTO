-- Main.lua - Только простой интерфейс
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 420)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true  -- двигается
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

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Текст
local testLabel = Instance.new("TextLabel")
testLabel.Text = "Меню работает!\nДвигай за фон.\nКликни X для закрытия."
testLabel.Size = UDim2.new(1, -20, 1, -80)
testLabel.Position = UDim2.new(0, 10, 0, 70)
testLabel.BackgroundTransparency = 1
testLabel.TextColor3 = Color3.fromRGB(220, 100, 255)
testLabel.TextSize = 24
testLabel.TextWrapped = true
testLabel.Parent = mainFrame

print("Простой UI готов!")
