-- Strategies/Example.lua
local Strategy = {}

function Strategy:Run()
    while true do
        wait(1)
        if Library:GetGameState() == "GAME" then
            print("Стратегия запущена, но пока ничего не делает")
        end
    end
end

return Strategy
