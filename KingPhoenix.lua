-- KingPhoenix.lua — дополнение к MiyuGUI (кладётся в Autoexecute рядом с хабом).
-- 1) В начале забега забирает сохранённые вещи из стартового ящика (PlayerService.SetLoadout, как в DrillFarm).
local function log(s) pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [KingPhoenix] " .. s .. "\n") end
if not game:IsLoaded() then game.Loaded:Wait() end
local RS = game:GetService("ReplicatedStorage")
local t0 = os.clock()
while not RS:FindFirstChild("DrillService", true) and os.clock() - t0 < 90 do task.wait(1) end
if not RS:FindFirstChild("DrillService", true) then return end -- лобби
local player = game:GetService("Players").LocalPlayer

local cache = {}
local function knit(service, name)
	local c = cache[service .. "." .. name]
	if c and c.Parent then return c end
	local idx = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("_Index")
	for _, d in ipairs(idx and idx:GetDescendants() or {}) do
		if d.Name == name and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == service then
			cache[service .. "." .. name] = d
			return d
		end
	end
end
local function call(service, name, ...)
	local rf = knit(service, name)
	if not rf then return end
	local ok, res = pcall(rf.InvokeServer, rf, ...)
	if ok then return res end
end
local function hrp() local c = player.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- 1) стартовый ящик: лучший по Value предмет на каждый слот (больше игра не даёт взять)
task.spawn(function()
	task.wait(5)
	local coins = call("CurrencyService", "GetCurrency")
	if type(coins) ~= "number" or coins > 100 then return end -- не начало забега
	local items = call("PlayerService", "GetCrateItems")
	if type(items) ~= "table" or #items == 0 then return end
	local DB = require(RS.Shared.ItemDatabase)
	local best = {}
	for _, it in ipairs(items) do
		local n = type(it) == "table" and it.Name or it
		local key = type(it) == "table" and (it.Key or n) or n
		local i = DB.Get(n); local a = i and i.Attributes or {}
		local slot = (a.Category == "Armor" and a.ArmorType) or ((a.Category == "Melee" or a.Category == "Pickaxe") and a.Category)
		if slot and (not best[slot] or (a.Value or 0) > best[slot].v) then best[slot] = { k = key, v = a.Value or 0 } end
	end
	local lo, names = {}, {}
	for _, b in pairs(best) do lo[b.k] = 1; table.insert(names, b.k) end
	if #names == 0 then return end
	local ok = call("PlayerService", "SetLoadout", lo)
	log(("из ящика: %s — %s"):format(table.concat(names, ", "), ok and "взял" or "не вышло"))
end)
-- вещи Kings/Phoenix из сундуков собирает сам хаб (патч S.kpGearSweep в MiyuDrill.lua) — тут не дёргаем персонажа
