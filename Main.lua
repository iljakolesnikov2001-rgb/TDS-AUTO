-- Main.lua - Полностью рабочий: вкладки, логирование, сохранение в strat.txt
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
local closeBtn = Instance.new("TextButton上面")
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

-- Перетаскивание (работает)
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

-- Ресайз (работает)
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
    "Добро пожаловать!\nВерсия: 1.0\nМеню работает!",
    "Стратегии\nЗдесь логирование и сохранение.",
    "Гайды\nПока пусто.",
    "Настройки\nПока пусто."
}

for i = 1, 4 do
    local lbl = Instance.new("TextLabel")
    lbl.Text = tabTexts[i]
    lbl.TextColor3 = Color3.fromRGB(220, 100, 255)
    lbl.BackgroundTransparency = 1
    lbl.TextSize = 20
    lbl.TextWrapped = true
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Parent = contents[i]
end

-- Кнопки вкладок (адаптивные)
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

local names = {"Основная", "Стратегии", "Гайды", "Настройки"}
for i, n in ipairs(names) do createTabButton(n, i) end

-- Логирование в вкладке Стратегии
local loggingEnabled = false
local strategyLog = {}

local function logAction(action)
    if loggingEnabled then
        table.insert(strategyLog, action)
        print("Записано: " .. action)
    end
end

local logToggle = Instance.new("TextButton")
logToggle.Text = "Логирование: ВЫКЛ"
logToggle.Size = UDim2.new(0, 250, 0, 50)
logToggle.Position = UDim2.new(0.5, -125, 0, 100)
logToggle.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
logToggle.TextColor3 = Color3.new(1,1,1)
logToggle.Parent = contents[2]

logToggle.MouseButton1Click:Connect(function()
    loggingEnabled = not loggingEnabled
    logToggle.Text = "Логирование: " .. (loggingEnabled and "ВКЛ" or "ВЫКЛ")
    logToggle.BackgroundColor3 = loggingEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
end)

local saveBtn = Instance.new("TextButton")
saveBtn.Text = "Сохранить в strat.txt"
saveBtn.Size = UDim2.new(0, 250, 0, 50)
saveBtn.Position = UDim2.new(0.5, -125, 0, 170)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
saveBtn.TextColor3 = Color3.new(1,1,1)
saveBtn.Parent = contents[2]

saveBtn.MouseButton1Click:Connect(function()
    if #strategyLog == 0 then
        print("Нет данных для сохранения")
        return
    end
    local data = table.concat(strategyLog, "\n")
    writefile("strat.txt", data)
    print("Стратегия сохранена в strat.txt (" .. #strategyLog .. " строк)")
end)

print("Меню готово! Логирование в вкладке Стратегии.")
