-- Main.lua
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Title = "TDS Auto-Strat | My Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 500)
})

local MainTab = Window:AddTab({ Title = "Главная" })
local StratTab = Window:AddTab({ Title = "Стратегии" })
local SettingsTab = Window:AddTab({ Title = "Настройки" })

MainTab:AddLabel("Привет! Luna UI работает ✅")
MainTab:AddLabel("Автор: твой ник")

StratTab:AddButton({
    Title = "Тест кнопка (пока ничего)",
    Callback = function()
        Luna:Notify({ Title = "Тест", Content = "Кнопка работает!" })
    end
})

StratTab:AddDropdown({
    Title = "Выбери карту",
    Items = {"Crossroads", "Pizza Party", "Badlands", "Wrecked Battlefield"},
    Callback = function(value)
        Luna:Notify({ Title = "Выбрано", Content = value })
    end
})

SettingsTab:AddToggle({
    Title = "Авто-скип волн",
    Default = false,
    Callback = function(state)
        print("Авто-скип: " .. tostring(state))
    end
})

SettingsTab:AddSlider({
    Title = "Задержка (сек)",
    Min = 0.1,
    Max = 5,
    Default = 1,
    Callback = function(value)
        print("Задержка: " .. value)
    end
})
