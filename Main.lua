-- Main.lua - Простое меню с 4 вкладками
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 450, 0, 350)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = gui

-- Заголовок
local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat | iljakolesnikov2001-rgb"
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = mainFrame

-- Кнопки вкладок
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

-- Контейнеры для вкладок
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

-- Вкладка 1: Основная
local labelMain = Instance.new("TextLabel")
labelMain.Text = "Добро пожаловать!\nВерсия: 1.0\nАвтор: iljakolesnikov2001-rgb\nЗдесь основная информация."
labelMain.TextColor3 = Color3.new(1,1,1)
labelMain.BackgroundTransparency = 1
labelMain.TextSize = 18
labelMain.Size = UDim2.new(1, 0, 1, 0)
labelMain.Parent = contents[1]

-- Вкладка 2: Стратегии
local labelStrat = Instance.new("TextLabel")
labelStrat.Text = "Выбор стратегий\nПока пусто — добавим позже."
labelStrat.TextColor3 = Color3.new(1,1,1)
labelStrat.BackgroundTransparency = 1
labelStrat.TextSize = 18
labelStrat.Size = UDim2.new(1, 0, 1, 0)
labelStrat.Parent = contents[2]

-- Вкладка 3: Гайды
local labelGuides = Instance.new("TextLabel")
labelGuides.Text = "Гайды и инструкции\nСкоро добавим."
labelGuides.TextColor3 = Color3.new(1,1,1)
labelGuides.BackgroundTransparency = 1
labelGuides.TextSize = 18
labelGuides.Size = UDim2.new(1, 0, 1, 0)
labelGuides.Parent = contents[3]

-- Вкладка 4: Настройки
local labelSettings = Instance.new("TextLabel")
labelSettings.Text = "Настройки\nАвто-скип: пока нет."
labelSettings.TextColor3 = Color3.new(1,1,1)
labelSettings.BackgroundTransparency = 1
labelSettings.TextSize = 18
labelSettings.Size = UDim2.new(1, 0, 1, 0)
labelSettings.Parent = contents[4]

-- Функция переключения вкладок
local function switchTab(num)
    for i = 1, 4 do
        contents[i].Visible = (i == num)
    end
end

-- Кнопки
createTabButton("Основная", 0).MouseButton1Click:Connect(function() switchTab(1) end)
createTabButton("Стратегии", 1).MouseButton1Click:Connect(function() switchTab(2) end)
createTabButton("Гайды", 2).MouseButton1Click:Connect(function() switchTab(3) end)
createTabButton("Настройки", 3).MouseButton1Click:Connect(function() switchTab(4) end)

print("Меню с 4 вкладками загружено!")
