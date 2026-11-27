local ok, err = pcall(function() loadstring(readfile("MiyuDrill.lua"))() end)
pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [Miyu] автозапуск: " .. (ok and "ok" or ("ошибка: " .. tostring(err))) .. "\n")
-- только чтение: что лежит в стартовом ящике (сохранённые вещи), ничего не забирает
task.spawn(function()
    task.wait(12)
    local ok, items = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        return RS.Packages._Index["sleitnick_knit@1.4.6"].knit.Services.PlayerService.RF.GetCrateItems:InvokeServer()
    end)
    if ok and type(items) == "table" then
        local n = {}
        for _, it in ipairs(items) do n[#n + 1] = tostring(type(it) == "table" and it.Name or it) end
        pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [Crate] в ящике: " .. table.concat(n, ", ") .. "\n")
    end
end)
