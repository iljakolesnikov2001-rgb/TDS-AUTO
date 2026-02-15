-- Main.lua
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Title = "TDS Auto-Strat | My Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460)
})

local MainTab = Window:AddTab({ Title = "Main" })
local SettingsTab = Window:AddTab({ Title = "Settings" })

MainTab:AddLabel("Luna UI загружена успешно!")

MainTab:AddButton({
    Title = "Тест стратегии",
    Callback = function()
        Luna:Notify({ Title = "Info", Content = "Стратегия пока пустая!" })
    end
})

MainTab:AddDropdown({
    Title = "Выбери карту",
    Items = {"Crossroads", "Pizza Party", "Badlands"},
    Callback = function(value)
        print("Выбрана карта: " .. value)
    end
})

SettingsTab:AddToggle({
    Title = "Авто-скип волн",
    Default = false,
    Callback = function(state)
        print("Авто-скип: " .. tostring(state))
    end
})
