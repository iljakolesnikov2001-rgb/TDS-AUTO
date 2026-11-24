-- DrillFarm autoexec: после телепорта (новый забег) сам грузит скрипт и включает Auto
local function log(s) pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [Autoexec] " .. s .. "\n") end
log("старт, place " .. tostring(game.PlaceId))
if not game:IsLoaded() then game.Loaded:Wait() end
-- сервисы игры реплицируются не сразу: ждём до 90 с (раньше была одна проверка через 8 с — и молчаливый выход)
local RS = game:GetService("ReplicatedStorage")
local t0 = os.clock()
while not RS:FindFirstChild("DrillService", true) and os.clock() - t0 < 90 do task.wait(1) end
if not RS:FindFirstChild("DrillService", true) then log("DrillService не найден за 90 с — не та игра/лобби, не запускаю") return end
task.wait(3)
if not isfile("DrillFarm.lua") then log("нет DrillFarm.lua") return end
-- загрузка может зависнуть (сервер не ответил при входе): ждём 40 с, пишем, где висит, и пробуем снова (до 3 раз);
-- новая копия сама гасит старую (DF_Token)
for try = 1, 3 do
	local f, e = loadstring(readfile("DrillFarm.lua"))
	if not f then log("SYNTAX " .. tostring(e)) return end
	getgenv().DF = nil
	getgenv().DF_PrevState = { Auto = true }
	log("загружаю DrillFarm (попытка " .. try .. ")")
	local co = coroutine.create(function()
		local ok, err = pcall(f)
		if not ok then log("RUNERR " .. tostring(err)) end
	end)
	task.spawn(co)
	local t1 = os.clock()
	while not getgenv().DF and coroutine.status(co) ~= "dead" and os.clock() - t1 < 40 do task.wait(0.5) end
	if getgenv().DF then return end
	if coroutine.status(co) == "dead" then return end -- упал с ошибкой (RUNERR выше) — повтор не поможет
	log("загрузка зависла на 40 с: " .. tostring(debug.traceback(co)):gsub("%s+", " "):sub(1, 400))
end
log("скрипт так и не загрузился за 3 попытки")
