-- Autoexecute: локальная копия MiyuGUI (MiyuDrill.lua, без покупок за Robux) вместо загрузки с GitHub.
-- Наши добавки (KingPhoenix.lua) лежат в Autoexecute отдельным файлом.
local ok, err = pcall(function() loadstring(readfile("MiyuDrill.lua"))() end)
if not ok then pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [Miyu] ошибка: " .. tostring(err) .. "\n") end
