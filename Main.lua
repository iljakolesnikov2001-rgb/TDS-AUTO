-- Main.lua - Logging + Save to strat.txt
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

-- Title
local title = Instance.new("TextLabel")
title.Text = "TDS Auto-Strat"
title.Size = UDim2.new(1, -60, 0, 60)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220, 100, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.Parent = mainFrame

-- Close button
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

-- Dragging and resizing (как раньше, работает)

-- ... (оставляю код перетаскивания и ресайза из предыдущей версии, он идентичен)

-- Logging system
local loggingEnabled = false
local strategyLog = {}  -- таблица логов

local function logAction(action)
    if loggingEnabled then
        table.insert(strategyLog, action)
        print("Logged: " .. action)
    end
end

-- Пример использования (потом подключи к реальным функциям)
-- logAction("Place Farm at CFrame.new(...) wave 1")

-- Tab panel and content (как раньше)

-- Вкладка Strategies - новые элементы
local stratContent = contents[2]  -- вторая вкладка

local logToggle = Instance.new("TextButton")
logToggle.Text = "Logging: OFF"
logToggle.Size = UDim2.new(0, 200, 0, 50)
logToggle.Position = UDim2.new(0.5, -100, 0, 20)
logToggle.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
logToggle.TextColor3 = Color3.new(1,1,1)
logToggle.Parent = stratContent

logToggle.MouseButton1Click:Connect(function()
    loggingEnabled = not loggingEnabled
    logToggle.Text = "Logging: " .. (loggingEnabled and "ON" or "OFF")
    logToggle.BackgroundColor3 = loggingEnabled and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
end)

local saveBtn = Instance.new("TextButton")
saveBtn.Text = "Save Strategy to strat.txt"
saveBtn.Size = UDim2.new(0, 300, 0, 50)
saveBtn.Position = UDim2.new(0.5, -150, 0, 100)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
saveBtn.TextColor3 = Color3.new(1,1,1)
saveBtn.Parent = stratContent

saveBtn.MouseButton1Click:Connect(function()
    if #strategyLog == 0 then
        print("No data to save")
        return
    end
    
    local data = table.concat(strategyLog, "\n")
    writefile("strat.txt", data)
    print("Strategy saved to strat.txt (" .. #strategyLog .. " lines)")
end)

local clearBtn = Instance.new("TextButton")
clearBtn.Text = "Clear Log"
clearBtn.Size = UDim2.new(0, 150, 0, 50)
clearBtn.Position = UDim2.new(0.5, -75, 0, 170)
clearBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
clearBtn.TextColor3 = Color3.new(1,1,1)
clearBtn.Parent = stratContent

clearBtn.MouseButton1Click:Connect(function()
    strategyLog = {}
    print("Log cleared")
end)

print("Logging system ready! Use logAction() to record actions.")
