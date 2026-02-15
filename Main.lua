-- Main.lua - Меню с 4 вкладками, draggable, resizable и кнопкой закрытия
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 450, 0, 350)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 2
mainFrame.Active = true
mainFrame.Draggable = false  -- будем делать вручную
mainFrame.Parent = gui

-- Заголовок (для перетаскивания)
local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat | iljakolesnikov2001-rgb"
title.Size = UDim2.new(1, -40, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = mainFrame

-- Кнопка закрытия X
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 40, 0, 50)
closeBtn.Position = UDim2.new(1, -40, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 24
closeBtn.Parent = mainFrame

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Перетаскивание по заголовку
local dragging = false
local dragInput
local dragStart
local startPos

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
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

-- Изменение размера (grip в правом нижнем углу)
local resizeGrip = Instance.new("Frame")
resizeGrip.Size = UDim2.new(0, 20, 0, 20)
resizeGrip.Position = UDim2.new(1, -20, 1, -20)
resizeGrip.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
resizeGrip.Parent = mainFrame

local resizing = false
local resizeStart
local resizeStartSize

resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        resizeStart = input.Position
        resizeStartSize = mainFrame.Size
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
            end
        end)
    end
end)

resizeGrip.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if resizing and input == dragInput then
        local delta = input.Position - resizeStart
        mainFrame.Size = UDim2.new(resizeStartSize.X.Scale, math.max(300, resizeStartSize.X.Offset + delta.X),
                                  resizeStartSize.Y.Scale, math.max(200, resizeStartSize.Y.Offset + delta.Y))
    end
end)

-- Кнопки вкладок и контент (как раньше)
local tabsY = 60
local function createTabButton(name, pos)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Size = UDim2.new(0, 100, 0, 40)
    btn.Position = UDim2.new(0, 10 + pos * 110, 0, tabsY)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = mainFrame
    return btn
end

local contents = {}
for i = 1, 4 do
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 1, -120)
    frame.Position = UDim2.new(0, 10, 0, 110)
    frame.BackgroundTransparency = 1
    frame.Visible = (i == 1)
    frame.Parent = mainFrame
    contents[i] = frame
end

-- Текст для вкладок
local labels = {
    "Добро пожаловать!\nВерсия: 1.0\nАвтор: iljakolesnikov2001-rgb\nЗдесь основная информация.",
    "Выбор стратегий\nПока пусто — добавим позже.",
    "Гайды и инструкции\nСкоро добавим.",
    "Настройки\nАвто-скип и другие опции."
}

for i = 1, 4 do
    local label = Instance.new("TextLabel")
    label.Text = labels[i]
    label.TextColor3 = Color3.new(1,1,1)
    label.BackgroundTransparency = 1
    label.TextSize = 18
    label.TextWrapped = true
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Parent = contents[i]
end

local function switchTab(num)
    for i = 1, 4 do contents[i].Visible = (i == num) end
end

createTabButton("Основная", 0).MouseButton1Click:Connect(function() switchTab(1) end)
createTabButton("Стратегии", 1).MouseButton1Click:Connect(function() switchTab(2) end)
createTabButton("Гайды", 2).MouseButton1Click:Connect(function() switchTab(3) end)
createTabButton("Настройки", 3).MouseButton1Click:Connect(function() switchTab(4) end)

print("Меню готово: перетаскивай за заголовок, меняй размер за правый нижний угол, закрывай X")
