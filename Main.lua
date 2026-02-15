-- Main.lua
local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Title = "TDS Auto-Strat | My Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 520)
})

-- 4 вкладки
local TabMain = Window:AddTab({ Title = "Основная" })
local TabSelect = Window:AddTab({ Title = "Выбор стратегий" })
local TabGuides = Window:AddTab({ Title = "Гайды" })
local TabSettings = Window:AddTab({ Title = "Настройки" })

-- Основная вкладка с текстом
TabMain:AddLabel("Добро пожаловать в TDS Auto-Strat!")
TabMain:AddLabel("Версия: 1.0")
TabMain:AddLabel("Автор: iljakolesnikov2001-rgb")
TabMain:AddLabel("Здесь будет основная информация и статистика.")

-- Вкладка выбора стратегий
TabSelect:AddDropdown({
    Title = "Выбери стратегию",
    Items = {"Нет стратегий", "Crossroads Solo", "Pizza Party Trio", "Badlands Quad"},
    Callback = function(value)
        Luna:Notify({ Title = "Выбрано", Content = value })
    end
})

TabSelect:AddButton({
    Title = "Запустить стратегию",
    Callback = function()
        Luna:Notify({ Title = "Info", Content = "Стратегия пока не подключена!" })
    end
})

-- Гайды (пусто пока)
TabGuides:AddLabel("Здесь будут гайды и описания.")

-- Настройки
TabSettings:AddToggle({
    Title = "Авто-скип волн",
    Default = false,
    Callback = function(state) end
})
