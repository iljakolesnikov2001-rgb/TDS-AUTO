-- Main.lua
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Title = "TDS Auto-Strat | iljakolesnikov2001-rgb",
    TabWidth = 160,
    Size = UDim2.fromOffset(650, 550)
})

local TabMain = Window:AddTab({ Title = "Основная" })
local TabStrat = Window:AddTab({ Title = "Стратегии" })
local TabGuides = Window:AddTab({ Title = "Гайды" })
local TabSettings = Window:AddTab({ Title = "Настройки" })

-- Основная вкладка
TabMain:AddLabel("Добро пожаловать в TDS Auto-Strat!")
TabMain:AddLabel("Версия: 1.0")
TabMain:AddLabel("Автор: iljakolesnikov2001-rgb")
TabMain:AddLabel("Скрипт работает! Здесь будет статистика и информация.")

-- Стратегии
TabStrat:AddDropdown({
    Title = "Выбор стратегии",
    Items = {"Crossroads Solo", "Pizza Party Trio", "Badlands Quad", "Wrecked Battlefield"},
    Callback = function(val)
        Luna:Notify({ Title = "Выбрано", Content = val })
    end
})

TabStrat:AddButton({
    Title = "Запустить",
    Callback = function()
        Luna:Notify({ Title = "Запуск", Content = "Стратегия пока не подключена!" })
    end
})

-- Гайды
TabGuides:AddLabel("Пока пусто — добавим позже.")

-- Настройки
TabSettings:AddToggle({ Title = "Авто-скип", Default = true, Callback = function() end })
TabSettings:AddSlider({ Title = "Задержка", Min = 0.1, Max = 5, Default = 1, Callback = function() end })

Luna:Notify({ Title = "Загружено", Content = "Меню готово!" })
