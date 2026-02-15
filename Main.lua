-- Main.lua - Неоново-фиолетовое меню с адаптивными кнопками, скруглёнными углами и неоновым стилем
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 400)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 0, 50)  -- тёмный фиолетовый фон
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = gui

-- Скругление углов
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

-- Неоновый обвод
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(180, 50, 255)  -- неоновый фиолетовый
stroke.Transparency = 0.3
stroke.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat | iljakolesnikov2001-rgb"
title.Size = UDim2.new(1, -50, 0, 60)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220, 100, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = mainFrame

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -55, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 100)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 28
closeBtn.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

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
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Ресайз (правый нижний угол)
local resizeGrip = Instance.new("Frame")
resizeGrip.Size = UDim2.new(0, 25, 0, 25)
resizeGrip.Position = UDim2.new(1, -25, 1, -25)
resizeGrip.BackgroundColor3 = Color3.fromRGB(180, 50, 255)
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
        mainFrame.Size = UDim2.new(resizeStartSize.X.Scale, math.max(400, resizeStartSize.X.Offset + delta.X),
                                  resizeStartSize.Y.Scale, math.max(300, resizeStartSize.Y.Offset + delta.Y))
    end
end)

resizeGrip.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = false
    end
end)

-- Панель вкладок (адаптивная)
local tabPanel = Instance.new("Frame")
tabPanel.Size = UDim2.new(1, 0, 0, 60)
tabPanel.Position = UDim2.new(0, 0, 0, 60)
tabPanel.BackgroundTransparency = 1
tabPanel.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabPanel

-- Контент вкладок
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -130)
contentFrame.Position = UDim2.new(0, 10, 0, 120)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local contents = {}
for i = 1, 4 do
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = (i == 1)
    frame.Parent = contentFrame
    contents[i] = frame
end

-- Текст для вкладок
local tabTexts = {
    "Добро пожаловать!\nВерсия: 1.0\nАвтор: iljakolesnikov2001-rgb\nНеоновый стиль активирован!",
    "Выбор стратегий\nПока пусто — добавим реальные страты.",
    "Гайды и инструкции\nСкоро здесь будут гайды.",
    "Настройки\nАвто-скип и другие опции."
}

for i = 1, 4 do
    local label = Instance.new("TextLabel")
    label.Text = tabTexts[i]
    label.TextColor3 = Color3.fromRGB(220, 100, 255)
    label.BackgroundTransparency = 1
    label.TextSize = 20
    label.TextWrapped = true
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Parent = contents[i]
end

-- Создание кнопок вкладок
local tabNames = {"Основная", "Стратегии", "Гайды", "Настройки"}

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.AutoButtonColor = false
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 2
    btnStroke.Color = Color3.fromRGB(200, 80, 255)
    btnStroke.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        for j = 1, 4 do contents[j].Visible = (j == index) end
    end)
    
    btn.Parent = tabPanel
    return btn
end

for i, name in ipairs(tabNames) do
    createTabButton(name, i)
end

print("
