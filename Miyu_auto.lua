local ok, err = pcall(function() loadstring(readfile("MiyuDrill.lua"))() end)
pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [Miyu] автозапуск: " .. (ok and "ok" or ("ошибка: " .. tostring(err))) .. "\n")
