-- KingPhoenix.lua — дополнение к MiyuGUI (кладётся в Autoexecute рядом с хабом).
-- 1) В начале забега забирает сохранённые вещи из стартового ящика (PlayerService.SetLoadout, как в DrillFarm).
-- 2) Вещи короля/феникса, лежащие рядом: броню надевает (Interact), оружие/кирки подбирает (Pickup).
local function log(s) pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S") .. " [KingPhoenix] " .. s .. "\n") end
if not game:IsLoaded() then game.Loaded:Wait() end
local RS = game:GetService("ReplicatedStorage")
local t0 = os.clock()
while not RS:FindFirstChild("DrillService", true) and os.clock() - t0 < 90 do task.wait(1) end
if not RS:FindFirstChild("DrillService", true) then return end -- лобби
local player = game:GetService("Players").LocalPlayer
local KEYS = { "King", "Phoenix", "GoblinLord", "Goblin Lord" }

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

-- 2) вещи короля/феникса в мире (дроп с боссов)
local function isTarget(it)
	local s = (it.Name .. " " .. tostring(it:GetAttribute("DisplayName") or "")):lower()
	for _, k in ipairs(KEYS) do if s:find(k:lower(), 1, true) then return true end end
	return false
end
local tried = {}
while true do
	task.wait(1)
	local folder, r = workspace:FindFirstChild("Items"), hrp()
	for _, it in ipairs(folder and r and folder:GetChildren() or {}) do
		local ok, p = pcall(function() return it:GetPivot().Position end)
		if ok and (tried[it] or 0) < os.clock() and isTarget(it) and (p - r.Position).Magnitude < 150 then
			tried[it] = os.clock() + 20
			local back = r.CFrame
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(p + Vector3.new(0, 3, 0))
			task.wait(0.3)
			local name = it:GetAttribute("DisplayName") or it.Name
			if it:GetAttribute("Category") == "Armor" then
				call("InteractionService", "Interact", it) -- броня надевается через E, Pickup лишь кладёт в рюкзак
			else
				call("CarryInventoryService", "Pickup", it)
			end
			task.wait(0.8)
			log(("%s: %s"):format(name, it:IsDescendantOf(folder) and "не взял, повтор через 20 с" or "взял"))
			r = hrp()
			if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = back end
		end
	end
end
