-- Main.lua
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()

local Window = OrionLib:MakeWindow({
    Name = "TDS Auto-Strat | Empty Template",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "TDSAutoStrat"
})

local TabGuides = Window:MakeTab({Name = "Guides", Icon = "rbxassetid://4483345998"})
local TabStrategies = Window:MakeTab({Name = "Strategies", Icon = "rbxassetid://4483345998"})
local TabSettings = Window:MakeTab({Name = "Settings", Icon = "rbxassetid://4483345998"})

TabStrategies:AddButton({
    Name = "Запустить стратегию (пока пусто)",
    Callback = function()
        OrionLib:MakeNotification({Name = "Info", Content = "Стратегия не выбрана!", Time = 5})
    end
})

TabStrategies:AddDropdown({
    Name = "Выбери стратегию",
    Options = {"Нет стратегий"},
    Callback = function(Value) end    
})

OrionLib:Init()
