-- Main.lua
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Rayfield/main/source'))()

local Window = Rayfield:CreateWindow({
    Name = "TDS Auto-Strat | iljakolesnikov2001-rgb",
    LoadingTitle = "TDS Auto-Strat",
    LoadingSubtitle = "by iljakolesnikov2001-rgb",
    ConfigurationSaving = { Enabled = true, FolderName = "TDSAutoStrat" }
})

local TabMain = Window:CreateTab("Основная", 4483362458)
local TabStrat = Window:CreateTab("Стратегии", 4483362458)
local TabGuides = Window:CreateTab("Гайды", 4483362458)
local TabSettings = Window:CreateTab("Настройки", 4483362458)

-- Основная с текстом
TabMain:CreateLabel("Добро пожаловать в TDS Auto-Strat!")
TabMain:CreateLabel("Версия: 1.0")
TabMain:CreateLabel("Автор: iljakolesnikov2001-rgb")
TabMain:CreateLabel("Меню работает! Здесь статистика и инфо.")

-- Стратегии
TabStrat:CreateDropdown({
    Name = "Выбор стратегии",
    Options = {"Crossroads Solo", "Pizza Party Trio", "Badlands Quad"},
    CurrentOption = "Crossroads Solo",
    Callback = function(val) Rayfield:Notify({ Title = "Выбрано", Content = val }) end
})

TabStrat:CreateButton({
    Name = "Запустить",
    Callback = function() Rayfield:Notify({ Title = "Запуск", Content = "Пока не подключено!" }) end
})

-- Гайды и настройки
TabGuides:CreateLabel("Гайды скоро добавим.")
TabSettings:CreateToggle({ Name = "Авто-скип", CurrentValue = false, Callback = function() end })
