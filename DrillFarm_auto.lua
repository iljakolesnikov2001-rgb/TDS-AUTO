-- DrillFarm autoexec: после телепорта (новый забег) сам грузит скрипт и включает Auto
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(8)
if not game:GetService("ReplicatedStorage"):FindFirstChild("DrillService", true) then return end -- не та игра
if not isfile("DrillFarm.lua") then return end
local function log(s) appendfile("DrillFarm.log", os.date("%H:%M:%S") .. " [Autoexec] " .. s .. "\n") end
-- загрузка может зависнуть (сервер не ответил при входе): ждём 40 с, пишем, где висит, и пробуем снова (до 3 раз);
-- новая копия сама гасит старую (DF_Token)
for try = 1, 3 do
	local f, e = loadstring(readfile("DrillFarm.lua"))
	if not f then appendfile("DrillFarm.log", "AUTOEXEC SYNTAX " .. tostring(e) .. "\n") return end
	getgenv().DF = nil
	getgenv().DF_PrevState = { Auto = true }
	log("загружаю DrillFarm (попытка " .. try .. ")")
	local co = coroutine.create(function()
		local ok, err = pcall(f)
		if not ok then appendfile("DrillFarm.log", "RUNERR " .. tostring(err) .. "\n") end
	end)
	task.spawn(co)
	local t0 = os.clock()
	while not getgenv().DF and coroutine.status(co) ~= "dead" and os.clock() - t0 < 40 do task.wait(0.5) end
	if getgenv().DF then return end
	if coroutine.status(co) == "dead" then return end -- упал с ошибкой (RUNERR выше) — повтор не поможет
	log("загрузка зависла на 40 с: " .. tostring(debug.traceback(co)):gsub("%s+", " "):sub(1, 400))
end
log("скрипт так и не загрузился за 3 попытки")
