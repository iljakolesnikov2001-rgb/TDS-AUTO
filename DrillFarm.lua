-- DrillFarm.lua — Drill to Earth's Core
-- Одна кнопка «Авто-фарм»: бур едет сам, по дороге скрипт открывает сундуки, собирает лут и топливо,
-- заходит в подземелья, продаёт добычу, качает урон бура, заправляет его и прячется под землю при низком HP.

----------------------------------------------------------------- CONFIG
local CONFIG = {
	-- Авто-фарм
	WorkRadius       = 300,  -- сундуки/лут/монстры ищем в этом радиусе от бура (дальше игра телепортирует к буру)
	GateStopDist     = 300,  -- заходим в подземелья с воротами ближе этого к буру (по горизонтали: ворота стоят сбоку)
	WallStopDist     = 110,  -- перед финальной стеной (при ударе идёт волна врагов) ждём полное HP
	GuardHpPct       = 40,   -- HP ниже — прячемся под землю
	SafeHpPct        = 60,   -- выходим из укрытия, когда HP восстановилось
	FuelTargetPct    = 50,   -- заправляем, когда топлива меньше (если в рюкзаке есть канистра)
	FuelSearchRadius = 500,  -- топливо почти кончилось, канистр нет — ищем дальше
	DriveMinFuel     = 3,
	MedkitStock      = 6,     -- держать аптечек в запасе (покупаются в магазине крепости)
	BandageStock     = 20,    -- бинтов (дешёвые, 10 монет) держать до стольких, сверх MedkitStock
	ShopRestock      = 300,   -- каждый магазин обновляет товар раз в 5 минут
	BandageRunDist   = 6000,  -- за бинтами в запомненный магазин летаем не дальше этого от бура
	SellFarPct       = 85,   -- сумка заполнена на N% — продаём даже на дальнем столе
	SaveGearOnStall  = true, -- бур не продвигается N минут — уносим лучшее через алтарь Save Gear (бесплатно, конец захода)
	SaveGearStallMin = 8,
	SellAtPct        = 70,   -- продаём, когда сумка заполнена на N% и стол продажи рядом с буром
	DungeonRadius    = 250,  -- в подземелье: монстры/сундуки/лут в этом радиусе
	KillRadius       = 80,   -- Kill Aura
	KillTimeout      = 30,   -- сек на одного монстра
	ChestRadius      = 150,
	ItemsMinValue    = 0,
	IgnoredItems     = { "Rock", "DeathChest" },
	-- порядок покупки апгрейдов бура (сначала урон по стенам). Карточки за Robux не покупаются никогда.
	-- порядок покупки апгрейдов бура (тир-лист): сначала строго по списку,
	UpgradePriority  = { "RPMOverclock", "DrillPower", "PowerBurst", "HealthRegen", "UltraDrill", "MoneyDrill", "MegaDrill", "PowerSlam" },
	-- затем из этой группы — тот, у которого уровень на буре сейчас меньше всех; остальные — в последнюю очередь
	UpgradeBalanced  = { "TeamHealth", "DrillDefense", "EngineOverdrive", "HealthRegen", "SackStorage",
		"TeamPickaxeDamage", "TeamMeleeDamage", "DriveSpeed" },
	UpgradeNever     = { "CartExtension", "PowerDrive" }, -- никогда не покупать (вагоны замедляют бур)

	-- Фарм руды (отдельный тумблер)
	OreNames         = {},   -- типы руды (SessionOreType: "Coal", "Iron"...); пусто = любая
	MaxTimePerOre    = 8,
	OreSearchRadius  = 150,
	AutoOreRadius    = 80,   -- авто-фарм: копать руду не дальше этого от бура (0 = не копать)
	PickaxeName      = "Pickaxe",

	BagCountAttr     = "CarryUsage",
	BagCapacityAttr  = "CarryCapacity",
	DrillName        = "Drill",
	FuelAttr         = "Fuel",
	MaxFuelAttr      = "MaxFuel",
	GateName         = "DungeonGate_",
	GatePromptKey    = "Enter",
	MonsterFilter    = {},   -- подсветка: пусто = все монстры
	HighlightColor   = Color3.fromRGB(255, 60, 60),
	SellKeepRarity   = { "Legendary", "Mythic", "Exotic", "Secret", "Divine" }, -- не продавать
	SellKeepCategory = { "Fuel", "Consumable" },  -- топливо не продаём
	MoveSpeed        = 540,  -- студов/сек при перелёте
	PickupDelay      = 0.05,
	Tick             = 0.25,
}

----------------------------------------------------------------- SERVICES
local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local VIM      = game:GetService("VirtualInputManager")
local player   = Players.LocalPlayer

local Running = true
local Selling = false -- пока идёт продажа, остальные функции ждут
local Connections = {}
-- новая загрузка скрипта гасит старую копию, даже если та упала с ошибкой и не дошла до shutdown
do
	local token = {}
	if getgenv then getgenv().DF_Token = token end
	task.spawn(function()
		while Running do
			task.wait(1)
			if getgenv and getgenv().DF_Token ~= token then
				Running = false
				for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
			end
		end
	end)
end
local State = { Auto=false, NoDrive=false, DungeonFarm=false, Farm=false, KillAura=false, Noclip=false, Highlight=false, SkipCutscenes=true }
-- работает ли «мозг» (авто-фарм или фарм данжей) — по этому флагу продолжаются бой, укрытие, сбор
local function busy() return State.Auto or State.DungeonFarm end
if getgenv and getgenv().DF_PrevState then
	for k, v in pairs(getgenv().DF_PrevState) do State[k] = v end
	getgenv().DF_PrevState, getgenv().DF_Reloading = nil, nil
end
local Stats = { chests=0, items=0, kills=0, dungeons=0, upgrades=0, hides=0, refuels=0, sells=0, start=nil }
local Phase = "Выключено"
local function collecting() return busy() end


-- Статус: печать в F9 + строка внизу меню (видно и без консоли)
local StatusLabel
local function status(msg)
	print(msg)
	if StatusLabel then StatusLabel.Text = msg end
	-- лог в файл экзекутора (Delta/Workspace/DrillFarm.log) — удобно смотреть вне игры
	if appendfile then pcall(appendfile, "DrillFarm.log", os.date("%H:%M:%S ") .. tostring(msg) .. "\n") end
end

-- Отладка: если в Workspace экзекутора появился DF_cmd.lua — выполняем его и пишем результат в лог.
-- shortcut: локальный мост для теста через adb; выключить, поставив DF_BRIDGE = false
local DF_BRIDGE = true
if DF_BRIDGE and isfile and readfile and delfile and loadstring then
	task.spawn(function()
		while Running do
			if isfile("DF_cmd.lua") then
				local src = readfile("DF_cmd.lua"); delfile("DF_cmd.lua")
				local f, err = loadstring(src)
				local ok, res = false, err
				if f then ok, res = pcall(f) end
				status("[CMD] " .. (ok and "ok: " or "ошибка: ") .. tostring(res))
			end
			task.wait(0.5)
		end
	end)
end

-- Анти-AFK: перемещения через CFrame Roblox не считает активностью — без этого кик через 20 минут (278)
do
	local VU = game:GetService("VirtualUser")
	table.insert(Connections, player.Idled:Connect(function()
		pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
	end))
end

----------------------------------------------------------------- HELPERS
local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function hasKey(str, list)
	str = string.lower(str)
	for _, k in ipairs(list) do
		if string.find(str, string.lower(k), 1, true) then return true end
	end
	return false
end

local function pos(obj)
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Attachment") then return obj.WorldPosition end
	if obj:IsA("Model") then
		local ok, cf = pcall(obj.GetPivot, obj)
		if ok then return cf.Position end
	end
end

local function dist(obj)
	local r, p = hrp(), pos(obj)
	return (r and p) and (r.Position - p).Magnitude or math.huge
end

local function tp(obj, offset)
	local r, p = hrp(), pos(obj)
	if r and p then r.CFrame = CFrame.new(p + (offset or Vector3.new(0, 3, 0))) end
end

-- Плавный перелёт (вместо мгновенного ТП); возвращает false, если прервали
local Moving = false -- пока скрипт двигает персонажа, включён ноклип
local function moveTo(obj, stillOk, targetPos)
	local r, p = hrp(), pos(obj)
	if not (r and p) then return false end
	Moving = true
	local okc, ok = pcall(function()
	local target = targetPos or (p + Vector3.new(0, 3, 0))
	-- сидя за рулём телепорт не сдвигает персонажа: встаём, иначе цикл крутится вечно, пока нас бьют
	local hm = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hm and hm.SeatPart then hm.Sit = false; task.wait(0.15) end
	local t0, limit = os.clock(), 3 + (target - r.Position).Magnitude / (CONFIG.MoveSpeed * 0.5)
	while true do
		r = hrp()
		if not r or not obj.Parent or (stillOk and not stillOk()) or os.clock() - t0 > limit then return false end
		local d = target - r.Position
		if d.Magnitude < 3 then return true end
		local step = math.min(d.Magnitude, CONFIG.MoveSpeed * 0.05)
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.new(r.Position + d.Unit * step)
		task.wait(0.05)
	end
	end)
	Moving = false
	return okc and ok
end

-- ТП к дрели в свободную точку (сзади/сбоку/сверху), чтобы не застрять внутри модели
local function tpToDrill(drill)
	local r = hrp()
	if not (r and drill) then return false end
	local ok, cf, size = pcall(function() return drill:GetBoundingBox() end)
	if not ok then cf, size = CFrame.new(pos(drill) or r.Position), Vector3.new(10, 10, 10) end
	local c = player.Character
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c, drill }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { c }
	local L, R = cf.LookVector, cf.RightVector
	local cands = {
		cf.Position - L * (size.Z / 2 + 6), cf.Position + L * (size.Z / 2 + 6),
		cf.Position - R * (size.X / 2 + 6), cf.Position + R * (size.X / 2 + 6),
		cf.Position + Vector3.new(0, size.Y / 2 + 4, 0),
	}
	for idx, p in ipairs(cands) do
		local spot = p
		if idx < 5 then
			local hit = workspace:Raycast(p + Vector3.new(0, size.Y / 2, 0), Vector3.new(0, -size.Y - 20, 0), params)
			if not hit then spot = nil else spot = hit.Position + Vector3.new(0, 3, 0) end
		end
		if spot and #workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(2, 4, 2), op) == 0 then
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(spot, Vector3.new(cf.Position.X, spot.Y, cf.Position.Z))
			return true
		end
	end
	r.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 + 4, 0)) -- запасной вариант
	return true
end

local function attr(name)
	local c = player.Character
	return player:GetAttribute(name) or (c and c:GetAttribute(name))
end

-- Промпт: на время снимаем удержание/прямую видимость/дистанцию (мобильные экзекуторы
-- часто игнорируют HoldDuration), жмём fireproximityprompt, а если не сработало — "руками".
local function usePrompt(pr, done)
	local hold, los, maxd = pr.HoldDuration, pr.RequiresLineOfSight, pr.MaxActivationDistance
	pcall(function() pr.HoldDuration = 0; pr.RequiresLineOfSight = false; pr.MaxActivationDistance = math.max(maxd, 30) end)
	if fireproximityprompt then pcall(fireproximityprompt, pr); task.wait(0.4) end
	if not (done and done()) and pr.Parent then
		pcall(function() pr:InputHoldBegin(); task.wait(0.1); pr:InputHoldEnd() end)
		task.wait(0.3)
	end
	pcall(function() pr.HoldDuration, pr.RequiresLineOfSight, pr.MaxActivationDistance = hold, los, maxd end)
	return done == nil or done()
end

local function firePrompt(obj, key)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("ProximityPrompt") and (not key
			or hasKey(d.Name, {key}) or hasKey(d.ActionText, {key})) then
			usePrompt(d)
			return true
		end
	end
	return false
end

----------------------------------------------------------------- LEARN
-- Подсматриваем, каким remote игра САМА подбирает предмет / открывает сундук,
-- когда игрок делает это руками, и потом повторяем так же. Нужен hookmetamethod.
local Learned = {} -- kind ("item"/"chest") -> { remote, method, args, idx, how, partName }
local function chestNode(inst)
	-- мимики — это монстры (Workspace.Npc, NpcFaction), не сундуки
	if workspace:FindFirstChild("Npc") and inst:IsDescendantOf(workspace.Npc) then return end
	-- состояние (ChestOpenState/Locked) висит на ChestNode с SessionChestId, а не на меше "Chest"
	local n, first = inst, nil
	for _ = 1, 6 do
		if not n or n == workspace then break end
		if n:GetAttribute("NpcFaction") then return end
		if n:GetAttribute("SessionChestId") then return n end
		if not first and (n:GetAttribute("RuntimeChestModel") or hasKey(n.Name, { "Chest", "Crate" })) then first = n end
		n = n.Parent
	end
	return first
end
local function itemNode(inst)
	local n = inst
	for _ = 1, 6 do
		if not n or n == workspace then return end
		if n:GetAttribute("SessionSnapshotItemId") then return n end
		n = n.Parent
	end
end
local function refOf(v)
	if typeof(v) == "Instance" and v:IsDescendantOf(workspace) then
		local n = itemNode(v)
		-- предмет уже в руках/на персонаже (EquipTool, Drop...) — это не подбор с земли
		local holder = n and n:FindFirstAncestorOfClass("Model")
		if n and holder and Players:GetPlayerFromCharacter(holder) then return end
		if n then return "item", n, v == n and "inst" or "part" end
		n = chestNode(v)
		if n then return "chest", n, v == n and "inst" or "part" end
	elseif type(v) == "string" and workspace:FindFirstChild("Items") then
		for _, it in ipairs(workspace.Items:GetChildren()) do
			if it:GetAttribute("SessionSnapshotItemId") == v then return "item", it, "id" end
		end
	end
end
local function changed(kind, node)
	if not node.Parent or not node:IsDescendantOf(workspace) then return true end
	if kind == "item" then
		local m = node:FindFirstAncestorOfClass("Model")
		return m ~= nil and Players:GetPlayerFromCharacter(m) ~= nil
	end
	local st = node:GetAttribute("ChestOpenState")
	return st ~= nil and st ~= "Idle"
end
local function learnFrom(remote, method, args)
	-- сундук смерти забирается своим вызовом (TakeAllItems) — это не способ подбора обычных предметов
	if remote:GetFullName():find("DeathChest", 1, true) then return end
	for i = 1, args.n do
		local kind, node, how = refOf(args[i])
		-- во время продажи предметы со стола исчезают сами — не путать это с подбором
		if kind == "item" and Selling then return end
		if kind then
			task.wait(1.5) -- засчитываем, только если предмет реально подобрался / сундук открылся
			if changed(kind, node) then
				Learned[kind] = { remote = remote, method = method, args = args, idx = i, how = how,
					partName = how == "part" and args[i].Name or nil }
				status(("[Learn] %s: %s, аргумент #%d (%s)"):format(kind, remote:GetFullName(), i, how))
			end
			return
		end
	end
end
if hookmetamethod and getnamecallmethod then
	local old
	old = hookmetamethod(game, "__namecall", (newcclosure or function(f) return f end)(function(self, ...)
		local m = getnamecallmethod()
		if Running and (m == "InvokeServer" or m == "FireServer") and not (checkcaller and checkcaller()) then
			local args = table.pack(...)
			task.spawn(pcall, learnFrom, self, m, args)
			if getgenv().DF_SPY then -- отладка: лог всех вызовов remote игрой
				task.spawn(pcall, function()
					local t = {}
					for i = 1, args.n do
						local v = args[i]
						t[i] = typeof(v) == "Instance" and v:GetFullName() or typeof(v) == "table" and "{table}" or tostring(v)
					end
					status("[SPY] " .. self.Name .. ":" .. m .. "(" .. table.concat(t, ", ") .. ")")
				end)
			end
		end
		return old(self, ...)
	end))
end
local function replay(kind, node)
	local L = Learned[kind]
	if not (L and L.remote.Parent) then return false end
	local args = table.clone(L.args)
	if L.how == "inst" then args[L.idx] = node
	elseif L.how == "id" then args[L.idx] = node:GetAttribute("SessionSnapshotItemId")
	else args[L.idx] = node:FindFirstChild(L.partName, true) or node:FindFirstChildWhichIsA("BasePart", true) end
	task.spawn(pcall, function()
		if L.method == "InvokeServer" then L.remote:InvokeServer(table.unpack(args, 1, args.n))
		else L.remote:FireServer(table.unpack(args, 1, args.n)) end
	end)
	for _ = 1, 8 do task.wait(0.15); if changed(kind, node) then return true end end
	return false
end

local function touch(part)
	local r = hrp()
	if r and firetouchinterest and part:IsA("BasePart") then
		firetouchinterest(r, part, 0); firetouchinterest(r, part, 1)
	end
end

local function findAll(pred)
	local out = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if pred(d) then table.insert(out, d) end
	end
	return out
end

local function nearest(list, radius)
	local best, bd = nil, (radius and radius > 0) and radius or math.huge
	for _, o in ipairs(list) do
		local d = dist(o)
		if d < bd then best, bd = o, d end
	end
	return best
end

local function isCharacter(m)
	return Players:GetPlayerFromCharacter(m) ~= nil
end

----------------------------------------------------------------- BAG / SHOP
local knitCache = {}
local function knit(service, name)
	local key = service .. "." .. name
	local c = knitCache[key]
	if c and c.Parent then return c end
	local idx = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("_Index")
	if not idx then return end
	for _, d in ipairs(idx:GetDescendants()) do
		if d.Name == name and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == service then
			knitCache[key] = d
			return d
		end
	end
end

-- Заполненность сумки: берём из GetInventory (Usage/Capacity) — атрибут CarryCapacity врёт
local invCache, invAt = nil, 0
local function inventory(force)
	if not force and invCache and os.clock() - invAt < 1 then return invCache end
	local rf = knit("CarryInventoryService", "GetInventory")
	if rf then
		local ok, inv = pcall(function() return rf:InvokeServer() end)
		if ok and type(inv) == "table" then invCache, invAt = inv, os.clock() end
	end
	return invCache
end
local function bagUsage(force)
	local inv = inventory(force)
	if inv and inv.Usage then return inv.Usage, inv.Capacity end
	return attr(CONFIG.BagCountAttr), attr(CONFIG.BagCapacityAttr)
end
local function bagFull()
	local n, cap = bagUsage()
	return n and cap and n >= cap
end

-- Подбор предмета: перебираем варианты аргументов Pickup, запоминаем рабочий
local pickupWay
local function pickupItem(it)
	-- 0) быстро: встать вплотную и Pickup(предмет) — сервер берёт с ~10 st и сразу отвечает true/false
	local fast = knit("CarryInventoryService", "Pickup")
	local ip = fast and pos(it)
	local hr = hrp()
	if ip and hr then
		if (hr.Position - ip).Magnitude > 6 then hr.AssemblyLinearVelocity = Vector3.zero; hr.CFrame = CFrame.new(ip + Vector3.new(0, 3, 0)) end
		local ok, res = pcall(function() return fast:InvokeServer(it) end)
		if ok and res == true then return true end
	end
	-- 1) как это делает сама игра (выучено), 2) промпт/клик на предмете, 3) перебор Pickup
	if replay("item", it) then return true end
	local function gone() return changed("item", it) end
	local pr = it:FindFirstChildWhichIsA("ProximityPrompt", true)
	if pr and usePrompt(pr, gone) then return true end
	local cd = it:FindFirstChildWhichIsA("ClickDetector", true)
	if cd and fireclickdetector then
		pcall(fireclickdetector, cd); task.wait(0.4)
		if gone() then return true end
	end
	local rf = knit("CarryInventoryService", "Pickup")
	if not rf then return false end
	local id = it:GetAttribute("SessionSnapshotItemId")
	local part = it:IsA("BasePart") and it or it:FindFirstChildWhichIsA("BasePart", true)
	local ways = {
		function() return rf:InvokeServer(it) end,
		function() return rf:InvokeServer(id) end,
		function() return rf:InvokeServer({ it }) end,
		function() return rf:InvokeServer(part) end,
	}
	local function done()
		return not it.Parent or not it:IsDescendantOf(workspace) or (it:FindFirstAncestorOfClass("Model") and isCharacter(it:FindFirstAncestorOfClass("Model")))
	end
	local order = pickupWay and { pickupWay } or {}
	for i = 1, #ways do if i ~= pickupWay then table.insert(order, i) end end
	local before = bagUsage(true)
	for _, i in ipairs(order) do
		pcall(ways[i])
		task.wait(0.35)
		if done() or bagUsage(true) ~= before then
			if pickupWay ~= i then pickupWay = i; status("[Pickup] рабочий способ #" .. i) end
			return true
		end
	end
	return false
end


----------------------------------------------------------------- FEATURES
local gameTool -- ниже (рядом со swing)
-- ActiveTool.Tool — другой экземпляр того же инструмента: сравнивать только по имени
-- (сравнение объектов давало «не в руке» → повторный EquipTool снимал меч, удары не шли)
local function holds(at, tool)
	return at ~= nil and at.Tool ~= nil and tool ~= nil and at.Tool.Name == tool.Name
end
-- pick(tool) -> число (приоритет) или nil; экипируем лучший подходящий инструмент
local function equipBest(pick)
	local c = player.Character
	if not c then return end
	local best, bs
	for _, src in ipairs({ c, player.Backpack }) do
		for _, t in ipairs(src:GetChildren()) do
			local sc = t:IsA("Tool") and pick(t)
			if sc and (not bs or sc > bs) then best, bs = t, sc end
		end
	end
	if not best then return end
	local at = gameTool()
	local eq = knit("ToolService", "EquipTool")
	if not eq then return end
	-- EquipTool — переключатель: повторный вызов на уже экипированном инструменте СНИМАЕТ его.
	-- Но после езды/смерти инструмент бывает «в руке» без ActiveTool (удары не идут) — тогда снять и надеть заново.
	if best.Parent == c then
		for _ = 1, 6 do
			at = gameTool()
			if holds(at, best) then return best end
			task.wait(0.1)
		end
		local un = knit("ToolService", "UnequipTool")
		if un then pcall(function() un:InvokeServer() end) end
		task.wait(0.2)
	end
	pcall(function() eq:InvokeServer(best) end)
	for _ = 1, 10 do
		at = gameTool()
		if holds(at, best) then return best end
		task.wait(0.1)
	end
	return best
end
-- экипируем только через ToolService.EquipTool (Humanoid:EquipTool не создаёт ActiveTool — удары не засчитываются)
local function equipPickaxe()
	return equipBest(function(t) return hasKey(t.Name, { CONFIG.PickaxeName }) and (t:GetAttribute("Damage") or 1) end)
end
-- оружие для монстров: ближний бой с наибольшим уроном (меч бьёт в 5 раз сильнее кирки)
local function equipWeapon()
	return equipBest(function(t)
		if t:GetAttribute("ActionType") == "Swing" and not hasKey(t.Name, { CONFIG.PickaxeName }) then
			return t:GetAttribute("Damage") or 1
		end
	end) or equipPickaxe()
end
-- каменных мобов (Mutation_Stone) меч не пробивает — только кирка
local function weaponFor(m)
	-- каменные мобы и Fuel Leech (сосёт топливо из бура) пробиваются только киркой
	if m and (m:GetAttribute("Mutation_Stone") == true or m:GetAttribute("FuelLeechState") ~= nil) then return equipPickaxe() end
	return equipWeapon()
end

-- Жилы: Part с атрибутами SessionOreType / OreLoaded (Workspace.Chunks...Nodes.Ore_Node*)
local function oreNodes()
	local out, root = {}, workspace:FindFirstChild("Chunks") or workspace
	for _, d in ipairs(root:GetDescendants()) do
		local t = d:IsA("BasePart") and d:GetAttribute("SessionOreType")
		if t and d:GetAttribute("OreLoaded") ~= false and d:FindFirstChild("Ore") and not d:GetAttribute("_DF_Skip")
			and (#CONFIG.OreNames == 0 or hasKey(t, CONFIG.OreNames)) then
			table.insert(out, d)
		end
	end
	return out
end

local function oreAlive(node)
	return node.Parent and node:GetAttribute("OreLoaded") ~= false and node:FindFirstChild("Ore") ~= nil
end

-- Удар киркой: зовём объект кирки самой игры (Knit ToolController.ActiveTool:Swing()).
-- Он сам играет анимацию, ищет руду перед персонажем и шлёт ToolService.RE.Update.
-- tool:Activate() не работает (у кирки нет Handle), ручная отправка Update сервер не засчитывает.
local Knit
pcall(function() Knit = require(RS.Packages.Knit) end)
gameTool = function()
	local ok, tc = pcall(function() return Knit.GetController("ToolController") end)
	return ok and tc and tc.ActiveTool or nil
end
local function swing(tool)
	local at = gameTool()
	-- +3 st к дальности: удар считает клиент, сервер пропускает примерно до 17–18 st (проверено), дальше — нет
	if holds(at, tool) and at.Range and not at._dfRange then at._dfRange = true; at.Range = at.Range + 3 end
	if holds(at, tool) and at.Swing then pcall(at.Swing, at) end
end

local pickupOresNear -- определяется ниже (после collect)

-- Точка продажи: ...TradingPost.SellParts.SellPart
-- Если стол далеко, игра его не прогружает (streaming) — запоминаем позицию,
-- летим туда и просим сервер прогрузить область.
local lastSellPos
local function findSellParts()
	return findAll(function(d)
		-- столы в папках CutScene* — декорации катсцен, продать там нельзя
		return d:IsA("BasePart") and d.Name == "SellPart"
			and (d:FindFirstAncestor("TradingPost") or d:FindFirstAncestor("Sell_Table")) ~= nil
			and not d:GetFullName():find("CutScene", 1, true)
	end)
end
local function nearestSellPart()
	local sp = nearest(findSellParts())
	if sp then lastSellPos = sp.Position; return sp end
	if not lastSellPos then
		status("[Sell] стол продажи не найден (ни разу не был прогружен)")
		return nil
	end
	local r = hrp()
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.new(lastSellPos + Vector3.new(0, 4, 0))
	end
	pcall(function() player:RequestStreamAroundAsync(lastSellPos, 5) end)
	local t0 = os.clock()
	repeat
		task.wait(0.3)
		sp = nearest(findSellParts())
	until sp or os.clock() - t0 > 6
	if not sp then status("[Sell] стол продажи не прогрузился") end
	return sp
end
-- запоминаем позицию стола, пока он прогружен
task.spawn(function()
	while Running do
		local sp = nearest(findSellParts())
		if sp then lastSellPos = sp.Position end
		task.wait(5)
	end
end)

-- Сумка полна: к точке продажи (если есть), иначе к дрели
local sellAll -- определяется ниже
local function onBagFull(who)
	-- Автопродажа включена и есть стол продажи — продаём; иначе — к дрели
	local sell = nearestSellPart()
	if sell and sellAll then
		tp(sell)
		status("[" .. who .. "] Сумка полна — продажа")
		Selling = true
		local ok, err = pcall(sellAll, sell)
		Selling = false
		if not ok then warn("[Sell] ошибка: " .. tostring(err)) end
		if not bagFull() then return end
	end
	local drill = workspace:FindFirstChild(CONFIG.DrillName)
	if drill then tpToDrill(drill) end
	status("[" .. who .. "] Сумка полна — ТП к дрели")
end

-- Mining: авто-фарм копает уголь на топливо тем же кодом, не трогая тумблер «Фарм руды»
local Mining = false
local function farming() return State.Farm or Mining end
local function farmStep(target)
	if bagFull() then
		onBagFull("Farm")
		if bagFull() and not Mining then State.Farm = false end
		return
	end
	-- target: конкретная жила (авто-фарм выбирает её у бура, а персонаж может стоять далеко от неё)
	local node = target or nearest(oreNodes(), CONFIG.OreSearchRadius)
	if not node then return end
	local ore = node:FindFirstChild("Ore") or node
	local rock = node:FindFirstChild("Rock")
	local p = pos(ore)
	local r = hrp()
	if not (p and r) then return end
	-- точка сбоку от камня, на земле (а не на верхушке)
	local radius = 4
	for _, part in ipairs({ rock, ore }) do
		if part and part:IsA("BasePart") then
			radius = math.max(radius, math.max(part.Size.X, part.Size.Z) / 2 + 3)
		end
	end
	-- перебираем 12 точек вокруг камня, берём свободную (не в стене) ближайшую к игроку
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, node }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { player.Character, node }
	local stand, best = nil, math.huge
	for k = 0, 11 do
		local a = k * math.pi / 6
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		-- путь от руды до точки не перекрыт стеной
		if not workspace:Raycast(p, dir * radius, params) then
			local c = p + dir * radius
			local hit = workspace:Raycast(c + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
			if hit then
				local spot = hit.Position + Vector3.new(0, 3, 0)
				local blocked = #workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(2, 4, 2), op) > 0
				local d = (spot - r.Position).Magnitude
				if not blocked and d < best then stand, best = spot, d end
			end
		end
	end
	if not stand then
		print("[Farm] Нет свободного места у руды — пропуск")
		node:SetAttribute("_DF_Skip", true)
		return
	end

	if not moveTo(ore, function() return farming() end, stand) then return end
	local tool = equipPickaxe()
	local start, oreCheck = os.clock(), os.clock()
	while farming() and oreAlive(node) do
		-- выпавшую руду подбираем сразу, а не после того как жила кончится (иначе она пропадает/её уносит)
		if os.clock() - oreCheck > 0.5 and pickupOresNear then oreCheck = os.clock(); pickupOresNear(p, 25, true) end
		if CONFIG.MaxTimePerOre > 0 and os.clock() - start > CONFIG.MaxTimePerOre then break end
		if Selling then task.wait(0.3) continue end -- убийство монстров / продажа заняли персонажа
		r = hrp()
		if r then
			r.CFrame = CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z))
			local cam = workspace.CurrentCamera
			if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, p) end
		end
		swing(tool)
		task.wait(0.2) -- кулдаун держит сама кирка (LastSwing)
	end
	status(("[Farm] %s: %s за %.1fс"):format(tostring(node:GetAttribute("SessionOreType")),
		oreAlive(node) and "не добил" or "добыто", os.clock() - start))
	if farming() and oreAlive(node) then
		-- не добили (слабая кирка/монстр мешает) — 30 сек не возвращаемся, иначе крутимся на одной жиле
		node:SetAttribute("_DF_Skip", true)
		task.delay(30, function() if node.Parent then node:SetAttribute("_DF_Skip", nil) end end)
	end
	if farming() and not oreAlive(node) and pickupOresNear then pickupOresNear(p, 25) end
end


-- Предметы лежат в Workspace.Items (атрибуты Value, Category, DisplayName)
-- Предметы на земле: Workspace.Items + лут (атрибут SessionSnapshotItemId), не на персонажах
local skipUntil = setmetatable({}, { __mode = "k" })
local skipIds = {} -- SessionSnapshotItemId -> до какого времени не трогать
local function groundItems()
	local out, seen = {}, {}
	local folder = workspace:FindFirstChild("Items")
	if folder then
		for _, it in ipairs(folder:GetChildren()) do
			seen[it] = true
			-- товары магазина лежат там же, но без SessionSnapshotItemId
			if it:GetAttribute("SessionSnapshotItemId") then table.insert(out, it) end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if not seen[d] and (d:IsA("Model") or d:IsA("BasePart")) and d:GetAttribute("SessionSnapshotItemId")
			and d:GetAttribute("ItemDatabaseId") then
			local m = d:FindFirstAncestorOfClass("Model")
			if not (m and isCharacter(m)) and not (d.Parent and seen[d.Parent]) then
				seen[d] = true; table.insert(out, d)
			end
		end
	end
	return out
end

local grabSack -- ниже


-- Поднять выпавшую руду (DisplayCategory=Ore) рядом с точкой
pickupOresNear = function(center, radius, quick)
	local folder = workspace:FindFirstChild("Items")
	if not folder then return end
	-- pickupItem сам встаёт вплотную (сервер отдаёт с ~10 st) — отдельный подлёт и паузы не нужны.
	-- Ждём появления руды до 1.5 с; после последней подобранной — ещё 0.4 с на догоняющие куски.
	local t0, lastFound = os.clock(), nil
	repeat
		for _, it in ipairs(folder:GetChildren()) do
			if not farming() or bagFull() then return end
			local p = pos(it)
			if it:GetAttribute("DisplayCategory") == "Ore" and it:GetAttribute("SessionSnapshotItemId") and p and (p - center).Magnitude <= radius
				and (skipUntil[it] or 0) < os.clock() then
				lastFound = os.clock()
				if pickupItem(it) then task.wait(CONFIG.PickupDelay) else skipUntil[it] = os.clock() + 60 end
			end
		end
		if quick then return end
		task.wait(0.1)
	until (lastFound and os.clock() - lastFound > 0.4) or os.clock() - t0 > 1.5
end

-- Автопродажа: выкидываем предметы на стол продажи по одному.
-- Выпавший предмет проверяем по его атрибутам (Rarity/Category); если его нельзя
-- продавать (легендарка/топливо) — сразу поднимаем обратно. Затем подбираем мешочек с золотом.
-- GetInventory() -> { Capacity, Usage, Entries = { {Id, Key, Name, Rarity, Category, DisplayName, ...} } }
local function invEntries()
	local rf = knit("CarryInventoryService", "GetInventory")
	if not rf then return {} end
	local ok, inv = pcall(function() return rf:InvokeServer() end)
	if not ok or type(inv) ~= "table" or type(inv.Entries) ~= "table" then return {} end
	local list = {}
	for _, e in pairs(inv.Entries) do
		if type(e) == "table" and e.Id then table.insert(list, e) end
	end
	return list
end

local function sellable(e)
	return not hasKey(tostring(e.Rarity or ""), CONFIG.SellKeepRarity)
		and not hasKey(tostring(e.Category or ""), CONFIG.SellKeepCategory)
end

local function tryDrop(e)
	local usage = bagUsage(true)
	local remotes = {
		knit("CarryInventoryService", "DropGroup"),
		knit("ToolService", "DropSpecificItem"),
	}
	local variants = {
		{ e.Id }, { e.Key }, { e.Key, 1 }, { e.Id, 1 }, { { e.Id } }, { e.Name },
	}
	for _, rf in pairs(remotes) do
		for _, args in ipairs(variants) do
			local ok, res = pcall(function() return rf:InvokeServer(table.unpack(args)) end)
			task.wait(0.4)
			if bagUsage(true) ~= usage then
				status("[Sell] выброс сработал: " .. rf.Name .. "(" .. tostring(args[1]) .. ")")
				return true
			end
			if not ok then print("[Sell] " .. rf.Name .. " ошибка: " .. tostring(res)) end
		end
	end
	return false
end

-- Кирки в хотбаре: оставляем одну лучшую (по Damage, затем Value), остальные выкидываем на стол
local function toolScore(t)
	return (t:GetAttribute("Damage") or 0) * 100000 + (t:GetAttribute("Value") or t:GetAttribute("Cost") or 0)
end
local function myPickaxes()
	local out = {}
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if src then
			for _, t in ipairs(src:GetChildren()) do
				if t:IsA("Tool") and (t:GetAttribute("Class") == "Pickaxe" or hasKey(t.Name, { "Pickaxe" })) then
					table.insert(out, t)
				end
			end
		end
	end
	table.sort(out, function(a, b) return toolScore(a) > toolScore(b) end)
	return out
end
local function toolGone(t, count)
	return t.Parent == nil or not (t:IsDescendantOf(player.Backpack) or (player.Character and t:IsDescendantOf(player.Character)))
		or (t:GetAttribute("Count") or 1) < count
end
local function dropTool(t)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local count = t:GetAttribute("Count") or 1
	local id = t:GetAttribute("ItemDatabaseId")
	local drop, dropSpec = knit("ToolService", "Drop"), knit("ToolService", "DropSpecificItem")
	local eq = knit("ToolService", "EquipTool")
	local tries = {
		-- взять в руки через ToolService (как игра) и Drop() — так выкидываются мечи/броня
		function()
			local at = gameTool()
			if not (at and at.Tool and at.Tool.Name == t.Name) and eq then eq:InvokeServer(t); task.wait(0.4) end
			return drop and drop:InvokeServer()
		end,
		function() if hum then hum:EquipTool(t) end; task.wait(0.2); return drop and drop:InvokeServer() end,
		function() return drop and drop:InvokeServer(t) end,
		function() return dropSpec and dropSpec:InvokeServer(t) end,
		function() return dropSpec and dropSpec:InvokeServer(t.Name) end,
		function() return dropSpec and id and dropSpec:InvokeServer(id) end,
	}
	for _, f in ipairs(tries) do
		pcall(f)
		task.wait(0.4)
		if toolGone(t, count) then return true end
	end
	return false
end
local function sellExtraPickaxes(mine)
	local folder = workspace:FindFirstChild("Items")
	for _ = 1, 20 do
		local list = myPickaxes()
		local best = list[1]
		local target
		for i = 2, #list do target = list[i]; break end
		-- стак одинаковых (×5): если лучшая сама в стаке >1 — продаём лишние из стака
		if not target and best and (best:GetAttribute("Count") or 1) > 1 then target = best end
		if not target then return end
		local before = {}
		if folder then for _, it in ipairs(folder:GetChildren()) do before[it] = true end end
		local name = target.Name
		if dropTool(target) then
			status("[Sell] продаю кирку: " .. name)
			if folder then
				task.wait(0.2)
				for _, it in ipairs(folder:GetChildren()) do if not before[it] then mine[it] = true end end
			end
		else
			status("[Sell] не удалось выкинуть кирку: " .. name)
			return
		end
	end
end

-- Старое снаряжение на продажу: всё оружие ближнего боя, кроме лучшего; броня из рюкзака (лучшая уже надета
-- armorStep'ом); пушки (патроны скрипт не покупает). Аптечки, топливо и кирки (их — sellExtraPickaxes) не трогаем.
-- обычная броня (только защита) — её можно продавать; с особыми свойствами (Hoarder — сумка, скорость, эффекты) — нет
local plainKeys = { ArmorType = 1, Value = 1, MedicalStackCount = 1, Cost = 1, Tool = 1, ItemDatabaseTemplate = 1, DisplayName = 1,
	CarryItemId = 1, Rarity = 1, ItemDatabaseId = 1, Category = 1, Armor = 1, SessionSnapshotItemId = 1, CommittedChestReward = 1,
	CarryStackKey = 1, LastDragger = 1, Icon = 1, Description = 1, InventoryHotbar = 1 }
local function plainArmor(t)
	if t:GetAttribute("Rarity") ~= "Common" then return false end
	for k in pairs(t:GetAttributes()) do if not plainKeys[k] then return false end end
	return true
end
local function oldGear()
	local melee, out = {}, {}
	-- броня не лучше надетой в своём слоте (ботинки — и не быстрее надетых) — лишняя, даже с особыми свойствами
	local function worse(t)
		local c = player.Character
		local slot = t:GetAttribute("ArmorType")
		slot = slot == "Head" and "Helmet" or slot
		local have, a = c and slot and c:GetAttribute(slot), t:GetAttribute("Armor") or 0
		if type(have) ~= "number" or a > have then return false end
		local h = c:FindFirstChildOfClass("Humanoid")
		return a < have or (t:GetAttribute("SpeedBoost") or 0) <= (h and h:GetAttribute("SpeedBoost") or 0)
	end
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(src and src:GetChildren() or {}) do
			if t:IsA("Tool") then
				local cat = t:GetAttribute("Category") or ""
				if cat == "Melee" then table.insert(melee, t)
				elseif cat == "Armor" and (plainArmor(t) or worse(t)) or cat:find("Gun") or cat == "Tool" and t:GetAttribute("Class") ~= "Pickaxe" and t:GetAttribute("ActionType") ~= "Use" then
					table.insert(out, t)
				end
			end
		end
	end
	table.sort(melee, function(a, b) return (a:GetAttribute("Damage") or 0) > (b:GetAttribute("Damage") or 0) end)
	for i = 2, #melee do table.insert(out, melee[i]) end
	return out
end
local function sellOldGear(mine)
	local folder = workspace:FindFirstChild("Items")
	for _, t in ipairs(oldGear()) do
		local before = {}
		if folder then for _, it in ipairs(folder:GetChildren()) do before[it] = true end end
		local name = t:GetAttribute("DisplayName") or t.Name
		if dropTool(t) then
			status("[Sell] продаю старое: " .. name)
			if folder then
				task.wait(0.2)
				for _, it in ipairs(folder:GetChildren()) do if not before[it] then mine[it] = true end end
			end
		else
			status("[Sell] не удалось выкинуть: " .. name)
		end
	end
end

local function isMySack(it)
	return it:GetAttribute("ItemDatabaseId") == "Money_Sack"
		and (it:GetAttribute("BagCreator") == nil or it:GetAttribute("BagCreator") == player.Name)
end

-- Мешок с деньгами: пробуем Interact/Pickup/касание/E, пока не исчезнет; рабочий способ запоминаем
local sackWay = 4 -- Interact(model): проверено в игре 20.11
grabSack = function(it)
	local pickup = knit("CarryInventoryService", "Pickup")
	local interact = knit("InteractionService", "Interact")
	local dragReq = knit("DragService", "Request")
	local bag = it:FindFirstChild("Bag") or it:FindFirstChildWhichIsA("BasePart", true)
	local sid = it:GetAttribute("SessionSnapshotItemId")
	local tries = {
		{ "Pickup(model)",   function() return pickup:InvokeServer(it) end },
		{ "Pickup(bag)",     function() return pickup:InvokeServer(bag) end },
		{ "Pickup(id)",      function() return pickup:InvokeServer(sid) end },
		{ "Interact(model)", function() return interact:InvokeServer(it) end },
		{ "Interact(bag)",   function() return interact:InvokeServer(bag) end },
		{ "Drag(model)",     function() return dragReq:InvokeServer(it) end },
		{ "touch",           function() for _, p in ipairs(it:GetDescendants()) do if p:IsA("BasePart") then touch(p) end end end },
		{ "E",               function()
			local cam = workspace.CurrentCamera
			if cam and bag then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, bag.Position) end
			VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.1)
			VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		end },
	}
	moveTo(it)
	-- сначала способ, который уже срабатывал (в тесте это Interact(model))
	local order = {}
	if sackWay then table.insert(order, sackWay) end
	for i = 1, #tries do if i ~= sackWay then table.insert(order, i) end end
	for n, i in ipairs(order) do
		if not it.Parent then break end
		local r = hrp()
		if r and bag then r.CFrame = CFrame.new(bag.Position + Vector3.new(0, 2.5, 0)) end
		pcall(tries[i][2])
		for _ = 1, 5 do task.wait(0.1); if not it.Parent then break end end
		if not it.Parent then
			if sackWay ~= i then sackWay = i; status("[Sell] мешок подобран способом: " .. tries[i][1]) end
			return true
		end
		if n == 1 and pickupItem(it) then return true end
	end
	return not it.Parent
end

sellAll = function(sellPart)
	local folder = workspace:FindFirstChild("Items")
	if not folder then return end
	local spot = sellPart.Parent and sellPart.Parent.Parent
		and sellPart.Parent.Parent:FindFirstChild("SellSpot", true) or sellPart
	tp(spot, Vector3.new(0, 4, 0))
	task.wait(0.3)
	local mine, failed = {}, {}
	-- быстрый проход: всё продаваемое подряд через DropGroup(id) (~0.1 с на предмет), без опроса инвентаря
	local dropRf = knit("CarryInventoryService", "DropGroup")
	if dropRf then
		local before = {}
		for _, it in ipairs(folder:GetChildren()) do before[it] = true end
		local list = {}
		for _, e in ipairs(invEntries()) do if sellable(e) then table.insert(list, e) end end
		for i, e in ipairs(list) do
			local r = hrp()
			if r and (r.Position - pos(spot)).Magnitude > 8 then tp(spot, Vector3.new(0, 4, 0)) end
			pcall(function() dropRf:InvokeServer(e.Id) end)
			if i % 5 == 0 then task.wait(0.05) end
		end
		task.wait(0.4)
		for _, it in ipairs(folder:GetChildren()) do
			if not before[it] then
				local rar, cat = it:GetAttribute("Rarity") or "", it:GetAttribute("Category") or ""
				if hasKey(rar, CONFIG.SellKeepRarity) or hasKey(cat, CONFIG.SellKeepCategory) then
					pickupItem(it); status("[Sell] выпало не то, вернул: " .. it.Name)
				else
					mine[it] = true
				end
			end
		end
		if #list > 0 then status(("[Sell] выкинул на стол: %d предметов"):format(#list)) end
	end
	-- что не ушло быстрым способом — по одному старым перебором
	for _ = 1, 60 do
		local target
		for _, e in ipairs(invEntries()) do
			if sellable(e) and not failed[e.Id] then target = e; break end
		end
		if not target then break end
		local before = {}
		for _, it in ipairs(folder:GetChildren()) do before[it] = true end
		if tryDrop(target) then
			status("[Sell] продаю: " .. tostring(target.DisplayName or target.Name))
			task.wait(0.2)
			for _, it in ipairs(folder:GetChildren()) do
				if not before[it] then
					-- страховка: выпало не то (легендарка/топливо) — поднять обратно
					local rar, cat = it:GetAttribute("Rarity") or "", it:GetAttribute("Category") or ""
					if hasKey(rar, CONFIG.SellKeepRarity) or hasKey(cat, CONFIG.SellKeepCategory) then
						pickupItem(it)
						status("[Sell] выпало не то, вернул: " .. it.Name)
					else
						mine[it] = true
					end
				end
			end
		else
			failed[target.Id] = true
			status("[Sell] не удалось выкинуть: " .. tostring(target.DisplayName or target.Name))
		end
		tp(spot, Vector3.new(0, 4, 0))
	end
	pcall(sellExtraPickaxes, mine)
	pcall(sellOldGear, mine)
	if next(mine) == nil then
		status("[Sell] нечего продавать (или не удалось выкинуть — нужен лог SimpleSpy)")
		return
	end
	-- ждём свой мешок с деньгами (Money_Sack, BagCreator = мы) и подбираем
	local t0, got = os.clock(), 0
	while os.clock() - t0 < 12 do
		local any = false
		for _, it in ipairs(folder:GetChildren()) do
			if isMySack(it) then any = true; if grabSack(it) then got += 1 end end
		end
		if got > 0 and not any then break end
		task.wait(0.4)
	end
	status(got > 0 and ("[Sell] готово, мешков подобрано: " .. got) or "[Sell] мешок с деньгами не найден/не поднялся")
end


----------------------------------------------------------------- DRILL
local function getDrill()
	return workspace:FindFirstChild(CONFIG.DrillName)
end
local function hum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function hpPct()
	local h = hum()
	return (h and h.MaxHealth > 0) and h.Health / h.MaxHealth * 100 or 0
end
local function alive()
	local h = hum()
	return h ~= nil and h.Health > 0 and hrp() ~= nil
end
-- атрибут InDungeon обновляется с опозданием на десятки секунд — держим свой флаг (вход/выход = телепорт)
local dungeonActive = false
local function inDungeon() return dungeonActive end
-- расстояние по горизонтали (ворота и стены стоят в стороне/выше пути бура)
local function flat(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
-- Внутренности данжей стоят прямо в мире (в стороне от пути бура). Залететь туда без входа через ворота
-- опасно: мобы бьют, а наш урон не проходит. Зона = круг вокруг внутреннего промпта Exit.
local zoneCache, zoneAt = {}, 0
local function dungeonZones()
	if os.clock() - zoneAt < 5 then return zoneCache end
	zoneAt, zoneCache = os.clock(), {}
	for _, g in ipairs(workspace:GetChildren()) do
		if g.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName then
			for _, d in ipairs(g:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.ActionText == "Exit" then
					local p = d.Parent:IsA("Attachment") and d.Parent.WorldPosition or pos(d.Parent)
					if p then table.insert(zoneCache, p) end
				end
			end
		end
	end
	return zoneCache
end
local function inZone(p)
	for _, z in ipairs(dungeonZones()) do
		if flat(z, p) < 260 then return true end
	end
	return false
end


-- Вызов Knit-сервиса так же, как это делает игра (методы возвращают Promise). nil — ошибка.
local function call(service, method, ...)
	local args = table.pack(...)
	local ok, a, b = pcall(function()
		local s = Knit.GetService(service)
		local p = s[method](s, table.unpack(args, 1, args.n))
		if type(p) == "table" and p.expect then return p:expect() end
		return p
	end)
	if not ok then return nil end
	return a, b
end

-- Топливо: канистры/уголь (Category=Fuel: GasCan 50, PropaneTank 200, Ore_Coal 25) лежат в мире;
-- поднятое топливо — инструмент в рюкзаке. Заправка: взять его в руки, стоя на FuelTouchPart (проверено: 2.7 → 28).
local function fuelPct()
	local d = getDrill()
	local f, m = d and d:GetAttribute(CONFIG.FuelAttr), d and d:GetAttribute(CONFIG.MaxFuelAttr)
	if not (f and m and m > 0) then return 100, f or 0 end
	return f / m * 100, f
end
local function fuelTools()
	local out = {}
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if src then
			for _, t in ipairs(src:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Category") == "Fuel" then table.insert(out, t) end
			end
		end
	end
	return out
end

-- Трупы мобов (Category=Corpse, Fuel=5) лежат в сумке; брошенный в топливный отсек труп сгорает в топливо
local function corpses()
	local inv, out = inventory(), {}
	for _, e in pairs(inv and inv.Entries or {}) do
		-- дорогие трупы (Bandit Miner 380) — на продажу; в печь только при почти пустом баке
		if type(e) == "table" and e.Category == "Corpse" and e.Id and ((e.Value or 0) < 50 or fuelPct() < 20) then table.insert(out, e) end
	end
	return out
end

-- Езда: DrillService.StartDriving → газ через LocalDriverSeat (клиент игры сам шлёт UpdateDriverThrottle).
local driveStarted = false
local function driveCall(name, ...)
	local r = knit("DrillService", name)
	if not r then return false end
	local args = { ... }
	local ok, res = pcall(function()
		if r:IsA("RemoteFunction") then return r:InvokeServer(table.unpack(args)) end
		r:FireServer(table.unpack(args)); return true
	end)
	return ok and res
end
local function isDriver()
	local d = getDrill()
	return d ~= nil and d:GetAttribute("DriverUserId") == player.UserId
end
local function driveStop(why)
	if driveStarted or (State.Auto and isDriver()) then
		local d = getDrill()
		local seat = d and d:FindFirstChild("LocalDriverSeat", true)
		if seat then pcall(function() seat.ThrottleFloat = 0; seat.Throttle = 0 end) end
		driveCall("UpdateDriverThrottle", 0)
		driveCall("StopDriving")
		driveStarted = false
		task.wait(0.3)
		if why then status("[Drive] стоп: " .. why) end
	end
end
local function drive()
	local drill = getDrill()
	if not drill then return end
	-- бур общий: если за рулём другой игрок — управление не отбираем
	local who = drill:GetAttribute("DriverUserId")
	if type(who) == "number" and who ~= 0 and who ~= player.UserId then
		driveStarted = false
		Phase = "За рулём другой игрок — помогаю"
		return
	end
	if not isDriver() then
		local seat = drill:FindFirstChild("LocalDriverSeat", true)
		local r = hrp()
		if seat and r then
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
		end
		task.wait(0.3)
		if not driveCall("StartDriving") then
			status("[Drive] StartDriving не принят — повтор")
			task.wait(1.5)
			return
		end
		driveStarted = true
		status("[Drive] за рулём")
		task.wait(0.5)
	end
	driveStarted = true
	local seat = drill:FindFirstChild("LocalDriverSeat", true)
	if seat then pcall(function() seat.ThrottleFloat = 1; seat.Throttle = 1 end) end
	-- кнопка R (Power Burst, после апгрейда): сервер сам держит перезарядку, просто пробуем раз в 3 с
	if (drill:GetAttribute("PowerBurst") or 0) > 0 and os.clock() > (DF_boostNext or 0) then
		DF_boostNext = os.clock() + 3 -- глобал: лимит локалов
		if driveCall("ActivateBoost") then status("[Drive] Power Burst (R)") end
	end
end

local refuelNext = 0
local enemies -- ниже (бой)
local function refuel()
	local d = getDrill()
	local part = d and d:FindFirstChild("FuelTouchPart")
	if not part then return false end
	driveStop()
	local _, before = fuelPct()
	local eq = knit("ToolService", "EquipTool")
	-- сначала мелкое топливо, чтобы не сжечь баллон на 200 в почти полный бак
	local tools = fuelTools()
	table.sort(tools, function(a, b) return (a:GetAttribute("Fuel") or 0) < (b:GetAttribute("Fuel") or 0) end)
	Moving = true -- ноклип: стоим прямо внутри топливного отсека, чтобы предмет в руке его касался
	for _, t in ipairs(tools) do
		if fuelPct() >= 95 then break end
		local r = hrp()
		if not r then break end
		local _, was = fuelPct()
		if t.Parent ~= player.Character and eq then pcall(function() eq:InvokeServer(t) end) end
		for _ = 1, 12 do
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0))
			touch(part)
			task.wait(0.2)
			local _, now = fuelPct()
			if now > was + 1 or not t.Parent then break end
		end
	end
	local drop = knit("CarryInventoryService", "DropGroup")
	local burned = 0
	-- труп кидаем ПЕРЕД печкой (снаружи бура): брошенный внутрь отсека отлетает и не засчитывается
	local function front()
		local r = hrp()
		if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = d:GetPivot() * CFrame.new(0, -1, 21) end
	end
	-- трупы подряд (по 0.15 с), потом один раз ждём, пока они упадут в печь
	for _ = 1, 3 do front(); task.wait(0.1) end
	for _, e in ipairs(drop and corpses() or {}) do
		if fuelPct() >= 95 or not hrp() or hpPct() < CONFIG.GuardHpPct + 10 or #enemies(20) >= 2 then break end
		front()
		if pcall(function() drop:InvokeServer(e.Id) end) then burned += 1 end
		task.wait(0.15)
	end
	if burned > 0 then for _ = 1, 12 do front(); task.wait(0.1) end end
	if burned > 0 then
		inventory(true)
		status("[Fuel] сжёг трупов: " .. burned)
	end
	Moving = false
	local _, after = fuelPct()
	status(("[Fuel] заправка: %.0f → %.0f"):format(before, after))
	if after > before + 1 then Stats.refuels += 1; return true end
	refuelNext = os.clock() + 5 -- не получилось — не долбим каждый тик
	return false
end

-- Апгрейды бура: карточки DrillService.FetchOptions() → UpgradeDrill(имя, версия). Только Type="Coins".
local upgradeNext = 0
local function upgradeStep(force)
	if not force and os.clock() < upgradeNext then return false end
	upgradeNext = os.clock() + 6
	local coins = call("CurrencyService", "GetCurrency")
	if type(coins) ~= "number" then return false end
	local opts, ver = call("DrillService", "FetchOptions")
	if type(opts) ~= "table" or type(ver) ~= "number" then return false end
	local best, bestRank
	for _, o in ipairs(opts) do
		if type(o) == "table" and o.Type == "Coins" and type(o.Cost) == "number" and o.Cost > 0 and o.Cost <= coins
			and not table.find(CONFIG.UpgradeNever, o.UpgradeName) then
			local rank = table.find(CONFIG.UpgradePriority, o.UpgradeName)
			if not rank and table.find(CONFIG.UpgradeBalanced, o.UpgradeName) then
				local d = getDrill()
				rank = #CONFIG.UpgradePriority + 1 + (d and tonumber(d:GetAttribute(o.UpgradeName)) or 0) / 1000
			end
			rank = rank or 100
			if not bestRank or rank < bestRank then best, bestRank = o, rank end
		end
	end
	if not best then return false end
	local res = call("DrillService", "UpgradeDrill", best.UpgradeName, ver)
	status(("[Upgrade] %s (%s) за %d: %s"):format(tostring(best.UpgradeName), tostring(best.Rarity), best.Cost, res and "куплено" or "отказ"))
	if res then Stats.upgrades += 1; upgradeNext = os.clock() + 1 end
	return res and true or false
end

-- Катсцены: делаем то же, что кнопка Skip (CutSceneController → VoteSkip / VoteSkipPrivate)
local function skipCutscene()
	if workspace:GetAttribute("InCutScene") ~= true then return end
	local ok, cc = pcall(function() return Knit.GetController("CutSceneController") end)
	if not (ok and cc and cc.CurrentCutScene) then return end
	local ctx = cc.CurrentCutSceneContext
	if ctx and ctx.DisableSkip == true then return end
	if ctx and ctx.Private and ctx.RuntimeId ~= nil then
		call("CutSceneService", "VoteSkipPrivate", ctx.RuntimeId, cc.CurrentCutScene)
	else
		call("CutSceneService", "VoteSkip", cc.CurrentCutScene, ctx and ctx.RuntimeId)
	end
	status("[Cutscene] пропуск: " .. tostring(cc.CurrentCutScene))
	task.wait(2)
end

----------------------------------------------------------------- KILL AURA / DUNGEON
-- Бьём монстров мечом, паря над макушкой монстра и глядя на него.
local RunService = game:GetService("RunService")
local killSkip = setmetatable({}, { __mode = "k" })
local Killing = false
local lastSurface

-- живые враги в радиусе от center (по умолчанию — от персонажа)
enemies = function(radius, center)
	local out, folder, r = {}, workspace:FindFirstChild("Npc"), hrp()
	center = center or (r and r.Position)
	if not (folder and center) then return out end
	for _, m in ipairs(folder:GetChildren()) do
		local h = m:IsA("Model") and m:FindFirstChild("Humanoid")
		-- мимики (Health ~1e11) — сундуки-монстры, их не бьём
		if h and h.Health > 0 and h.MaxHealth < 1e6 and m:GetAttribute("NpcFaction") == "Enemy"
			and (killSkip[m] or 0) < os.clock() then
			local p = pos(m)
			if p and (radius <= 0 or (p - center).Magnitude <= radius) then table.insert(out, m) end
		end
	end
	table.sort(out, function(a, b) return dist(a) < dist(b) end)
	return out
end
-- Fuel Leech, присосавшийся к буру (Humanoid нет — в enemies не попадает). Глобал: лимит локалов.
function leechOnDrill()
	local d, folder = getDrill(), workspace:FindFirstChild("Npc")
	local dp = d and pos(d)
	for _, m in ipairs(dp and folder and folder:GetChildren() or {}) do
		local p = pos(m)
		-- присосалась — в 80 st; в любом другом уязвимом состоянии (вылезла из камня, ползёт к буру) — в 150 st
		local st = m:GetAttribute("FuelLeechState")
		if st and m:GetAttribute("FuelLeechVulnerable") ~= false and (m:GetAttribute("FuelLeechHealth") or 0) > 0
			and p and (p - dp).Magnitude < (st == "Attached" and 80 or 150) and (killSkip[m] or 0) < os.clock() then return m end
	end
end

-- Позиция для удара (смещение от центра монстра). Опытным путём: над монстром не выше макушки+2 и
-- сбоку в пределах ~6 st работает; точное зависит от монстра и стен — поэтому перебираем по кругу,
-- пока не пойдёт урон, и запоминаем рабочий вариант.
-- Смещения считаются от размера моба (h = половина габарита): у Goblin Brute (6.5×10×3.3)
-- старые фиксированные точки оказывались внутри модели, и урон не проходил.
local killCands = {
	function(h) return Vector3.new(0, h.Y + 1, 0) end,           -- над макушкой (на 1 выше; +4 уже не бьёт)
	function(h) return Vector3.new(h.X + 2.5, h.Y * 0.3, 0) end,  -- сбоку, на уровне плеч
	function(h) return Vector3.new(0, h.Y * 0.3, h.Z + 2.5) end,
	function(h) return Vector3.new(-(h.X + 2.5), h.Y * 0.3, 0) end,
	function(h) return Vector3.new(h.X + 1, 0, 0) end,            -- вплотную (бьёт всегда, но и моб бьёт в ответ)
}
local killIdx = 1
local function standUnder(m)
	local ok, cf, size = pcall(m.GetBoundingBox, m)
	if not ok then local p = pos(m); return p and p + Vector3.new(0, 3, 0), p, p end
	local mid = cf.Position
	local base = Vector3.new(mid.X, mid.Y - size.Y / 2, mid.Z)
	return mid + killCands[killIdx](size / 2), base, mid
end

-- вплотную (глобал: лимит локалов); обычный killOne ниже бьёт с дальности оружия
function DF_killClose(m)
	-- у Fuel Leech нет Humanoid — здоровье в атрибуте FuelLeechHealth (см. mhp ниже)
	local h = m:FindFirstChild("Humanoid") or (m:GetAttribute("FuelLeechState") and { Health = 1 })
	local tool = weaponFor(m)
	if not (h and tool) then killSkip[m] = os.clock() + 30; return end
	local stand, base, mid = standUnder(m)
	if not stand then return end
	if not moveTo(m, function() return State.KillAura or busy() end, stand) then return end
	Moving = true -- ноклип на время удара
	-- у Fuel Leech своё здоровье в атрибуте FuelLeechHealth
	local function mhp() return m:GetAttribute("FuelLeechHealth") or h.Health end
	local t0, lastHp, lastHit = os.clock(), mhp(), os.clock()
	local misses, myHp0, nodmg = 0, hpPct(), false
	local toolCheck = os.clock()
	while Running and (State.KillAura or busy()) and m.Parent and h.Health > 0 and mhp() > 0 do
		local r = hrp()
		stand, base, mid = standUnder(m)
		if not (r and stand) then break end
		lastSurface = base
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(stand, mid)
		if os.clock() - toolCheck > 1 then -- меч «выпал» из ActiveTool — удары идут впустую
			toolCheck = os.clock()
			local at = gameTool()
			if not holds(at, tool) then tool = weaponFor(m) or tool end
		end
		swing(tool)
		if mhp() < lastHp - 0.01 then lastHp, lastHit = mhp(), os.clock() end
		if os.clock() - lastHit > 1.2 then -- урона нет: следующая позиция из списка
			killIdx = killIdx % #killCands + 1
			lastHit, misses = os.clock(), misses + 1
			-- два круга без урона, или нас бьёт кто-то другой, пока цель неуязвима (моб за стеной) — бросаем
			-- бросаем: два круга без урона, или цель неуязвима, а бьёт нас кто-то другой (он ближе цели)
			local other = enemies(30)[1]
			if misses > #killCands * 2 or (misses >= 2 and hpPct() < myHp0 - 5 and other and other ~= m) then nodmg = true; break end
		end
		if CONFIG.KillTimeout > 0 and os.clock() - t0 > CONFIG.KillTimeout then break end
		if hpPct() < (m:GetAttribute("FuelLeechState") and 25 or CONFIG.GuardHpPct) then break end -- мало HP: бросаем бой, дальше сработает укрытие
		RunService.Heartbeat:Wait()
	end
	Moving = false
	local dead = not m.Parent or h.Health <= 0 or mhp() <= 0
	if dead then Stats.kills += 1 elseif nodmg then killSkip[m] = os.clock() + 20 elseif hpPct() >= CONFIG.GuardHpPct then killSkip[m] = os.clock() + 30 end
	local at = gameTool()
	status(("[Kill] %s: %s за %.1fс%s"):format(m.Name, dead and "убит" or "не убил", os.clock() - t0,
		dead and "" or (" (поз.%d, меч в руке: %s)"):format(killIdx, tostring(holds(at, tool)))))
end

-- Орда: бьём крайнего моба с дистанции (меч достаёт на ~14 st, гоблины — ближе), стоя со стороны, противоположной
-- толпе; после каждого кадра встаём заново (мобы подходят). Если урон не идёт — подходим ближе.
local function hordeKill(m, center)
	local h = m:FindFirstChildOfClass("Humanoid")
	local tool = weaponFor(m)
	if not (h and tool) then return end
	-- у каждого оружия своя дальность (атрибут Range); встаём чуть ближе предела
	local range = math.max(5, (tool:GetAttribute("Range") or 12) + 1) -- +3 из swing, минус запас 2
	local t0, hp, last = os.clock(), h.Health, os.clock()
	local fallback = false
	Moving = true
	while Running and (State.KillAura or busy()) and m.Parent and h.Health > 0 and os.clock() - t0 < 15 and hpPct() >= CONFIG.GuardHpPct do
		local r, p = hrp(), pos(m)
		if not (r and p) then break end
		local away = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		local stand = p + away * range
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z))
		swing(tool)
		if h.Health < hp then hp, last = h.Health, os.clock() end
		if os.clock() - last > 1.5 then
			if range <= 5 then fallback = true; break end -- с дистанции не бьётся (паук низкий и т.п.)
			range = math.max(5, range - 2); last = os.clock()
		end
		RunService.Heartbeat:Wait()
	end
	Moving = false
	if fallback and m.Parent and h.Health > 0 and hpPct() >= CONFIG.GuardHpPct then return DF_killClose(m) end
	local dead = not m.Parent or h.Health <= 0
	if dead then Stats.kills += 1 else killSkip[m] = os.clock() + 10 end
	status(("[Horde] %s: %s за %.1fс (дистанция %d)"):format(m.Name, dead and "убит" or "не убил", os.clock() - t0, range))
end

-- Одиночная цель: с максимальной дальности оружия, со стороны игрока; не бьётся — hordeKill сам подойдёт вплотную
local function killOne(m)
	local r, p = hrp(), pos(m)
	if not (r and p) or not m:FindFirstChildOfClass("Humanoid") or m:GetAttribute("FuelLeechState") then return DF_killClose(m) end
	return hordeKill(m, p * 2 - r.Position)
end

-- true — были монстры (шаг занят), false — убивать некого
local function killStep(radius, back)
	if Killing then return true end
	if #enemies(radius) == 0 then return false end
	Killing, Selling = true, true
	local r = hrp()
	local origin = r and r.CFrame
	pcall(function()
		while Running and (State.KillAura or busy()) do
			local list = enemies(radius)
			if #list == 0 or hpPct() < CONFIG.GuardHpPct then break end
			killOne(list[1])
		end
	end)
	Moving, Killing, Selling = false, false, false
	r = hrp()
	-- Aura возвращает на место (идёт фарм), Dungeon — поднимает на поверхность у последнего монстра
	if r then
		if back and origin then r.CFrame = origin
		elseif lastSurface then r.CFrame = CFrame.new(lastSurface + Vector3.new(0, 4, 0)) end
		r.AssemblyLinearVelocity = Vector3.zero
	end
	return true
end

----------------------------------------------------------------- GUARD
-- Лог урона: откуда прилетает (яд, токсичный туман или мобы рядом) — по нему настраиваем защиту
local function poisoned()
	local c = player.Character
	return c ~= nil and (c:GetAttribute("IsPoisoned") == true or c:GetAttribute("IsToxicFogPoisoned") == true)
end
local dmgHooked = setmetatable({}, { __mode = "k" })
lastHitAt = 0
task.spawn(function()
	while Running do
		local h = hum()
		if h and not dmgHooked[h] then
			dmgHooked[h] = true
			local last = h.Health
			table.insert(Connections, h.HealthChanged:Connect(function(v)
				if v < last - 1 then
					lastHitAt = os.clock()
					local near = {}
					for _, m in ipairs(enemies(40)) do table.insert(near, m.Name .. "@" .. math.floor(dist(m))) end
					if #near == 0 then -- кто бьёт издалека: ближайший живой моб в 300 st (включая пропущенных)
						local f, best, bd = workspace:FindFirstChild("Npc"), nil, nil
						for _, m in ipairs(f and f:GetChildren() or {}) do
							local d = pos(m) and dist(m)
							if d and d < 300 and (not bd or d < bd) then best, bd = m, d end
						end
						if best then table.insert(near, "дальний: " .. best.Name .. "@" .. math.floor(bd)) end
					end
					local c = player.Character
					status(("[DMG] -%.0f → %.0f%s%s %s"):format(last - v, v,
						c and c:GetAttribute("IsPoisoned") and " ЯД" or "", c and c:GetAttribute("IsToxicFogPoisoned") and " ТУМАН" or "",
						#near > 0 and table.concat(near, ",") or "мобов рядом нет"))
				end
				last = v
			end))
		end
		task.wait(1)
	end
end)

-- Все живые враги (включая пропущенных) — для выбора безопасного места
local function threats(center, radius)
	local out, folder = {}, workspace:FindFirstChild("Npc")
	if not folder then return out end
	for _, m in ipairs(folder:GetChildren()) do
		local h = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
		local p = h and h.Health > 0 and m:GetAttribute("NpcFaction") == "Enemy" and pos(m)
		if p and (p - center).Magnitude <= radius then table.insert(out, p) end
	end
	return out
end
-- Безопасная точка: 8 направлений вокруг бура на 250 st — та, что дальше всех от мобов. Стоять на месте
-- (даже под землёй) нельзя: дальнобойные (Crazy Miner, −17) достают и там. Уходим из зоны агрессии.
local function safeSpot(avoid)
	local d = getDrill()
	local center = d and pos(d) or (hrp() and hrp().Position)
	if not center then return end
	local danger = threats(center, 1000)
	local best, bestScore
	for k = 0, 7 do
		local a = k * math.pi / 4
		-- 600 st: дальше дистанции преследования мобов (ChaseDistance до 400); не внутри данжей
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 600
		local score = inZone(p) and -math.huge or math.huge
		for _, e in ipairs(danger) do score = math.min(score, flat(e, p)) end
		if score == math.huge then score = 1e6 end
		if avoid and flat(avoid, p) < 100 then score = score - 1000 end -- только что били тут
		if not bestScore or score > bestScore then best, bestScore = p, score end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Npc"), d }
	local hit = workspace:Raycast(best + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return CFrame.new(best.X, (hit and hit.Position.Y or center.Y) - 16, best.Z) -- под полом
end

-- Аптечки (Class=Medkit: Bandages +10% за 10 монет, Basic_Medkit ...): взять в руки и ActiveTool:Consume().
-- Регенерация ~0.4 HP/с — без аптечек укрытие длится минутами.
local function medkits()
	local out = {}
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(src and src:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("Class") == "Medkit" then table.insert(out, t) end
		end
	end
	-- сначала маленькие, чтобы не тратить большую аптечку на пару HP
	table.sort(out, function(a, b) return (a:GetAttribute("Health") or 0) < (b:GetAttribute("Health") or 0) end)
	return out
end
local healNext = 0
local function heal(belowPct)
	if os.clock() < healNext or hpPct() >= belowPct then return false end
	local h = hum()
	for _, t in ipairs(medkits()) do
		local gain = (t:GetAttribute("Health") or 0.1) * 100
		-- большая аптечка — только когда HP реально мало
		if hpPct() + gain <= 105 or t == medkits()[#medkits()] then
			local eq = knit("ToolService", "EquipTool")
			if not (eq and h) then return false end
			if t.Parent ~= player.Character then pcall(function() eq:InvokeServer(t) end); task.wait(0.3) end
			local at = gameTool()
			local h0 = h.Health
			-- лечимся в 500 st над землёй: туда мобы не достают и бинт не сбивают
			if h.SeatPart then driveStop() end
			local r0 = hrp()
			local back = r0 and r0.CFrame
			local hold = back and RunService.Heartbeat:Connect(function()
				local r = hrp()
				if r then r.Anchored = false; r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = back + Vector3.new(0, 500, 0) end
			end)
			task.wait(0.2)
			if at and at.Consume then pcall(at.Consume, at) end
			task.wait((t:GetAttribute("UseTime") or 1) + 0.3)
			if hold then
				hold:Disconnect()
				local r = hrp()
				if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = back end
			end
			healNext = os.clock() + 0.5
			if h.Health > h0 then
				Stats.heals = (Stats.heals or 0) + 1
				status(("[Heal] %s: HP %.0f → %.0f"):format(t:GetAttribute("DisplayName") or t.Name, h0, h.Health))
				return true
			end
			healNext = os.clock() + 5
			return false
		end
	end
	return false
end

-- Мало HP: слезаем с бура, улетаем в безопасную точку под землёй и ждём, пока HP восстановится
-- Есть ли смысл сидеть в укрытии: мобы у бура/рядом, яд, или HP совсем мало. Иначе HP восстанавливается
-- и за рулём — простаивать минутами незачем.
local function dangerNear()
	if hpPct() < 30 then return true end
	local d = getDrill()
	local c = d and pos(d)
	return (c and #enemies(70, c) > 0) or #enemies(40) > 0
end
local Hiding = false
local function hide(why, keep)
	local r = hrp()
	if not r or Hiding then return end
	Hiding = true
	driveStop()
	Stats.hides += 1
	status(("[Guard] HP %.0f%% — ухожу в укрытие (%s)%s"):format(hpPct(), why, poisoned() and " [яд]" or ""))
	local spot = safeSpot()
	Moving = true
	pcall(function()
		if not spot then return end
		local t0, lastHp, lastCheck = os.clock(), hpPct(), os.clock()
		while Running and (busy() or State.KillAura) and alive() and ((hpPct() < CONFIG.SafeHpPct and dangerNear()) or (keep and keep())) and os.clock() - t0 < 90
			and not (hpPct() >= 35 and leechOnDrill()) -- пиявка сосёт топливо — выходим её бить
			and not (fuelPct() < 5 and #fuelTools() > 0 and #enemies(15, pos(getDrill()) or r.Position) == 0) do -- пустой бак: заправить
			r = hrp()
			if not r then break end
			r.Anchored = false -- Anchored не реплицируется: для сервера мы оставались там, где нас били
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = spot
			if hpPct() < CONFIG.SafeHpPct and heal(CONFIG.SafeHpPct) then lastHp = hpPct() end
			if os.clock() - lastCheck > 2 then
				if hpPct() < lastHp - 2 then
					spot = safeSpot(spot.Position) or spot
					status("[Guard] достают и тут — меняю укрытие" .. (poisoned() and " (яд)" or ""))
				end
				lastHp, lastCheck = hpPct(), os.clock()
			end
			RunService.Heartbeat:Wait()
		end
	end)
	r = hrp()
	if r then r.Anchored = false; r.CFrame = r.CFrame + Vector3.new(0, 19, 0) end -- вылезти на поверхность
	Moving, Hiding = false, false
	status(("[Guard] HP %.0f%% — выхожу из укрытия"):format(hpPct()))
end

-- Перед сундуком/лутом: убить монстров рядом с целью (если HP позволяет). false — не вышло, цель пропускаем.
local function clearAround(p, radius)
	for _ = 1, 8 do
		local list = enemies(radius, p)
		if #list == 0 then return true end
		if hpPct() < CONFIG.GuardHpPct + 15 then return false end
		driveStop()
		killOne(list[1])
	end
	return #enemies(radius, p) == 0
end

-- Сундуки: ищем активные промпты сундуков/ящиков ("Interact", "Open Chest"...).
-- Пропускаем запертые (Locked=true у узла) и уже открытые.
local chestTried = setmetatable({}, { __mode = "k" })
local function chestInfo(prompt)
	local npc = workspace:FindFirstChild("Npc")
	if npc and prompt:IsDescendantOf(npc) then return nil end -- мимик — монстр, не сундук
	local node = prompt
	local isChest = false
	for _ = 1, 6 do
		node = node.Parent
		if not node or node == workspace then break end
		if node:GetAttribute("Locked") == true then return nil end
		local st = node:GetAttribute("ChestOpenState")
		if st and st ~= "Idle" then return nil end
		if node:GetAttribute("SessionChestId") or node:GetAttribute("RuntimeChestModel")
			or hasKey(node.Name, { "Chest", "Crate" }) then
			isChest = true
		end
	end
	return isChest
end
local chestNextScan = 0
-- Ближайший неоткрытый сундук в radius от center: false — сундуков нет, true — занимались сундуком
local function chestStep(center, radius)
	if os.clock() < chestNextScan then return false end
	chestNextScan = os.clock() + 1.5
	-- Enabled не проверяем: игра часто включает промпт сундука, только когда игрок рядом.
	-- Текст промпта тоже не важен — достаточно, что он висит на сундуке.
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and (chestTried[d] or 0) < os.clock() and chestInfo(d) then
			table.insert(list, d)
		end
	end
	local best, bd
	for _, pr in ipairs(list) do
		local p = pos(pr.Parent)
		if p and (p - center).Magnitude <= radius and (dungeonActive or not inZone(p)) then
			local d = dist(pr.Parent)
			if not bd or d < bd then best, bd = pr, d end
		end
	end
	if not best then return false end
	chestNextScan = 0 -- после сундука сразу ищем следующий
	chestTried[best] = os.clock() + 120 -- не открылся — вернёмся не раньше чем через 2 мин
	local chest = chestNode(best) or best.Parent
	driveStop()
	if not clearAround(pos(best.Parent), 25) then return true end
	if moveTo(best.Parent, collecting) then
		task.wait(0.3) -- дать игре включить промпт
		local wasOn = best.Enabled
		local function opened() return changed("chest", chest) or not best.Parent or (wasOn and not best.Enabled) end
		local ok = replay("chest", chest) or usePrompt(best, opened)
		if ok then Stats.chests += 1 end
		status((ok and "[Chest] открыт: " or "[Chest] не открылся (откройте один руками — скрипт выучит): ")
			.. chest:GetFullName() .. " | " .. best.ActionText)
		task.wait(1.2)
	end
	return true
end

local function highlightStep()
	local folder = workspace:FindFirstChild("Npc")
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") then
			local enemy = m:GetAttribute("NpcFaction") == "Enemy"
			local want = enemy and (#CONFIG.MonsterFilter == 0 or hasKey(m.Name, CONFIG.MonsterFilter))
			local h = m:FindFirstChild("_DF_HL")
			if State.Highlight and want and not h then
				h = Instance.new("Highlight")
				h.Name, h.FillColor, h.FillTransparency = "_DF_HL", CONFIG.HighlightColor, 0.6
				h.Parent = m
			elseif h and (not State.Highlight or not want) then
				h:Destroy()
			end
		end
	end
end

----------------------------------------------------------------- AUTO FARM
-- Лут: по одному предмету за шаг (между шагами заново проверяем HP/топливо/монстров)
local gearGain, wearItem -- ниже (магазин)
local function lootOne(center, radius, fuelOnly)
	local full = bagFull()
	local best, bd
	for _, it in ipairs(groundItems()) do
		local p = pos(it)
		local sid = it:GetAttribute("SessionSnapshotItemId")
		-- AdventureQuestProtected (напр. труп босса Simon) поднять нельзя; неудачи помним по ID — объект пересоздаётся
		if p and (p - center).Magnitude <= radius and (skipUntil[it] or 0) < os.clock() and (dungeonActive or not inZone(p))
			and not it:GetAttribute("AdventureQuestProtected") and (not sid or (skipIds[sid] or 0) < os.clock()) then
			local name = it:GetAttribute("DisplayName") or it.Name
			local isFuel = it:GetAttribute("Category") == "Fuel" or it:GetAttribute("Category") == "Corpse"
			local want
			if it:GetAttribute("ItemDatabaseId") == "Money_Sack" then want = not fuelOnly and isMySack(it)
			-- трупы: топливо (5–10) и товар (гоблин 10, Bandit Miner 380): берём для бака или если дорогие
			elseif it:GetAttribute("Category") == "Corpse" then
				want = not full and (fuelPct() < 85 or (it:GetAttribute("Value") or 0) >= 50)
			elseif fuelOnly then want = isFuel and not full
			else want = not full and (isFuel or ((it:GetAttribute("Value") or 0) >= CONFIG.ItemsMinValue
				and not hasKey(name, CONFIG.IgnoredItems)))
			end
			if want then
				local d = dist(it)
				if not bd or d < bd then best, bd = it, d end
			end
		end
	end
	if not best then return false end
	driveStop()
	local name = best:GetAttribute("DisplayName") or best.Name
	if not clearAround(pos(best), 25) then skipUntil[best] = os.clock() + 30; return true end
	if best:GetAttribute("ItemDatabaseId") == "Money_Sack" then
		if not grabSack(best) then skipUntil[best] = os.clock() + 30 end
		return true
	end
	if best:GetAttribute("Category") == "Armor" and gearGain and gearGain(best) then
		skipUntil[best] = os.clock() + 60
		wearItem(best)
		return true
	end
	if (pos(best) - (hrp() and hrp().Position or pos(best))).Magnitude < 600 or moveTo(best, collecting) then
		if pickupItem(best) then
			Stats.items += 1
			status("[Loot] подобрал: " .. name)
			task.wait(CONFIG.PickupDelay)
			return "picked"
		else
			skipUntil[best] = os.clock() + 60
			local sid = best:GetAttribute("SessionSnapshotItemId")
			if sid then skipIds[sid] = os.clock() + 300 end
			status("[Loot] не поднялся: " .. name)
		end
	else
		skipUntil[best] = os.clock() + 10
	end
	return true
end
-- подбор пачкой: после удачного подбора сразу берём следующий, пока рядом нет врагов (до 15 за шаг)
local function lootStep(center, radius, fuelOnly)
	local res = lootOne(center, radius, fuelOnly)
	if res ~= "picked" then return res end
	for _ = 1, 14 do
		if #enemies(30) > 0 or hpPct() < CONFIG.GuardHpPct then break end
		if lootOne(center, radius, fuelOnly) ~= "picked" then break end
	end
	return true
end

-- Переплавка: железная/золотая руда, брошенная в центр печи-кемпинга (FurnaceCampsite → OreConvertBox, тег ItemSwap),
-- становится слитком: Iron Ore → IronBar 150, Gold Ore → GoldBar 300. Печь-кемпинг есть не у каждой крепости.
local smeltOres = { Ore_Iron = true, Ore_Gold = true }
local function smeltStep()
	local camp = workspace:FindFirstChild("FurnaceCampsite")
	local list = {}
	for _, e in ipairs(invEntries()) do if smeltOres[e.Name] then table.insert(list, e) end end
	if not camp or #list == 0 then return false end
	local drop = knit("CarryInventoryService", "DropGroup")
	if not drop then return false end
	Phase = ("Переплавка руды (%d)"):format(#list)
	driveStop()
	local r = hrp()
	if not r then return false end
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.new(camp:GetPivot().Position + Vector3.new(0, 8, 0))
	pcall(function() player:RequestStreamAroundAsync(camp:GetPivot().Position, 5) end)
	local box
	for _ = 1, 20 do
		box = camp:FindFirstChild("OreConvertBox", true)
		if box then break end
		task.wait(0.25)
	end
	if not box then status("[Smelt] печь не прогрузилась"); return false end
	local before = {}
	for _, it in ipairs(workspace.Items:GetChildren()) do before[it] = true end
	local function center()
		local c = hrp()
		if c then c.AssemblyLinearVelocity = Vector3.zero; c.CFrame = box.CFrame end -- ровно в центр: с края руда падает мимо
	end
	Moving = true
	for _, e in ipairs(list) do
		for _ = 1, 3 do center(); task.wait(0.1) end
		pcall(function() drop:InvokeServer(e.Id) end)
		for _ = 1, 6 do center(); task.wait(0.1) end
	end
	for _ = 1, 15 do center(); task.wait(0.1) end
	Moving = false
	-- забрать слитки (и руду, если какая-то упала мимо). Свежий предмет сервер отдаёт только когда у него
	-- появится SessionSnapshotItemId (через 10–20 с) — раньше мы его не ждали, и слитки оставались у печи
	local bars, got, t0 = 0, {}, os.clock()
	Phase = "Переплавка: жду слитки"
	repeat
		for _, it in ipairs(workspace.Items:GetChildren()) do
			local pp = not before[it] and not got[it] and pos(it)
			if pp and (pp - box.Position).Magnitude < 30 and it:GetAttribute("SessionSnapshotItemId") and pickupItem(it) then
				got[it] = true
				if it.Name:find("Bar") then bars += 1 end
			end
		end
		local n = 0
		for _ in pairs(got) do n += 1 end
		if n >= #list then break end
		task.wait(0.5)
	until os.clock() - t0 > 25 or not busy()
	status(("[Smelt] переплавлено: %d руды → %d слитков"):format(#list, bars))
	return true
end

-- Продажа: сумка заполнена и рядом с буром есть стол продажи
local sellNext = 0
-- BOUNTY: у Ozy (лагерь охотника в крепостях) трупы мобов с пометкой bounty (HasBounty) продаются дороже.
-- Выкидываем все трупы на BountySellHitBox; то, что без bounty, подбираем обратно (уйдёт на обычный стол/в печь).
DF_bountyStep = function(center)
	local pads = findAll(function(d)
		return d:IsA("BasePart") and d.Name == "BountySellHitBox" and not d:GetFullName():find("CutScene", 1, true)
	end)
	local pad, bd
	for _, p in ipairs(pads) do
		local d = flat(p.Position, center)
		if d <= CONFIG.WorkRadius and (not bd or d < bd) then pad, bd = p, d end
	end
	if not pad then return false end
	local list = {}
	for _, e in ipairs(invEntries()) do if e.Category == "Corpse" and not hasKey(tostring(e.Rarity or ""), CONFIG.SellKeepRarity) then table.insert(list, e) end end
	if #list == 0 then return false end
	local folder, dropRf = workspace:FindFirstChild("Items"), knit("CarryInventoryService", "DropGroup")
	if not (folder and dropRf) then return false end
	Phase = "Продажа bounty"
	driveStop()
	if not clearAround(pad.Position, 30) then return false end
	local c0 = call("CurrencyService", "GetCurrency")
	local before = {}
	for _, it in ipairs(folder:GetChildren()) do before[it] = true end
	for _, e in ipairs(list) do
		tp(pad, Vector3.new(0, 4, 0))
		pcall(function() dropRf:InvokeServer(e.Id) end)
		task.wait(0.1)
	end
	task.wait(2)
	local back, sold = 0, 0
	for _, it in ipairs(folder:GetChildren()) do
		if not before[it] and it:GetAttribute("Category") == "Corpse" then
			if it:GetAttribute("HasBounty") then sold += 1 else back += 1; pickupItem(it) end
		end
	end
	local c1 = call("CurrencyService", "GetCurrency")
	status(("[Bounty] выкинул %d трупов, bounty %d, без bounty вернул %d, монеты %s → %s"):format(#list, sold, back, tostring(c0), tostring(c1)))
	return true
end

local function sellStep(center, force)
	local n, cap = bagUsage()
	if not force and not (n and cap and cap > 0 and n / cap * 100 >= CONFIG.SellAtPct) then return false end
	if not force and os.clock() < sellNext then return false end
	-- после продажи в сумке остаётся непродаваемое (топливо, аптечки, редкое) — снова едем, только когда прибавилось
	if not force and DF_sellLeft and n <= DF_sellLeft + 2 then return false end
	sellNext = os.clock() + 4
	local best, bd
	for _, sp in ipairs(findSellParts()) do
		local d = flat(sp.Position, center)
		if (force or d <= CONFIG.WorkRadius) and (not bd or d < bd) then best, bd = sp, d end
	end
	if not best then return false end
	pcall(smeltStep) -- руду — в слитки перед продажей (слитки дороже)
	pcall(DF_bountyStep, center)
	Phase = "Продажа"
	driveStop()
	if not clearAround(best.Position, 30) then return false end
	tp(best)
	Selling = true
	local ok, err = pcall(sellAll, best)
	Selling = false
	if ok then Stats.sells += 1 else status("[Sell] ошибка: " .. tostring(err)) end
	sellNext = os.clock() + 20
	DF_sellLeft = bagUsage() -- глобал: у главного блока лимит 200 локальных
	return true
end

-- Магазин крепости: товар (тег ShopItem) перетаскиваем на стол у кассы (DragService.Request → PivotTo → Cancel),
-- затем ShopService.Buy(касса) — платим МОНЕТАМИ (проверено: 215 → 115). Стенд брони за Robux (ArmorSaleStand) не трогаем.
local CS = game:GetService("CollectionService")
local shopSkip = setmetatable({}, { __mode = "k" })
local shopNext = 0
local function bestOwned(pred)
	local best = 0
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(src and src:GetChildren() or {}) do
			if (t:IsA("Tool") or t:IsA("Model")) and pred(t) then best = math.max(best, t:GetAttribute("Damage") or 0) end
		end
	end
	return best
end
-- насколько товар лучше того, что есть (nil — не нужен)
local shopCoins = 0
-- скорость надетых ботинок: на персонаже висит модель брони с атрибутом SpeedBoost (если нет — запомненное при надевании)
local bootSpeed = 0
local function wornBootSpeed()
	local c, best = player.Character, nil
	for _, d in ipairs(c and c:GetDescendants() or {}) do
		local sp = d:GetAttribute("SpeedBoost")
		if type(sp) == "number" and not d:IsA("Tool") and not d:FindFirstAncestorOfClass("Tool") then best = math.max(best or 0, sp) end
	end
	return best or bootSpeed
end
gearGain = function(it)
	local cat, dmg = it:GetAttribute("Category"), it:GetAttribute("Damage") or 0
	if cat == "Melee" and it:GetAttribute("ActionType") == "Swing" then
		local have = bestOwned(function(t) return t:GetAttribute("Category") == "Melee" end)
		return dmg > have and (dmg - have) / math.max(have, 1) or nil
	elseif cat == "Pickaxe" then
		local have = bestOwned(function(t) return t:GetAttribute("Class") == "Pickaxe" or t.Name:find("Pickaxe") ~= nil end)
		return dmg > have and (dmg - have) / math.max(have, 1) * 0.5 or nil -- кирка важнее меча только для угля
	elseif it:GetAttribute("Class") == "Medkit" then
		-- запас аптечек: до MedkitStock штук, выгоднее — больше HP за монету
		local band = it.Name:find("Bandage") ~= nil
		if band then
			local n = 0
			for _, t in ipairs(medkits()) do if t.Name:find("Bandage") then n += 1 end end
			if n >= CONFIG.BandageStock then return nil end
		elseif #medkits() >= CONFIG.MedkitStock then return nil end
		-- дорогие аптечки (Golden за 1000) — только если монет много: апгрейды бура важнее
		if (it:GetAttribute("Cost") or 0) > math.max(100, shopCoins * 0.15) then return nil end
		return (it:GetAttribute("Health") or 0.1) * 100 / math.max(it:GetAttribute("Cost") or 1, 1) * 0.05
	elseif cat == "Armor" then
		local slot = it:GetAttribute("ArmorType")
		slot = slot == "Head" and "Helmet" or slot
		local c, a = player.Character, it:GetAttribute("Armor") or 0
		local have = c and slot and (c:GetAttribute(slot) or 0) or math.huge
		if a > have then return (a - have) / math.max(have, 5) end
		-- скоростные ботинки: брони 0, ценность — SpeedBoost (Diamond +4, Rusty +1)
		local sp = it:GetAttribute("SpeedBoost") or 0
		if slot == "Boots" and a == have and sp > wornBootSpeed() then return 0.2 + (sp - wornBootSpeed()) * 0.05 end
		return nil
	end
end
-- Броня надевается «другой кнопкой»: Interact (E) по модели брони в мире (Pickup лишь кладёт её в рюкзак).
-- Проверено: Steel Helmet → Armor 50 → 60.
wearItem = function(it)
	local inter = knit("InteractionService", "Interact")
	local c = player.Character
	local p = pos(it)
	if not (inter and c and p) then return false end
	local a0 = c:GetAttribute("Armor") or 0
	local r = hrp()
	if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = CFrame.new(p + Vector3.new(0, 3, 2)) end
	task.wait(0.3)
	pcall(function() inter:InvokeServer(it) end)
	task.wait(0.8)
	local a1 = c:GetAttribute("Armor") or 0
	status(("[Gear] надел %s: броня %s → %s"):format(it:GetAttribute("DisplayName") or it.Name, tostring(a0), tostring(a1)))
	if it:GetAttribute("ArmorType") == "Boots" and not it.Parent then bootSpeed = it:GetAttribute("SpeedBoost") or bootSpeed end
	return a1 > a0 or not it.Parent
end
-- Броня, уже лежащая в рюкзаке (подобрана раньше): выбросить и надеть через Interact
local armorTried = {}
local function armorStep()
	-- самый выгодный кусок брони из рюкзака (а не первый попавшийся)
	local best, bg
	for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(src and src:GetChildren() or {}) do
			local id = t:IsA("Tool") and t:GetAttribute("Category") == "Armor" and t:GetAttribute("CarryItemId")
			if id and (armorTried[id] or 0) < os.clock() then
				local g = gearGain(t)
				if g and (not bg or g > bg) then best, bg = t, g end
			end
		end
	end
	if not best then return false end
	local id, name = best:GetAttribute("CarryItemId"), best:GetAttribute("DisplayName") or best.Name
	armorTried[id] = os.clock() + 60 -- не вышло — повторим через минуту
	driveStop()
	local eq, drop = knit("ToolService", "EquipTool"), knit("ToolService", "Drop")
	if not (eq and drop) then return false end
	-- в руке должен оказаться именно этот предмет: иначе Drop выкинет другой
	for _ = 1, 3 do
		if holds(gameTool(), best) then break end
		pcall(function() eq:InvokeServer(best) end)
		task.wait(0.4)
	end
	if not holds(gameTool(), best) then status("[Gear] не взял в руки: " .. name); return true end
	local before = {}
	for _, it in ipairs(workspace.Items:GetChildren()) do before[it] = true end
	pcall(function() drop:InvokeServer() end)
	local w
	for _ = 1, 10 do
		task.wait(0.2)
		for _, it in ipairs(workspace.Items:GetChildren()) do
			if it:GetAttribute("SessionSnapshotItemId") == id or (not before[it] and it.Name == best.Name) then w = it end
		end
		if w then break end
	end
	if w then wearItem(w) else status("[Gear] выброшенная броня не найдена: " .. name) end
	return true
end
-- far: ближайший магазин где угодно (летим туда, прогружаем), а не только у бура
local function shopStep(center, far)
	if not far and os.clock() < shopNext then return false end
	shopNext = os.clock() + 10
	local coins = call("CurrencyService", "GetCurrency")
	if type(coins) ~= "number" or coins <= 0 then return false end
	shopCoins = coins
	local bp
	for _, b in ipairs(CS:GetTagged("BuyPart")) do
		if b:IsA("BasePart") and not b:GetFullName():find("CutScene", 1, true) then
			local d = flat(b.Position, center)
			if (far or d <= CONFIG.WorkRadius) and (not bp or d < flat(bp.Position, center)) then bp = b end
		end
	end
	if not bp then return false end
	if far then
		-- товары грузятся только рядом: летим к кассе и ждём прогрузки
		local r = hrp()
		if r and (r.Position - bp.Position).Magnitude > 100 then
			driveStop()
			Phase = "Лечу в магазин"
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(bp.Position + Vector3.new(0, 4, 8))
			pcall(function() player:RequestStreamAroundAsync(bp.Position, 5) end)
			task.wait(1)
		end
	end
	local best, bestGain
	for _, it in ipairs(workspace.Items:GetChildren()) do
		local cost = it:GetAttribute("Cost")
		local p = cost and not shopSkip[it] and CS:HasTag(it, "ShopItem") and not it:FindFirstAncestor("ArmorSaleStand") and pos(it)
		if p and cost <= coins and (p - bp.Position).Magnitude < 150 then
			local g = gearGain(it)
			if g and (not bestGain or g > bestGain) then best, bestGain = it, g end
		end
	end
	if not best then return false end
	local req, cancel, buy = knit("DragService", "Request"), knit("DragService", "Cancel"), knit("ShopService", "Buy")
	if not (req and cancel and buy) then return false end
	Phase = "Покупка снаряжения"
	driveStop()
	local name, cost = best:GetAttribute("DisplayName") or best.Name, best:GetAttribute("Cost")
	shopSkip[best] = true -- одна попытка на товар
	local r = hrp()
	if not r then return true end
	Moving = true
	pcall(function()
		local top = bp.CFrame + Vector3.new(0, bp.Size.Y / 2 + 0.8, 0)
		local placed = false
		for try = 1, 3 do
			r = hrp()
			if not r then return end
			r.CFrame = CFrame.new(pos(best) + Vector3.new(0, 3, 4)); task.wait(0.4)
			if req:InvokeServer(best) ~= true then status("[Shop] не взял: " .. name); return end
			-- держим товар на столе каждый кадр, пока сервер не засчитает (иначе он падает со стола)
			local t0 = os.clock()
			while os.clock() - t0 < 1.5 do
				r = hrp()
				if r then r.CFrame = CFrame.new(bp.Position + Vector3.new(0, 2, 6)) end
				pcall(function()
					best:PivotTo(top)
					for _, d in ipairs(best:GetDescendants()) do if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero end end
				end)
				RunService.Heartbeat:Wait()
			end
			cancel:InvokeServer(false)
			for _ = 1, 10 do
				if (bp:GetAttribute("Cost") or 0) > 0 then placed = true; break end
				task.wait(0.1)
			end
			if placed then break end
			status(("[Shop] %s не лёг на стол (попытка %d)"):format(name, try))
		end
		if not placed then return end
		-- на столе ровно наш товар и хватает монет
		local quote = call("ShopService", "GetBuyQuote", bp)
		if type(quote) ~= "number" or quote <= 0 or quote > cost or quote > coins then
			status(("[Shop] касса: %s (ждали %s) — не покупаю"):format(tostring(quote), tostring(cost))); return
		end
		buy:InvokeServer(bp)
		-- ждём списания монет, а не фиксированную секунду
		local after
		for _ = 1, 8 do
			task.wait(0.15)
			after = call("CurrencyService", "GetCurrency")
			if type(after) == "number" and after < coins then break end
		end
		if type(after) ~= "number" or after >= coins then status("[Shop] покупка не прошла: " .. name); return end
		Stats.bought = (Stats.bought or 0) + 1
		shopNext = os.clock() + 1 -- купили — сразу смотрим следующий товар
		status(("[Shop] куплено: %s за %d монет"):format(name, coins - after))
		r = hrp()
		if r then r.CFrame = CFrame.new(pos(best) + Vector3.new(0, 3, 3)) end
		task.wait(0.3)
		if best:GetAttribute("Category") == "Armor" then wearItem(best) else pickupItem(best) end
	end)
	Moving = false
	return true
end
-- поход в дальний магазин: покупаем всё нужное за один заход
local function farShop(center)
	local any = false
	for _ = 1, 8 do
		if not shopStep(center, true) then break end
		any = true
	end
	return any
end

-- Подземелья. Модели ворот перезагружаются (streaming), поэтому «пройденные» помним по позиции.
-- пройденные ворота переживают перезапуск скрипта (в пределах одного забега)
local gateDone = getgenv and (getgenv().DF_GateDone or {}) or {}
if getgenv then getgenv().DF_GateDone = gateDone end
local gateTries = {}
local function gateKey(g)
	local p = pos(g)
	return p and (math.floor(p.X / 20) .. ":" .. math.floor(p.Z / 20))
end
local function gateNear(center)
	for _, g in ipairs(workspace:GetChildren()) do
		if g:IsA("Model") and g.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName then
			local p, k = pos(g), gateKey(g)
			if p and k and not gateDone[k] and flat(p, center) <= CONFIG.GateStopDist then return g, k end
		end
	end
end
-- у каждых ворот два промпта: "Enter" (вход, у ворот) и "Exit" (выход, внутри данжа)
local function enterPrompt(g)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == CONFIG.GatePromptKey then return d end
	end
end
local function promptPos(pr)
	return pr.Parent:IsA("Attachment") and pr.Parent.WorldPosition or pos(pr.Parent)
end
local dungeonIdle, dungeonStart = 0, 0
local curGate, waveWaitAt -- текущий данж (модель ворот: внутри Wave, Arena) и начало ожидания волны
local function enterGate(g, key)
	gateTries[key] = (gateTries[key] or 0) + 1
	if gateTries[key] >= 3 then gateDone[key] = true end
	driveStop()
	local gp = pos(g)
	if not clearAround(gp, 40) then gateDone[key] = true; return end
	if dist(g) > 40 and not moveTo(g, collecting) then return end
	pcall(function() player:RequestStreamAroundAsync(gp, 5) end)
	local pr
	for _ = 1, 20 do
		pr = enterPrompt(g)
		if pr then break end
		task.wait(0.25)
	end
	if not pr then
		gateDone[key] = true
		status("[Dungeon] у ворот нет промпта Enter: " .. g.Name)
		return
	end
	local r = hrp()
	local target = promptPos(pr)
	if r and target then r.CFrame = CFrame.new(target + Vector3.new(0, 3, 4)) end
	task.wait(0.4)
	status("[Dungeon] вход: " .. g.Name)
	local from = r and r.Position
	local function entered()
		local c = hrp()
		return c and from and (c.Position - from).Magnitude > 100
	end
	if not usePrompt(pr, entered) then
		local inter = knit("InteractionService", "Interact")
		if inter then pcall(function() inter:InvokeServer(pr.Parent.Parent) end) end
	end
	for _ = 1, 20 do if entered() then break end task.wait(0.25) end
	if entered() then
		dungeonActive = true
		table.clear(killSkip) -- снаружи/внутри урон считается по-разному: старые пропуски не в счёт
		gateDone[key] = true
		Stats.dungeons += 1
		dungeonStart, dungeonIdle = os.clock(), os.clock()
		curGate, waveWaitAt = g, 0
		status("[Dungeon] вошёл: " .. g.Name)
	else
		status("[Dungeon] вход не сработал: " .. g.Name)
	end
end
-- скрипт перезапустили, когда персонаж уже внутри данжа: продолжаем его, а не улетаем к буру
do
	local r = hrp()
	if r and inZone(r.Position) then
		local best, bd
		for _, g in ipairs(workspace:GetChildren()) do
			if g:IsA("Model") and g.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName then
				for _, d in ipairs(g:GetDescendants()) do
					if d:IsA("ProximityPrompt") and d.ActionText == "Exit" then
						local p = promptPos(d)
						if p and flat(p, r.Position) < 260 and (not bd or flat(p, r.Position) < bd) then best, bd = g, flat(p, r.Position) end
					end
				end
			end
		end
		if best then
			dungeonActive, curGate, waveWaitAt = true, best, 0
			dungeonStart, dungeonIdle = os.clock(), os.clock()
			local k = gateKey(best)
			if k then gateDone[k] = true end
			status("[Dungeon] продолжаю после перезапуска: " .. best.Name)
		end
	end
end

local curPit -- текущая паучья яма (SpiderPit), если мы в ней
local function exitDungeon(why)
	status("[Dungeon] выход: " .. why)
	local r = hrp()
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		-- только выход из данжа (у SpiderPit тоже есть Exit)
		if d:IsA("ProximityPrompt") and d.ActionText == "Exit" and (d:GetFullName():find(".Dungeon_", 1, true)
			or (curPit and d:IsDescendantOf(curPit))) then
			local p = promptPos(d)
			local dd = p and r and (p - r.Position).Magnitude
			if dd and (not bd or dd < bd) then best, bd = d, dd end
		end
	end
	if not best then status("[Dungeon] промпт Exit не найден"); dungeonActive = false; return false end
	moveTo(best.Parent, nil, promptPos(best) + Vector3.new(0, 3, 3))
	task.wait(0.3)
	local from = hrp() and hrp().Position
	local function out() local c = hrp(); return c and from and (c.Position - from).Magnitude > 100 end
	usePrompt(best, out)
	for _ = 1, 20 do if out() then break end task.wait(0.25) end
	if not out() then
		local inter = knit("InteractionService", "Interact")
		if inter then pcall(function() inter:InvokeServer(best.Parent.Parent) end) end
		task.wait(1.5)
	end
	if out() then dungeonActive = false; curPit = nil; table.clear(killSkip) end
	return not dungeonActive
end

-- Арена босса: дверь ArenaGate открывается (DoorOpen=true) — заходим внутрь, дальше обычная зачистка
local arenaVisited = setmetatable({}, { __mode = "k" })
local arenaNext = 0
local function arenaStep()
	if os.clock() < arenaNext then return false end
	arenaNext = os.clock() + 2
	local gates = {}
	for _, g in ipairs(workspace:GetChildren()) do
		if g.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName then table.insert(gates, g) end
	end
	for _, g in ipairs(gates) do for _, d in ipairs(g:GetDescendants()) do
		if d.Name == "ArenaGate" and d:GetAttribute("DoorOpen") == true then
			local arena = d.Parent
			local p = arena and pos(arena)
			if p and not arenaVisited[arena] then
				arenaVisited[arena] = true
				status("[Dungeon] арена открыта — захожу")
				moveTo(arena, collecting, p + Vector3.new(0, 4, 0))
				task.wait(1.5)
				return true
			end
		end
	end end
	return false
end

-- Данж: мобы у входа → арена (там стартует волна с боссом, Wave.WaveActive) → сундуки волны (Wave.ChestNodes)
-- за ареной → выход. Интерьер длиной ~700 st, поэтому ищем по всему данжу, а не в 250 st от игрока.
local function dungeonCenter()
	local arena = curGate and curGate.Parent and curGate:FindFirstChild("Arena", true)
	return arena and pos(arena), arena
end
local function idleChests(g)
	local out, wave = {}, g and g:FindFirstChild("Wave")
	local cn = wave and wave:FindFirstChild("ChestNodes")
	for _, n in ipairs(cn and cn:GetChildren() or {}) do
		-- открытый сундук теряет промпт, а ChestOpenState может остаться Idle — считаем только с живым промптом
		local pr = n:IsA("BasePart") and n:FindFirstChildWhichIsA("ProximityPrompt", true)
		if pr and pr.Enabled and (n:GetAttribute("ChestOpenState") or "Idle") == "Idle" then table.insert(out, n) end
	end
	return out
end
-- Паучья яма (SpiderPit): вход — встать на место очереди (тег DungeonQueueSpot у ворот), идёт отсчёт
-- (QueueState=Countdown, CountdownEndsAt) и телепорт внутрь. Внутри волны (CurrentWave/MaxWave, Enemy),
-- после последней — SpiderPitCompleted=true и сундуки (промпты Interact). Яма активна, только когда до неё
-- доехал бур (открытая территория).
local pitStep, pitRun
;(function() -- своя функция: у Luau лимит 200 локальных на функцию
local pitTried = {}
local function pitGatePos(m)
	local g = m:FindFirstChild("SpiderGate")
	return g and pos(g)
end
local function pitsNear(dp, radius)
	local out = {}
	for _, m in ipairs(workspace:GetChildren()) do
		local id = m:GetAttribute("SpiderPitId")
		local gp = id and m:GetAttribute("SpiderPitCompleted") ~= true and pitGatePos(m)
		if gp and flat(gp, dp) <= radius and (pitTried[id] or 0) < os.clock() then table.insert(out, m) end
	end
	return out
end
pitStep = function(dp, radius)
	if hpPct() < CONFIG.SafeHpPct then return false end
	local pit = pitsNear(dp, radius or 400)[1]
	if not pit then return false end
	local id, gp = pit:GetAttribute("SpiderPitId"), pitGatePos(pit)
	pitTried[id] = os.clock() + 60 -- не пустили — повторим через минуту
	driveStop()
	Phase = "Паучья яма: встаю в очередь"
	local r = hrp()
	if not r then return true end
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.new(gp.X, gp.Y + 10, gp.Z)
	pcall(function() player:RequestStreamAroundAsync(gp, 5) end)
	local spot
	for _ = 1, 12 do
		for _, q in ipairs(CS:GetTagged("DungeonQueueSpot")) do
			if q:IsA("BasePart") and q:IsDescendantOf(pit) then spot = q end
		end
		if spot then break end
		task.wait(0.25)
	end
	if not spot then status("[Pit] место очереди не найдено"); return true end
	-- встать ногами (сервер считает игроков на площадке) и ждать отсчёт → телепорт
	r = hrp()
	if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = spot.CFrame + Vector3.new(0, 4, 0) end
	local from, t0 = r and r.Position, os.clock()
	while Running and busy() and os.clock() - t0 < 30 do
		local c = hrp()
		if not c then break end
		if player:GetAttribute("InDungeon") == true or (from and (c.Position - from).Magnitude > 150) then
			dungeonActive, curPit, curGate = true, pit, nil
			dungeonStart, dungeonIdle = os.clock(), os.clock()
			table.clear(killSkip)
			Stats.dungeons += 1
			status("[Pit] вошёл в паучью яму (сложность " .. tostring(pit:GetAttribute("Difficulty")) .. ")")
			return true
		end
		local st = spot:GetAttribute("QueueState")
		Phase = st == "Countdown" and ("Паучья яма: отсчёт %d с"):format(math.max(0, math.ceil((spot:GetAttribute("CountdownEndsAt") or 0) - workspace:GetServerTimeNow())))
			or "Паучья яма: жду очередь"
		-- 8 с без отсчёта — яма ещё закрыта (бур не доехал / кто-то внутри)
		if os.clock() - t0 > 8 and st ~= "Countdown" then break end
		if (c.Position - spot.Position).Magnitude > 25 then c.CFrame = spot.CFrame + Vector3.new(0, 4, 0) end
		task.wait(0.25)
	end
	status(("[Pit] не пустили (очередь: %s, игроков %s)"):format(tostring(spot:GetAttribute("QueueState")), tostring(spot:GetAttribute("PlayerCount"))))
	return true
end
pitRun = function()
	local pit = curPit
	Phase = ("Паучья яма: волна %s/%s"):format(tostring(pit:GetAttribute("CurrentWave")), tostring(pit:GetAttribute("MaxWave")))
	if hpPct() < 60 and #enemies(60) > 0 then exitDungeon("мало HP"); return end
	local list = enemies(400)
	if #list > 0 then
		killOne(list[1])
		dungeonIdle = os.clock()
		return
	end
	local r = hrp()
	if not r then return end
	-- сундуки и лут (после последней волны)
	if chestStep(r.Position, 600) then Phase = "Паучья яма: сундуки"; dungeonIdle = os.clock(); return end
	if lootStep(r.Position, 400) then dungeonIdle = os.clock(); return end
	if pit:GetAttribute("SpiderPitCompleted") == true then
		if os.clock() - dungeonIdle > 6 then
			pitTried[pit:GetAttribute("SpiderPitId") or ""] = math.huge
			exitDungeon("паучья яма пройдена")
		end
		return
	end
	-- волны идут по таймеру: ждём; совсем долго ничего не происходит — выходим
	if os.clock() - dungeonIdle > 60 or os.clock() - dungeonStart > 900 then exitDungeon("в яме ничего не происходит") end
end
end)() -- (паучьи ямы)

local function dungeonRun()
	if curPit then return pitRun() end
	Phase = "Подземелье"
	-- в данже мобы преследуют и в укрытии: при опасности сразу выходим
	if hpPct() < 60 and #enemies(60) > 0 then exitDungeon("мало HP"); return end
	local r = hrp()
	if not r then return end
	local ac, arena = dungeonCenter()
	-- мобы: по всему данжу (вокруг арены 450 st) и рядом с нами
	local list = enemies(CONFIG.DungeonRadius)
	if #list == 0 and ac then list = enemies(450, ac) end
	if #list > 0 then
		Phase = "Подземелье: бой"
		killOne(list[1])
		dungeonIdle = os.clock()
		return
	end
	local wave = curGate and curGate:FindFirstChild("Wave")
	if wave and wave:GetAttribute("WaveCompleted") ~= true then
		if wave:GetAttribute("WaveActive") == true then
			Phase = "Подземелье: волна (жду мобов)"
			dungeonIdle = os.clock()
			task.wait(0.5)
			return
		end
		-- волна стартует касанием зоны Wave.WaveTrigger (проверено: WaveActive → true, идут мобы)
		local trig = wave:FindFirstChild("WaveTrigger")
		if waveWaitAt == 0 then waveWaitAt = os.clock() end
		if trig and waveWaitAt ~= math.huge and os.clock() - waveWaitAt < 30 then
			Phase = "Подземелье: запускаю волну (с боссом)"
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = trig.CFrame
			touch(trig)
			dungeonIdle = os.clock()
			task.wait(0.5)
			return
		end
		if waveWaitAt ~= math.huge then status("[Dungeon] волна не стартовала за 30 с — иду к сундукам") end
		waveWaitAt = math.huge
	end
	-- сундуки волны (за ареной)
	for _, n in ipairs(idleChests(curGate)) do
		if chestStep(n.Position, 40) then Phase = "Подземелье: сундуки"; dungeonIdle = os.clock(); return end
	end
	if chestStep(r.Position, CONFIG.DungeonRadius) then dungeonIdle = os.clock(); return end
	if lootStep(r.Position, CONFIG.DungeonRadius) then dungeonIdle = os.clock(); return end
	if arenaStep() then dungeonIdle = os.clock(); return end
	if os.clock() - dungeonIdle > 6 or os.clock() - dungeonStart > 600 then exitDungeon("зачищено") end
end

-- Финальная стена слоя («босс»-стена): при ударе идёт волна врагов
local wallReady = setmetatable({}, { __mode = "k" })
local function finalWallAhead(dp)
	local f = workspace:FindFirstChild("RockWalls")
	if not f then return end
	for _, w in ipairs(f:GetChildren()) do
		local t = w:GetAttribute("Type")
		if w:IsA("BasePart") and t and t:find("Final") and (w:GetAttribute("Health") or 0) > 0
			and flat(w.Position, dp) <= CONFIG.WallStopDist then
			return w
		end
	end
end

-- Мозг авто-фарма: каждый тик выбираем самое важное дело
-- После смерти вещи лежат в сундуке смерти (модель с ItemDatabaseId/Name *DeathChest*): забираем первым делом
-- через DeathChestService.TakeAllItems(сундук) — так это делает сама игра.
local deathTried = setmetatable({}, { __mode = "k" })
-- в сервере могут быть другие игроки: чужой сундук смерти не трогаем (владелец — в атрибутах *Owner*/*Player*/*User*)
local function mineChest(it)
	for k, v in pairs(it:GetAttributes()) do
		if (k:find("Owner") or k:find("Player") or k:find("User")) and (type(v) == "number" or type(v) == "string") then
			if v ~= player.UserId and v ~= player.Name and v ~= tostring(player.UserId) and v ~= player.DisplayName then return false end
		end
	end
	return true
end
local function deathChestStep()
	local take = knit("DeathChestService", "TakeAllItems")
	if not take then return false end
	for _, it in ipairs(groundItems()) do
		local id = tostring(it:GetAttribute("ItemDatabaseId") or it.Name)
		if id:find("DeathChest") and (deathTried[it] or 0) < 3 and pos(it) and mineChest(it) then
			deathTried[it] = (deathTried[it] or 0) + 1
			Phase = "Забираю вещи из сундука смерти"
			driveStop()
			if not clearAround(pos(it), 25) and deathTried[it] < 3 then return true end
			local r = hrp()
			if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = CFrame.new(pos(it) + Vector3.new(0, 3, 3)) end
			task.wait(0.4)
			local ok, res = pcall(function() return take:InvokeServer(it) end)
			task.wait(1)
			status(("[Death] сундук смерти: %s"):format(it.Parent and ("не забрал (" .. tostring(res) .. ")") or "вещи забраны"))
			return true
		end
	end
	return false
end

-- Бур едет быстрее мобов (~30 st/с против ~16): от мобов у бура выгоднее уехать, чем драться/прятаться.
-- «Застрял» — за рулём, но за 4 с почти не сдвинулись (упёрлись в стену/скалу) — тогда уже бой.
-- мелкое состояние авто-фарма одной таблицей (у Luau лимит 200 локальных в файле)
local AS = { progAt = 0, farShopNext = 0, coinsAt2 = 0, farSellNext = 0, fogSellNext = 0, wallHitAt = 0, hordeFight = false }
local function drillStuck(dp)
	if not driveStarted then AS.progX, AS.progAt = dp, os.clock(); return false end
	if not AS.progX or (dp - AS.progX).Magnitude > 6 then AS.progX, AS.progAt = dp, os.clock(); return false end
	return os.clock() - AS.progAt > 4
end

local function coinsCache2()
	if os.clock() - AS.coinsAt2 > 5 then AS.coinsAt2 = os.clock(); local c = call("CurrencyService", "GetCurrency"); if type(c) == "number" then AS.coinsVal2 = c end end
	return AS.coinsVal2
end
-- Бинты по всем магазинам: магазин есть в каждой крепости (Workspace.Chunks.Fortresses, модели не выгружаются,
-- а касса BuyPart прогружается только рядом). Товар обновляется раз в ShopRestock — тогда, если бинтов мало,
-- летим в ближайшую пройденную крепость, ждём прогрузки кассы и покупаем.
AS.shopAt = getgenv and (getgenv().DF_ShopAt or {}) or {}
if getgenv then getgenv().DF_ShopAt = AS.shopAt end
AS.bandNext = 0
AS.bandageRun = function(dp, force)
	local f = workspace:FindFirstChild("Chunks") and workspace.Chunks:FindFirstChild("Fortresses")
	if not f then return false end
	local forts = {}
	for _, m in ipairs(f:GetChildren()) do
		-- в некоторых крепостях (Toxic) магазин — декорация без полок GeneralStore_Nodes и кассы
		local shop = m:FindFirstChild("GeneralStore_Nodes", true) and m:FindFirstChild("Shop", true)
		local ok, p = pcall(function() return shop:GetPivot().Position end)
		if ok then
			-- крепость у бура: её кассу shopStep и так проверяет каждые 10 с
			if flat(p, dp) <= CONFIG.WorkRadius then AS.shopAt[m.Name] = os.clock() end
			table.insert(forts, { name = m.Name, pos = p })
		end
	end
	if not force and os.clock() < AS.bandNext then return false end
	AS.bandNext = os.clock() + 20
	local n = 0
	for _, t in ipairs(medkits()) do if t.Name:find("Bandage") then n += 1 end end
	if n >= CONFIG.BandageStock or (coinsCache2() or 0) < 10 then return false end
	local best, bd
	for _, fo in ipairs(forts) do
		local d = flat(fo.pos, dp)
		-- только пройденные крепости (впереди бура — сплошной камень)
		if fo.pos.X <= dp.X + 50 and d <= CONFIG.BandageRunDist and os.clock() - (AS.shopAt[fo.name] or -1e9) > CONFIG.ShopRestock
			and (not bd or d < bd) then best, bd = fo, d end
	end
	if not best then return false end
	AS.shopAt[best.name] = os.clock()
	status(("[Shop] за бинтами: %s (%d st, бинтов %d)"):format(best.name, bd, n))
	driveStop()
	local r = hrp()
	if not r then return false end
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.new(best.pos + Vector3.new(0, 10, 0))
	pcall(function() player:RequestStreamAroundAsync(best.pos, 5) end)
	local t0 = os.clock()
	repeat
		task.wait(0.3)
		local found = false
		for _, b in ipairs(CS:GetTagged("BuyPart")) do if flat(b.Position, best.pos) < 400 then found = true end end
		if found then break end
	until os.clock() - t0 > 6
	local ok = farShop(best.pos)
	if not ok then status("[Shop] " .. best.name .. ": бинтов нет или касса не прогрузилась") end
	return true
end
local trackedDungeonRun, noDriveIdle -- ниже (раздел DUNGEON FARM)
AS.wallSeen = setmetatable({}, { __mode = "k" })

-- REVIVE: на трупе тимейта (модель с CorpsePlayerUserId) висит RevivePrompt. С ReviveKit в инвентаре
-- он бесплатный ("Revive"); без кита игра просит монеты ("Revive (N Coins)") — такой не жмём.
AS.revPrompts = setmetatable({}, { __mode = "k" })
AS.revTries = setmetatable({}, { __mode = "k" })
;(function()
	local function add(d) if d:IsA("ProximityPrompt") and d.Name == "RevivePrompt" then AS.revPrompts[d] = true end end
	for _, d in ipairs(workspace:GetDescendants()) do add(d) end
	table.insert(Connections, workspace.DescendantAdded:Connect(add))
end)()
AS.reviveKit = function()
	local c = player.Character
	return (c and c:FindFirstChild("ReviveKit")) or player.Backpack:FindFirstChild("ReviveKit")
end
AS.reviveStep = function()
	if not AS.reviveKit() or hpPct() < CONFIG.GuardHpPct then return false end
	local r = hrp()
	if not r then return false end
	local best, bd
	for pr in pairs(AS.revPrompts) do
		local corpse = pr.Parent and pr:FindFirstAncestorOfClass("Model")
		local uid = corpse and corpse:GetAttribute("CorpsePlayerUserId")
		local p = corpse and pos(corpse)
		if p and typeof(uid) == "number" and uid ~= player.UserId and (AS.revTries[pr] or 0) < 3 then
			local d = (p - r.Position).Magnitude
			if d < 300 and #enemies(20, p) == 0 and (not bd or d < bd) then best, bd = pr, d end
		end
	end
	if not best then return false end
	local corpse = best:FindFirstAncestorOfClass("Model")
	AS.revTries[best] = (AS.revTries[best] or 0) + 1
	Phase = "Воскрешаю тимейта"
	driveStop()
	if not moveTo(corpse) then return true end
	task.wait(0.3) -- игра обновляет ActionText, когда промпт показался
	if best.ActionText:find("Coin") then AS.revTries[best] = 99; status("[Revive] нужен кит, а не монеты — пропуск"); return true end
	local kits = 0
	for _, t in ipairs(player.Backpack:GetChildren()) do if t.Name == "ReviveKit" then kits += 1 end end
	local gone = function() return not best.Parent or not best.Enabled or not corpse.Parent or not AS.reviveKit() end
	-- честное удержание (сервер может проверять время), если не вышло — общий usePrompt
	pcall(function() best:InputHoldBegin(); task.wait(best.HoldDuration + 0.4); best:InputHoldEnd() end)
	task.wait(0.5)
	if not gone() then usePrompt(best, gone) end
	local ok = gone()
	local name = corpse.Name
	status(("[Revive] %s: %s (китов было %d)"):format(name, ok and "воскрешён" or "не вышло", kits))
	return true
end

-- SAVE GEAR: алтарь в церкви (~50 000 м и ~100 000 м) бесплатно уносит до Limit вещей в лобби и завершает заход.
-- Только живым через PlayerService.SaveGear; после смерти это покупка за Robux (PromptSaveGearPurchase) — её не трогаем.
;(function()
	AS.altars = getgenv and (getgenv().DF_Altars or {}) or {}
	if getgenv then getgenv().DF_Altars = AS.altars end
	local function note(p)
		if p:IsA("ProximityPrompt") and p.ActionText == "Save Gear" then
			local ok, at = pcall(function() return p.Parent:IsA("Attachment") and p.Parent.WorldPosition or p.Parent.Position end)
			if ok then AS.altars[math.floor(at.X / 50) .. ":" .. math.floor(at.Z / 50)] = at end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("ProximityPrompt") then note(d) end end
	table.insert(Connections, workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then task.defer(note, d) end end))

	local function findPrompt(near)
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.ActionText == "Save Gear" then
				local ok, at = pcall(function() return d.Parent.WorldPosition end)
				if ok and (not near or (at - near).Magnitude < 300) then return d, at end
			end
		end
	end
	-- что берём: вся броня, лучший меч, лучшая кирка, 1 ревайв-кит, дальше — по цене
	local function selection(ch)
		local tools = {}
		for _, src in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			for _, t in ipairs(src and src:GetChildren() or {}) do
				local id = t:GetAttribute("SessionSnapshotItemId") or t:GetAttribute("CarryItemId")
				if id then tools[id] = t end
			end
		end
		local function val(it) local t = tools[it.Id]; return t and (t:GetAttribute("Value") or t:GetAttribute("Cost")) or 0 end
		local function kind(it)
			local t, n = tools[it.Id], it.Name or ""
			if tostring(it.Id):sub(1, 6) == "armor:" or (t and t:GetAttribute("Category") == "Armor") then return "armor" end
			if n:find("Revive") then return "revive" end
			if n:find("Pickaxe") or (t and t:GetAttribute("Class") == "Pickaxe") then return "pick" end
			if t and t:GetAttribute("Category") == "Melee" or n:find("Sword") then return "melee" end
			return "other"
		end
		local items = ch.Items or {}
		table.sort(items, function(a, b) return val(a) > val(b) end)
		local sel, n, limit = {}, 0, ch.Limit or 0
		local function add(it, cnt)
			cnt = math.min(cnt, limit - n, (it.Count or 1) - (sel[it.Id] or 0))
			if cnt > 0 then sel[it.Id] = (sel[it.Id] or 0) + cnt; n += cnt end
		end
		for _, it in ipairs(items) do if kind(it) == "armor" then add(it, it.Count or 1) end end
		for _, k in ipairs({ "melee", "pick", "revive" }) do
			for _, it in ipairs(items) do if kind(it) == k then add(it, 1); break end end
		end
		for _, it in ipairs(items) do add(it, it.Count or 1) end
		return sel, n
	end
	AS.saveSelection = selection

	-- бур не продвигается CONFIG.SaveGearStallMin минут — сохраняем лучшее (сразу, без алтаря)
	AS.saveStep = function(dp)
		if not CONFIG.SaveGearOnStall or State.NoDrive then return false end
		-- бур едет или ломает финальную стену (её HP падает) — это прогресс
		if not AS.stallX or math.abs(dp.X - AS.stallX) > 60 or os.clock() - AS.wallHitAt < 60 then AS.stallX, AS.stallAt = dp.X, os.clock(); return false end
		if os.clock() - AS.stallAt < CONFIG.SaveGearStallMin * 60 or os.clock() < (AS.saveNext or 0) then return false end
		AS.saveNext = os.clock() + 120
		Phase = "Бур не продвигается — сохраняю вещи"
		status(("[Save] бур стоит %d мин — сохраняю вещи"):format(CONFIG.SaveGearStallMin))
		AS.saveNow(dp, true)
		return true
	end
	-- лететь к ближайшему алтарю, сохранить лучшие вещи (сервер завершает заход и кидает в лобби); true = SaveGear вызван
	-- direct = сразу SaveGear без полёта к алтарю (проверено: сервер принимает и на ~6 000 м, вдали от алтаря)
	AS.saveNow = function(dp, direct)
		driveStop()
		local r = hrp()
		if not r then return false end
		local function hold(p, secs)
			local t0 = os.clock()
			while os.clock() - t0 < secs do
				local rr = hrp()
				if not rr then return end
				rr.Anchored = false; rr.AssemblyLinearVelocity = Vector3.zero; rr.CFrame = CFrame.new(p)
				RunService.Heartbeat:Wait()
			end
		end
		-- ближайший известный алтарь; нет — облетаем путь назад от бура
		local best
		if not direct then
			for _, at in pairs(AS.altars) do if not best or (at - dp).Magnitude < (best - dp).Magnitude then best = at end end
		end
		-- первый алтарь ~50 000 м (X≈19 500): мельче лететь назад незачем
		if not direct and not best and dp.X > 19000 then
			for x = dp.X - 300, math.max(dp.X - 30000, 18000), -800 do
				local p = Vector3.new(x, 150, -772)
				pcall(function() player:RequestStreamAroundAsync(p, 3) end)
				hold(p, 1)
				local _, at = findPrompt()
				if at then best = at; break end
			end
		end
		if best then
			pcall(function() player:RequestStreamAroundAsync(best, 5) end)
			hold(best + Vector3.new(0, 3, 0), 1.5)
			local prompt = findPrompt(best)
			if prompt and fireproximityprompt then pcall(fireproximityprompt, prompt) end
			task.wait(0.5)
		elseif not direct then
			status("[Save] алтарь не найден (первый на ~50 000 м) — пробую сохранить без него")
		end
		local ok, ch = pcall(function() return knit("PlayerService", "GetSaveGearChoices"):InvokeServer() end)
		if not (ok and type(ch) == "table") then status("[Save] список вещей не получен: " .. tostring(ch)); return false end
		local sel, n = selection(ch)
		local names = {}
		for _, it in ipairs(ch.Items or {}) do if sel[it.Id] then table.insert(names, it.Name .. "×" .. sel[it.Id]) end end
		status(("[Save] сохраняю %d/%d: %s"):format(n, ch.Limit or 0, table.concat(names, ", ")))
		local ok2, res = pcall(function() return knit("PlayerService", "SaveGear"):InvokeServer(sel) end)
		status("[Save] результат: " .. tostring(ok2) .. " " .. tostring(res))
		return ok2 and res ~= false
	end
end)()
local function autoStep()
	if not alive() then Phase = "Ждём возрождения"; return end
	if workspace:GetAttribute("InCutScene") == true then Phase = "Катсцена"; return end
	if heal(60) then Phase = "Лечусь"; return end
	if not inDungeon() and deathChestStep() then return end
	-- Fuel Leech присосался к буру и сосёт топливо — убиваем сразу (киркой), даже при невысоком HP
	local leech = not inDungeon() and hpPct() >= 35 and leechOnDrill()
	if leech then
		Phase = "Бью Fuel Leech (сосёт топливо)"
		driveStop()
		killOne(leech)
		return
	end
	if hpPct() < CONFIG.GuardHpPct then
		if inDungeon() then exitDungeon("мало HP") end
		-- аптечек нет, а монеты есть — в ближайший магазин за бинтами (быстрее, чем ждать регенерацию)
		if not inDungeon() and #medkits() == 0 and os.clock() > AS.farShopNext and (coinsCache2() or 0) >= 10 then
			AS.farShopNext = os.clock() + 60
			if farShop(hrp() and hrp().Position or Vector3.zero) then heal(CONFIG.SafeHpPct); return end
			local dd = getDrill()
			if dd and AS.bandageRun(pos(dd), true) then heal(CONFIG.SafeHpPct); return end
		end
		local d0 = getDrill()
		local f0 = d0 and d0:GetAttribute(CONFIG.FuelAttr) or 0
		if not State.NoDrive and hpPct() >= 35 and not poisoned() and d0 and f0 >= CONFIG.DriveMinFuel and not drillStuck(pos(d0))
			and #enemies(16, pos(d0)) == 0 and #enemies(12) == 0
			and not gateNear(pos(d0)) -- рядом недолутанный данж: восстанавливаемся и возвращаемся, а не уезжаем
			and not finalWallAhead(pos(d0)) then
			heal(CONFIG.GuardHpPct)
			Phase = "Мало HP — уезжаю от мобов"
			drive()
			return
		end
		if dangerNear() then
			Phase = "Укрытие (мало HP)"
			hide("мало HP")
			return
		end
		Phase = "Мало HP, мобов нет — еду дальше"
	end
	if AS.reviveStep() then return end
	if inDungeon() then return trackedDungeonRun() end

	local drill = getDrill()
	local me = hrp()
	if me and inZone(me.Position) and drill then
		status("[Auto] оказался в зоне данжа без входа — назад к буру")
		tpToDrill(drill)
		return
	end
	local dp = drill and pos(drill)
	if not dp then Phase = "Бур не найден"; return end
	local fp, fuel = fuelPct()
	if AS.saveStep(dp) then return end

	-- Финальная стена (босс-бар): волна не кончится, пока стена цела. Бур, упёршийся в стену, ломает её сам,
	-- пока есть топливо, — водитель не нужен. Поэтому: доезжаем до стены, а пока её HP падает — сидим в укрытии
	-- подальше от волны. Перестала падать (бур откатился) — подъезжаем снова.
	local wall = finalWallAhead(dp)
	if wall and fuel >= CONFIG.DriveMinFuel and not State.NoDrive then
		-- у стены бур жжёт ~1%/с: сначала заправиться всем, что есть (канистры, уголь, трупы)
		if fp < 85 and os.clock() > refuelNext and (#fuelTools() > 0 or #corpses() > 0) then Phase = "Заправка перед стеной"; refuel(); return end
		local function track()
			local h = wall:GetAttribute("Health") or 0
			if not AS.wallSeen[wall] then AS.wallSeen[wall] = h
			elseif h < AS.wallSeen[wall] then AS.wallSeen[wall], AS.wallHitAt = h, os.clock() end
			return h
		end
		track()
		if os.clock() - AS.wallHitAt < 4 then
			Phase = ("Бур ломает стену сам (%s HP) — жду в укрытии"):format(tostring(wall:GetAttribute("Health")))
			hide("бур ломает стену", function()
				local h = track()
				Phase = ("Бур ломает стену сам (%d HP, топливо %d%%) — жду в укрытии"):format(math.floor(h), math.floor(fuelPct()))
				-- топливо кончается, а заправиться есть чем — выходим заправить
				if fuelPct() < 25 and (#fuelTools() > 0 or #corpses() > 0) then return false end
				return wall.Parent ~= nil and h > 0 and os.clock() - AS.wallHitAt < 4 and fuelPct() > 3
			end)
			return
		end
		heal(75)
		Phase = "Подъезжаю к финальной стене"
		drive()
		return
	end

	-- пустой бак — бур стоит, и мобы копятся: заправить сразу (пара секунд), если у самого бура чисто
	if fuelPct() < 5 and #fuelTools() > 0 and hpPct() >= 30 and #enemies(15, dp) == 0 then
		Phase = "Срочная заправка"
		refuel()
		return
	end
	-- монстры у бура: пока они рядом, они бьют и водителя (и того, кто заправляет) — сначала разбираемся с ними
	local near = enemies(45, dp)
	-- уезжаем от толпы или когда HP мало; 1–3 моба при хорошем HP быстрее убить (они всё равно догоняют)
	-- уезжаем только от орды и только если никто не сидит на самом буре (такой едет вместе с нами)
	if #near >= 4 and not State.NoDrive and #enemies(16, dp) == 0 and fuel >= CONFIG.DriveMinFuel and not drillStuck(dp) and not gateNear(dp) then
		heal(70)
		Phase = ("Уезжаю от мобов (%d)"):format(#near)
		drive()
		return
	end
	-- орда (волна после катсцены/финальной стены: 10+ гоблинов и брутов) — в бой не лезем, пережидаем в укрытии
	-- орда (волна: 10+ гоблинов и брутов) сама не уходит — выбиваем по одному: выходим при HP ≥ 90%,
	-- бьём самого отбившегося от толпы, при HP < Guard уходим в укрытие до SafeHp и повторяем
	if #near >= 4 then
		if hpPct() < CONFIG.SafeHpPct + 10 and heal(CONFIG.SafeHpPct + 10) then return end
		if hpPct() >= CONFIG.SafeHpPct + 10 then AS.hordeFight = true end
		if not AS.hordeFight then Phase = ("Орда (%d): восстанавливаюсь"):format(#near); hide("орда у бура: " .. #near, function() return hpPct() < CONFIG.SafeHpPct + 10 end); return end -- ждём тот же порог, с которого выходим в бой, иначе прыгаем туда-обратно
		Phase = ("Орда (%d): бью по одному"):format(#near)
		driveStop()
		-- самый высокий (Goblin Brute) — встаём ему на макушку и бьём сверху: мелкие гоблины туда не достают
		local tall, th
		for _, m in ipairs(near) do
			local ok, _, size = pcall(m.GetBoundingBox, m)
			if ok and size.Y > 7 and (not th or size.Y > th) then tall, th = m, size.Y end
		end
		if tall then
			killIdx = 1 -- позиция «над макушкой»
			killOne(tall)
		else
			-- остались низкие — бьём крайнего с дистанции, со стороны от толпы
			local c = Vector3.zero
			for _, m in ipairs(near) do c += pos(m) or dp end
			c /= #near
			local best, bd
			for _, m in ipairs(near) do
				local p = pos(m)
				if p and (not bd or (p - c).Magnitude > bd) then best, bd = m, (p - c).Magnitude end
			end
			hordeKill(best, c)
		end
		if hpPct() < CONFIG.GuardHpPct + 5 then AS.hordeFight = false end
		return
	end
	AS.hordeFight = false
	-- моб бьёт нас самих вдали от бура (копаем руду/уголь, собираем лут) — сначала убить, иначе копаем под ударами
	if #near == 0 and hpPct() >= CONFIG.GuardHpPct then
		local mine = enemies(20)
		if #mine > 0 then Phase = "Бой рядом со мной"; driveStop(); killOne(mine[1]); return end
	end
	if #near > 0 then
		-- сидеть за рулём под ударами нельзя: либо бой (HP хватает), либо укрытие
		if hpPct() < CONFIG.GuardHpPct then Phase = "Укрытие (мобы у бура)"; hide("мобы у бура"); return end
		heal(70)
		Phase = "Бой у бура"
		driveStop()
		-- бьём с дистанции своего оружия, со стороны, противоположной остальным мобам
		local c = Vector3.zero
		for _, m in ipairs(near) do c += pos(m) or dp end
		hordeKill(near[1], #near > 1 and c / #near or (hrp() and hrp().Position or dp))
		return
	end

	-- подземелья — в приоритете: раньше заправки, продажи, магазина и прокачки
	if not State.NoDrive and pitStep(dp, 200) then return end
	local g, key = gateNear(dp)
	if g then
		-- ждать HP на месте нельзя — бьют; лечимся аптечкой, иначе ждём в укрытии
		if hpPct() < CONFIG.SafeHpPct then
			if heal(CONFIG.SafeHpPct) then return end
			-- аптечек нет: продать лут и слетать за аптечками быстрее, чем ждать реген минутами
			if #medkits() == 0 and os.clock() > (AS.gateShopNext or 0) then
				AS.gateShopNext = os.clock() + 45
				pcall(sellStep, dp, true)
				if shopStep(dp, true) or AS.bandageRun(dp, true) then return end
			end
			Phase = "Жду HP перед подземельем (в укрытии)"
			hide("жду HP перед подземельем", function() return hpPct() < CONFIG.SafeHpPct end)
			return
		end
		Phase = "Вход в подземелье"; enterGate(g, key); return
	end
	if os.clock() > refuelNext and ((fp < CONFIG.FuelTargetPct and (#fuelTools() > 0 or #corpses() > 0)) or (fp < 90 and #corpses() >= 3)) then Phase = "Заправка"; refuel(); return end
	if sellStep(dp) then return end
	-- ивент Money Fog (Lighting.Event = "MoneyFog"): продажа выгоднее — сбываем всё сразу, на ближайшем столе
	if game:GetService("Lighting"):GetAttribute("Event") == "MoneyFog" and os.clock() > AS.fogSellNext then
		if (bagUsage() or 0) > 0 then
			AS.fogSellNext = os.clock() + 20
			status("[Sell] Money Fog — продаю всё")
			if sellStep(dp, true) then return end
		end
	end
	-- сумка почти полна, а стола рядом нет — летим к ближайшему столу продажи, где бы он ни был
	local bn, bc = bagUsage()
	-- без вождения бур ведёт другой — продаём уже с обычного порога
	local farPct = State.NoDrive and CONFIG.SellAtPct or CONFIG.SellFarPct
	if bn and bc and bc > 0 and bn / bc * 100 >= farPct and os.clock() > AS.farSellNext then
		AS.farSellNext = os.clock() + 60
		if sellStep(dp, true) then return end
	end
	if shopStep(dp) then return end
	if AS.bandageRun(dp) then return end
	-- раз в 5 минут, если монет много: дальний магазин за снаряжением/аптечками получше
	if os.clock() > AS.farShopNext and (coinsCache2() or 0) >= 500 then
		AS.farShopNext = os.clock() + 300
		if farShop(dp) then return end
	end
	if armorStep() then Phase = "Надеваю броню"; return end
	if upgradeStep() then Phase = "Прокачка бура"; return end


	if chestStep(dp, CONFIG.WorkRadius) then Phase = "Сундуки"; return end
	if lootStep(dp, CONFIG.WorkRadius) then Phase = "Сбор лута"; return end
	if fp < CONFIG.FuelTargetPct and #fuelTools() == 0 then
		if lootStep(dp, CONFIG.FuelSearchRadius, true) then Phase = "Ищу топливо"; return end
		-- уголь, только что выкопанный вдали от бура, лежит у нас под ногами
		local me0 = hrp()
		if me0 and lootStep(me0.Position, 80, true) then Phase = "Подбираю уголь"; return end
		-- канистр нет — копаем уголь (Ore_Coal = топливо 25) киркой обычным фармом руды
		local r = hrp()
		local hasCoal = false
		for _, n in ipairs(oreNodes()) do
			if hasKey(n:GetAttribute("SessionOreType") or "", { "Coal" }) and r and (n.Position - dp).Magnitude <= CONFIG.WorkRadius then hasCoal = true; break end
		end
		if hasCoal then
			Phase = "Копаю уголь на топливо"
			driveStop()
			local names, radius = CONFIG.OreNames, CONFIG.OreSearchRadius
			CONFIG.OreNames, CONFIG.OreSearchRadius, Mining = { "Coal" }, CONFIG.WorkRadius, true
			pcall(farmStep)
			CONFIG.OreNames, CONFIG.OreSearchRadius, Mining = names, radius, false
			return
		end
	end
	if fuel < CONFIG.DriveMinFuel then driveStop(); Phase = "Нет топлива — жду канистры"; return end

	local w = finalWallAhead(dp)
	if w and not wallReady[w] then
		if hpPct() < CONFIG.SafeHpPct then
			if heal(CONFIG.SafeHpPct) then return end
			Phase = "Перед финальной стеной: жду HP (в укрытии)"
			hide("жду HP перед финальной стеной", function() return hpPct() < CONFIG.SafeHpPct end)
			return
		end
		wallReady[w] = true
		status("[Auto] финальная стена — ломаем (будет волна врагов)")
	end
	-- руда у бура: остановиться и выкопать, а не проезжать мимо
	if not State.NoDrive and CONFIG.AutoOreRadius > 0 and hpPct() >= CONFIG.SafeHpPct and not bagFull() then
		local node
		for _, n in ipairs(oreNodes()) do
			if flat(n.Position, dp) <= CONFIG.AutoOreRadius then node = n; break end
		end
		if node then
			Phase = "Копаю руду у бура"
			driveStop()
			-- жила не поддаётся (не долететь/не добить) — после 3 попыток пропускаем, иначе бур стоит вечно
			AS.oreTries = AS.oreTries or setmetatable({}, { __mode = "k" })
			AS.oreTries[node] = (AS.oreTries[node] or 0) + 1
			if AS.oreTries[node] > 3 then node:SetAttribute("_DF_Skip", true); status("[Farm] жила не поддаётся — пропускаю") ; return end
			Mining = true
			pcall(farmStep, node)
			Mining = false
			return
		end
	end
	if State.NoDrive then
		-- без вождения: бур ведёт кто-то другой — держимся на буре, чтобы не отстать
		if noDriveIdle(dp) then return end
		Phase = "Без вождения: жду дел у бура"
		local r = hrp()
		if r and (r.Position - dp).Magnitude > 40 then
			r.AssemblyLinearVelocity = Vector3.zero
			r.CFrame = CFrame.new(dp + Vector3.new(0, 10, 0))
		end
		return
	end
	Phase = w and "Ломаю финальную стену" or "Еду"
	drive()
end


----------------------------------------------------------------- SCANNER
-- Скан: печать в F9 + копирование в буфер обмена
local function scan(nearOnly)
	local out, seen = {}, {}
	local function log(...)
		local t = {}
		for _, v in ipairs({ ... }) do table.insert(t, tostring(v)) end
		local line = table.concat(t, " ")
		print(line); table.insert(out, line)
	end
	for _, d in ipairs(nearOnly and {} or workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local key = d.Parent.Name .. " | " .. d.ActionText
			if not seen[key] then seen[key] = true; log("[Prompt]", d.Parent:GetFullName(), "|", d.ActionText) end
		elseif d:IsA("Model") and next(d:GetAttributes()) then
			if not seen[d.Name] then
				seen[d.Name] = true
				local a = {}
				for k, v in pairs(d:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
				log("[Attr]", d:GetFullName(), table.concat(a, ", "))
			end
		end
	end
	local r = hrp()
	if r then
		local near = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if (d:IsA("BasePart") or d:IsA("Model")) and not d:IsDescendantOf(player.Character)
				and d.Parent and not near[d.Name] then
				local p = pos(d)
				if p and (p - r.Position).Magnitude < 25 then
					near[d.Name] = true
					local a = {}
					for k, v in pairs(d:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
					log("[Near]", d.ClassName, d:GetFullName(), table.concat(a, ", "))
					for _, pr in ipairs(d:GetChildren()) do
						if pr:IsA("ProximityPrompt") or pr:IsA("Attachment") then
							for _, q in ipairs(pr:IsA("Attachment") and pr:GetChildren() or { pr }) do
								if q:IsA("ProximityPrompt") then
									log("   [Prompt]", q.ActionText, "| Enabled=" .. tostring(q.Enabled),
										"| Hold=" .. tostring(q.HoldDuration), "| Dist=" .. tostring(q.MaxActivationDistance))
								end
							end
						end
					end
				end
			end
		end
	end
	if nearOnly then
		print("[Scan] Готово, строк: " .. #out)
		return table.concat(out, "\n")
	end
	for k, v in pairs(player:GetAttributes()) do log("[PlayerAttr]", k, v) end
	for _, d in ipairs(RS:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then log("[Remote]", d:GetFullName()) end
	end
	print("[Scan] Готово, строк: " .. #out)
	return table.concat(out, "\n")
end
local function copyText(text)
	local clip = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
	return clip and pcall(clip, text) or false
end


----------------------------------------------------------------- DUNGEON FARM
-- Фарм данжей в открытой территории: бур стоит, персонаж по кругу проходит данжи от старта до бура.
-- Ворота грузятся только рядом с игроком (streaming), поэтому позиции запоминаем: при проходе бура и разовым
-- облётом пути (путь — прямая вдоль X на z ≈ -772). Данж одноразовый: пройден, когда волна завершена и сундуки открыты.
local dungeonFarmStep
;(function() -- своя функция: у Luau лимит 200 локальных на функцию
local knownGates = getgenv and (getgenv().DF_KnownGates or {}) or {}
if getgenv then getgenv().DF_KnownGates = knownGates end
local farmedAt, farmFails, farmTries = {}, {}, {}
local function registerGates()
	for _, g in ipairs(workspace:GetChildren()) do
		if g:IsA("Model") and g.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName then
			local k, p = gateKey(g), pos(g)
			if k and p and not knownGates[k] then knownGates[k] = { pos = p, name = g.Name } end
		end
	end
end
task.spawn(function() while Running do pcall(registerGates); task.wait(3) end end)

local swept = false
local function sweepPath()
	local d = getDrill()
	local dp = d and pos(d)
	if not dp then return end
	status("[Данжи] облёт открытой территории: ищу ворота")
	Moving = true
	for x = 0, dp.X, 250 do
		if not (Running and State.DungeonFarm) then break end
		local p = Vector3.new(x, dp.Y, dp.Z)
		local r = hrp()
		if r then r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = CFrame.new(p - Vector3.new(0, 30, 0)) end -- под полом
		pcall(function() player:RequestStreamAroundAsync(p, 3) end)
		task.wait(0.4)
		pcall(registerGates)
	end
	Moving = false
	local n = 0
	for _ in pairs(knownGates) do n += 1 end
	status(("[Данжи] известно ворот: %d"):format(n))
	swept = true
end

-- проход данжа с учётом: вышли — данж пройден, если волна завершена и сундуков не осталось
-- (иначе, напр. после выхода по низкому HP, — вернёмся)
trackedDungeonRun = function()
	dungeonRun()
	if not inDungeon() and curGate then
		local k = gateKey(curGate)
		local wave = curGate:FindFirstChild("Wave")
		if k then
			if (not wave or wave:GetAttribute("WaveCompleted") == true) and #idleChests(curGate) == 0 then
				farmedAt[k] = math.huge
				status("[Данжи] пройден: " .. curGate.Name)
			else
				-- не до конца (вышли по HP / сундук не открылся): ещё одна попытка, потом — пройден
				farmTries[k] = (farmTries[k] or 0) + 1
				if farmTries[k] >= 2 then
					farmedAt[k] = math.huge
					status("[Данжи] " .. curGate.Name .. ": 2 захода без полного прохода — пропускаю")
				else
					farmedAt[k] = os.clock() + 30
					gateDone[k] = nil
				end
			end
		end
		curGate = nil
	end
end

-- ближайший непройденный данж из известных, подходящий под фильтр
local function pickGate(from, ok)
	local best, bk, bd
	for k, g in pairs(knownGates) do
		if ok(g) and (farmedAt[k] or 0) ~= math.huge and os.clock() >= (farmedAt[k] or 0) and (farmFails[k] or 0) < 3 then
			local dd = (g.pos - from).Magnitude
			if not bd or dd < bd then best, bk, bd = g, k, dd end
		end
	end
	return best, bk
end

-- долететь до ворот, дождаться прогрузки и войти
local function farmGate(best, bk, r)
	Phase = "Лечу к данжу: " .. best.name
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.new(best.pos + Vector3.new(0, 6, 0))
	pcall(function() player:RequestStreamAroundAsync(best.pos, 5) end)
	local g
	for _ = 1, 20 do
		for _, m in ipairs(workspace:GetChildren()) do
			if m:IsA("Model") and m.Name:sub(1, #CONFIG.GateName) == CONFIG.GateName and gateKey(m) == bk then g = m end
		end
		if g then break end
		task.wait(0.25)
	end
	if not g then farmFails[bk] = (farmFails[bk] or 0) + 1; farmedAt[bk] = os.clock() + 30; return end
	local wv = g:FindFirstChild("Wave")
	if wv and wv:GetAttribute("WaveCompleted") == true and #idleChests(g) == 0 then
		farmedAt[bk] = math.huge
		status("[Данжи] уже пройден: " .. g.Name)
		return
	end
	if chestStep(best.pos, 150) then return end -- сундуки у входа
	gateDone[bk], gateTries[bk] = nil, 0
	enterGate(g, bk)
	if not inDungeon() then
		farmFails[bk] = (farmFails[bk] or 0) + 1
		farmedAt[bk] = os.clock() + 20
		status(("[Данжи] %s: вход не сработал (попытка %d)"):format(best.name, farmFails[bk]))
	end
end

-- Без вождения, когда дел у бура нет: данжи рядом с буром, потом руда у бура
noDriveIdle = function(dp)
	local r = hrp()
	if not r then return false end
	if pitStep(dp, 400) then return true end
	if hpPct() >= CONFIG.SafeHpPct then
		local best, bk = pickGate(r.Position, function(g) return flat(g.pos, dp) <= 400 and g.pos.X <= dp.X + 150 end)
		if best then farmGate(best, bk, r); return true end
	end
	local node = nearest(oreNodes(), CONFIG.WorkRadius)
	if not (node and flat(node.Position, dp) <= CONFIG.WorkRadius) then return false end
	Phase = "Без вождения: копаю руду"
	local names, radius = CONFIG.OreNames, CONFIG.OreSearchRadius
	CONFIG.OreNames, CONFIG.OreSearchRadius, Mining = {}, CONFIG.WorkRadius, true
	pcall(farmStep)
	CONFIG.OreNames, CONFIG.OreSearchRadius, Mining = names, radius, false
	return true
end

dungeonFarmStep = function()
	if State.Auto then State.DungeonFarm = false; return end
	if not alive() then Phase = "Ждём возрождения"; return end
	if workspace:GetAttribute("InCutScene") == true then Phase = "Катсцена"; return end
	if heal(60) then return end
	if hpPct() < CONFIG.GuardHpPct then
		if inDungeon() then exitDungeon("мало HP") end
		Phase = "Укрытие (мало HP)"; hide("мало HP"); return
	end
	if inDungeon() then return trackedDungeonRun() end
	if deathChestStep() then return end
	driveStop()
	if armorStep() then Phase = "Надеваю броню"; return end
	local r = hrp()
	if not r then return end
	-- сумка почти полна — продать на ближайшем столе
	local n, cap = bagUsage()
	if n and cap and cap > 0 and n / cap * 100 >= CONFIG.SellAtPct and sellStep(r.Position, true) then return end
	if not swept then sweepPath(); return end

	local d = getDrill()
	if d and pos(d) and pitStep(pos(d), 600) then return end -- паучьи ямы рядом с буром
	local maxX = (d and pos(d) or r.Position).X + 150 -- только открытая территория (до бура)
	local best, bk = pickGate(r.Position, function(g) return g.pos.X <= maxX end)
	if not best then
		local left = 0
		for k, g in pairs(knownGates) do
			if g.pos.X <= maxX and farmedAt[k] ~= math.huge and (farmFails[k] or 0) < 3 then left += 1 end
		end
		if left == 0 then
			status("[Данжи] все данжи в открытой территории пройдены — фарм данжей выключен")
			State.DungeonFarm = false
		end
		Phase = "Данжи: жду"
		task.wait(1)
		return
	end
	farmGate(best, bk, r)
end
end)() -- (фарм данжей)

----------------------------------------------------------------- LOOPS
local loops = {
	Auto = autoStep,
	DungeonFarm = dungeonFarmStep,
	Farm = farmStep,
	KillAura = function()
		if hpPct() < CONFIG.GuardHpPct then hide("Kill Aura") else killStep(CONFIG.KillRadius, true) end
	end,
	SkipCutscenes = skipCutscene,
}
for name, fn in pairs(loops) do
	task.spawn(function()
		while Running do
			if State[name] and not Selling then
				local ok, err = pcall(fn)
				if not ok then status("[Ошибка] " .. name .. ": " .. tostring(err)); task.wait(1) end
			end
			task.wait(CONFIG.Tick)
		end
	end)
end
task.spawn(function()
	while Running do pcall(highlightStep); task.wait(1) end
end)
-- авто-фарм выключили — отпустить газ и выйти из водительского места
task.spawn(function()
	while Running do
		if driveStarted and not State.Auto then pcall(driveStop, "выключено") end
		if not busy() and Phase ~= "Выключено" then Phase = "Выключено" end
		task.wait(0.5)
	end
end)


-- Noclip: всегда, если включён тумблер, и автоматически во время перелётов скрипта
local noclipWas = {}
table.insert(Connections, game:GetService("RunService").Stepped:Connect(function()
	local c = player.Character
	if not c then return end
	local on = State.Noclip or Moving
	for _, part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then
			if on then
				if part.CanCollide then noclipWas[part] = true; part.CanCollide = false end
			elseif noclipWas[part] then
				noclipWas[part] = nil; part.CanCollide = true
			end
		end
	end
end))


----------------------------------------------------------------- UI
-- UI в отдельной функции: у главного блока Luau лимит 200 локальных переменных
;(function()
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local T = {
	Bg     = Color3.fromRGB(16, 16, 20),
	Card   = Color3.fromRGB(26, 26, 32),
	Hover  = Color3.fromRGB(34, 34, 42),
	Stroke = Color3.fromRGB(44, 44, 54),
	Text   = Color3.fromRGB(235, 235, 240),
	Sub    = Color3.fromRGB(130, 130, 145),
	Accent = Color3.fromRGB(92, 140, 255),
	Off    = Color3.fromRGB(58, 58, 68),
	Good   = Color3.fromRGB(46, 170, 105),
	Bad    = Color3.fromRGB(215, 70, 70),
	Warn   = Color3.fromRGB(240, 180, 60),
}
local FONT, FONT_B = Enum.Font.Gotham, Enum.Font.GothamBold
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(o, props) TweenService:Create(o, TI, props):Play() end
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function bind(sig, fn) local c = sig:Connect(fn); table.insert(Connections, c); return c end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o) new("UIStroke", { Color = T.Stroke, Thickness = 1 }, o) end

local pg = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G
if env.DrillFarmClose then pcall(env.DrillFarmClose) end
local old = pg:FindFirstChild("DrillFarm")
if old then old:Destroy() end

local gui = new("ScreenGui", { Name = "DrillFarm", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)

-- справа по центру: слева у игры свои панели (монеты, HP, голод), меню их перекрывало
local main = new("Frame", {
	Size = UDim2.new(0, 290, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 48), BackgroundColor3 = T.Bg, BorderSizePixel = 0,
}, gui)
corner(main, 12); stroke(main)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, main)
-- на телефоне/эмуляторе экран в логических пикселях маленький (~360 по высоте) — ужимаем меню
local uiScale = new("UIScale", {}, main)
local function rescale() uiScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 560, 0.62, 1) end
rescale()
local function sc() return uiScale.Scale end

-- Шапка
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 0 }, main)
local dot = new("Frame", { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, 0, 13),
	BackgroundColor3 = T.Off, BorderSizePixel = 0 }, header)
corner(dot, 4)
new("TextLabel", {
	Text = "DrillFarm", Font = FONT_B, TextSize = 16, TextColor3 = T.Text,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 28, 0, 7), Size = UDim2.new(1, -100, 0, 18),
}, header)
local subLabel = new("TextLabel", {
	Text = "Drill to Earth's Core", Font = FONT, TextSize = 11, TextColor3 = T.Sub,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -90, 0, 14),
}, header)
local accent = new("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 1, -2),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, header)
new("UIGradient", { Color = ColorSequence.new(T.Accent, Color3.fromRGB(170, 110, 255)),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7) }) }, accent)
local minBtn = new("TextButton", {
	Text = "–", Font = FONT_B, TextSize = 18, TextColor3 = T.Sub, AutoButtonColor = false,
	BackgroundColor3 = T.Card, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -72, 0, 8),
}, header)
corner(minBtn, 8)
local closeBtn = new("TextButton", {
	Text = "×", Font = FONT_B, TextSize = 18, TextColor3 = T.Sub, AutoButtonColor = false,
	BackgroundColor3 = T.Card, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -40, 0, 8),
}, header)
corner(closeBtn, 8)

-- Вкладки
local tabHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 }, main)
local tabBar = new("Frame", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 8),
	BackgroundColor3 = T.Card, BorderSizePixel = 0 }, tabHolder)
corner(tabBar, 8)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

-- Прокручиваемая область: своя реализация (колесо, ЛКМ, палец), у каждой вкладки своя страница
local view = new("Frame", {
	Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, BorderSizePixel = 0,
	ClipsDescendants = true, LayoutOrder = 2,
}, main)
local thumb = new("Frame", { Size = UDim2.new(0, 3, 0, 40), Position = UDim2.new(1, -5, 0, 0), ZIndex = 5,
	BackgroundColor3 = T.Accent, BackgroundTransparency = 0.3, BorderSizePixel = 0 }, view)
corner(thumb, 2)

local pages, tabs, cur = {}, {}, nil
local scrollY, scrollMoved, sliderActive = 0, false, false
local function contentH() return cur and cur.list.AbsoluteContentSize.Y + 12 or 0 end
local function setScroll(y)
	if not cur then return end
	local viewH = view.AbsoluteSize.Y
	local maxY = math.max(0, contentH() - viewH)
	scrollY = math.clamp(y, 0, maxY)
	-- scrollY и Absolute* — в экранных пикселях, а смещения UDim2 — до UIScale: делим на масштаб
	cur.frame.Position = UDim2.new(0, 0, 0, -scrollY / sc())
	thumb.Visible = maxY > 0
	if maxY > 0 then
		local th = math.max(24, viewH * viewH / contentH())
		thumb.Size = UDim2.new(0, 3, 0, th / sc())
		thumb.Position = UDim2.new(1, -5, 0, (viewH - th) * scrollY / maxY / sc())
	end
end
-- Высота = контент, но низ меню выше хотбара
local function fitHeight()
	-- от верха меню до хотбара (~60 px снизу), минус шапка и вкладки
	local room = gui.AbsoluteSize.Y - (main.AbsolutePosition.Y - gui.AbsolutePosition.Y) - 60 - 90 * sc()
	view.Size = UDim2.new(1, 0, 0, math.max(60 * sc(), math.min(contentH(), room)) / sc())
	setScroll(scrollY)
end
local function over(p)
	local a, z = view.AbsolutePosition, view.AbsoluteSize
	return main.Visible and view.Visible and p.X >= a.X and p.X <= a.X + z.X and p.Y >= a.Y and p.Y <= a.Y + z.Y
end
do
	local dragging, startY, startScroll
	local function isPress(t) return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch end
	bind(UIS.InputBegan, function(i)
		if isPress(i.UserInputType) and not sliderActive and over(i.Position) then
			dragging, startY, startScroll, scrollMoved = true, i.Position.Y, scrollY, false
		end
	end)
	bind(UIS.InputChanged, function(i)
		local t = i.UserInputType
		if dragging and not sliderActive and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			local d = i.Position.Y - startY
			if math.abs(d) > 6 then scrollMoved = true end
			if scrollMoved then setScroll(startScroll - d) end
		end
	end)
	bind(UIS.InputEnded, function(i)
		if isPress(i.UserInputType) then
			dragging = false
			task.delay(0.05, function() scrollMoved = false end)
		end
	end)
end
-- Колесо над меню: скроллим меню и "съедаем" ввод, чтобы камера не зумилась
do
	local CAS = game:GetService("ContextActionService")
	pcall(function() CAS:UnbindAction("DF_MenuWheel") end)
	CAS:BindActionAtPriority("DF_MenuWheel", function(_, state, input)
		if state == Enum.UserInputState.Change and (over(input.Position) or over(UIS:GetMouseLocation())) then
			setScroll(scrollY - input.Position.Z * 40)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 3000, Enum.UserInputType.MouseWheel)
end
bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function() rescale(); fitHeight() end)

local function showPage(name)
	for n, p in pairs(pages) do p.frame.Visible = n == name end
	for n, b in pairs(tabs) do
		local on = n == name
		tween(b, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and T.Text or T.Sub })
	end
	cur = pages[name]
	scrollY = 0
	fitHeight()
end
local page -- страница, в которую добавляют section/toggle/...
local function addPage(name, title)
	local frame = new("Frame", {
		Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}, view)
	local list = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 12) }, frame)
	pages[name] = { frame = frame, list = list }
	bind(list:GetPropertyChangedSignal("AbsoluteContentSize"), function() if cur == pages[name] then fitHeight() end end)
	local b = new("TextButton", {
		Text = title, Font = FONT_B, TextSize = 12, TextColor3 = T.Sub, AutoButtonColor = false,
		BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Size = UDim2.new(1 / 3, 0, 1, 0),
		LayoutOrder = #tabBar:GetChildren(),
	}, tabBar)
	corner(b, 8)
	b.MouseButton1Click:Connect(function() showPage(name) end)
	tabs[name] = b
	page = frame
end

local order = 0
local function nextOrder() order += 1; return order end

local function section(title)
	new("TextLabel", {
		Text = string.upper(title), Font = FONT_B, TextSize = 10, TextColor3 = T.Sub,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(),
	}, page)
end

local function row(height)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.Card,
		BorderSizePixel = 0, LayoutOrder = nextOrder() }, page)
	corner(r, 8)
	return r
end

local function toggle(key, title, hint)
	local r = row(hint and 44 or 34)
	new("TextLabel", {
		Text = title, Font = FONT, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, hint and 5 or 0),
		Size = UDim2.new(1, -64, 0, hint and 18 or 34),
	}, r)
	if hint then
		new("TextLabel", {
			Text = hint, Font = FONT, TextSize = 10, TextColor3 = T.Sub, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 23),
			Size = UDim2.new(1, -64, 0, 14),
		}, r)
	end
	local track = new("Frame", { Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -46, 0.5, -9),
		BackgroundColor3 = T.Off, BorderSizePixel = 0 }, r)
	corner(track, 9)
	local knob = new("Frame", { Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = T.Text, BorderSizePixel = 0 }, track)
	corner(knob, 7)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, r)
	hit.MouseEnter:Connect(function() tween(r, { BackgroundColor3 = T.Hover }) end)
	hit.MouseLeave:Connect(function() tween(r, { BackgroundColor3 = T.Card }) end)
	local shown
	local function render()
		local on = State[key]
		shown = on
		tween(track, { BackgroundColor3 = on and T.Accent or T.Off })
		tween(knob, { Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) })
	end
	hit.MouseButton1Click:Connect(function()
		if scrollMoved then return end
		State[key] = not State[key]
		render()
	end)
	render()
	-- если скрипт сам выключил функцию — обновить переключатель
	task.spawn(function()
		while Running do
			if State[key] ~= shown then render() end
			task.wait(0.3)
		end
	end)
end

local function slider(title, cfgKey, min, max, step, suffix)
	suffix = suffix or ""
	local r = row(46)
	new("TextLabel", {
		Text = title, Font = FONT, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -80, 0, 16),
	}, r)
	local val = new("TextLabel", {
		Text = tostring(CONFIG[cfgKey]) .. suffix, Font = FONT_B, TextSize = 12, TextColor3 = T.Accent,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -72, 0, 6), Size = UDim2.new(0, 60, 0, 16),
	}, r)
	local bar = new("Frame", { Size = UDim2.new(1, -24, 0, 4), Position = UDim2.new(0, 12, 0, 32),
		BackgroundColor3 = T.Off, BorderSizePixel = 0 }, r)
	corner(bar, 2)
	local fill = new("Frame", { Size = UDim2.new((CONFIG[cfgKey] - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0 }, bar)
	corner(fill, 2)

	local dragging = false
	local function set(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local v = math.floor((min + (max - min) * a) / step + 0.5) * step
		CONFIG[cfgKey] = v
		val.Text = tostring(v) .. suffix
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
	end
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 24) }, r)
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; sliderActive = true; set(i.Position.X)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			set(i.Position.X)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false; sliderActive = false
		end
	end)
end

local function action(title, fn, color)
	local b = new("TextButton", {
		Text = title, Font = FONT_B, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false,
		BackgroundColor3 = color or T.Card, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(),
	}, page)
	corner(b, 8)
	if not color then stroke(b) end
	b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.15 }) end)
	b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0 }) end)
	b.MouseButton1Click:Connect(function()
		if scrollMoved then return end
		local t0 = b.Text
		task.spawn(function()
			local ok, res = pcall(fn, b)
			b.Text = ok and (res or "Готово ✓") or "Ошибка"
			task.delay(1.5, function() if b.Parent then b.Text = t0 end end)
		end)
	end)
	return b
end

-- Плитка статуса: заголовок сверху, значение крупно
local function tile(parent, title, x, y, w)
	local f = new("Frame", { Size = UDim2.new(w or 0.5, -4, 0, 38), Position = UDim2.new(x, x > 0 and 4 or 0, 0, y),
		BackgroundColor3 = T.Bg, BorderSizePixel = 0 }, parent)
	corner(f, 6)
	new("TextLabel", { Text = title, Font = FONT, TextSize = 10, TextColor3 = T.Sub, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(1, -16, 0, 12) }, f)
	return new("TextLabel", { Text = "—", Font = FONT_B, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 8, 0, 16), Size = UDim2.new(1, -16, 0, 18) }, f)
end

-- окно подтверждения поверх страниц (перезагрузка через DrillFarmClose закрывает без вопросов)
local confirm = new("TextButton", { Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20,
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.08, BorderSizePixel = 0 }, view)
local askTitle, askText, askOk, askFn
do
	local box = new("Frame", { Size = UDim2.new(1, -24, 0, 146), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = T.Card, BorderSizePixel = 0 }, confirm)
	corner(box, 10); stroke(box)
	askTitle = new("TextLabel", { Text = "", Font = FONT_B, TextSize = 15, TextColor3 = T.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 12), Size = UDim2.new(1, -28, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left }, box)
	askText = new("TextLabel", { Text = "", Font = FONT, TextSize = 11, TextColor3 = T.Sub, BackgroundTransparency = 1,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 0, 48) }, box)
	local function btn(text, color, x)
		local b = new("TextButton", { Text = text, Font = FONT_B, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false,
			BackgroundColor3 = color, Size = UDim2.new(0.5, -18, 0, 32), Position = UDim2.new(x, x > 0 and 4 or 14, 1, -44) }, box)
		corner(b, 8)
		return b
	end
	btn("Отмена", T.Off, 0).MouseButton1Click:Connect(function() confirm.Visible = false end)
	askOk = btn("", T.Bad, 0.5)
	askOk.MouseButton1Click:Connect(function() confirm.Visible = false; task.spawn(askFn) end)
end
local function ask(title, text, okText, fn)
	main.Visible, view.Visible, tabHolder.Visible = true, true, true -- в свёрнутом меню окну негде показаться
	askTitle.Text, askText.Text, askOk.Text, askFn = title, text, okText, fn
	confirm.Visible = true
	if view.AbsoluteSize.Y < 160 * sc() then view.Size = UDim2.new(1, 0, 0, 160) end
end

----------------------------------------------------------------- Вкладка «Главная»
addPage("main", "Главная")
local autoBtn = new("TextButton", {
	Text = "", Font = FONT_B, TextSize = 15, TextColor3 = T.Text, AutoButtonColor = false,
	BackgroundColor3 = T.Good, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = nextOrder(),
}, page)
corner(autoBtn, 10)
local function renderAuto()
	autoBtn.Text = State.Auto and "■  ОСТАНОВИТЬ АВТО-ФАРМ" or "▶  ЗАПУСТИТЬ АВТО-ФАРМ"
	tween(autoBtn, { BackgroundColor3 = State.Auto and T.Bad or T.Good })
end
autoBtn.MouseButton1Click:Connect(function()
	if scrollMoved then return end
	State.Auto = not State.Auto
	if State.Auto then
		State.Farm, State.KillAura, State.DungeonFarm = false, false, false -- они дерутся за персонажа с авто-фармом
		Stats.start = Stats.start or os.clock()
	end
	renderAuto()
end)
renderAuto()

local saveBtn = new("TextButton", {
	Text = "БЫСТРЫЙ СЕЙВ И ВЫХОД В ЛОББИ", Font = FONT_B, TextSize = 12, TextColor3 = T.Warn, AutoButtonColor = false,
	BackgroundColor3 = T.Card, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(),
}, page)
corner(saveBtn, 8)
new("UIStroke", { Color = T.Warn, Thickness = 1, Transparency = 0.5 }, saveBtn)
saveBtn.MouseButton1Click:Connect(function()
	if scrollMoved then return end
	ask("Быстрый сейв?", "Всё остановится, лучшие вещи (до 9) сохранятся, заход закончится — выход в лобби.",
		"Сохранить", function()
			local prev = table.clone(State)
			for k in pairs(State) do if k ~= "SkipCutscenes" then State[k] = false end end
			saveBtn.Text = "Сохраняю…"
			local d = getDrill()
			local p = (d and pos(d)) or (hrp() and hrp().Position)
			local ok = p and AS.saveNow(p, true)
			saveBtn.Text = ok and "Сохранено — выход в лобби" or "Не вышло — см. лог"
			if not ok then for k, v in pairs(prev) do State[k] = v end end -- не сохранилось — фарм продолжается
			task.delay(4, function() if saveBtn.Parent then saveBtn.Text = "БЫСТРЫЙ СЕЙВ И ВЫХОД В ЛОББИ" end end)
		end)
end)

-- полоска: подпись слева, значение справа, заполнение снизу
local function meter(parent, title, y)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, y),
		BackgroundColor3 = T.Bg, BorderSizePixel = 0 }, parent)
	corner(f, 6)
	new("TextLabel", { Text = title, Font = FONT, TextSize = 11, TextColor3 = T.Sub, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(0.5, -8, 0, 16) }, f)
	local v = new("TextLabel", { Text = "—", Font = FONT_B, TextSize = 12, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.4, 0, 0, 3), Size = UDim2.new(0.6, -8, 0, 16) }, f)
	local bar = new("Frame", { Size = UDim2.new(1, -16, 0, 5), Position = UDim2.new(0, 8, 0, 22),
		BackgroundColor3 = T.Off, BorderSizePixel = 0 }, f)
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Good, BorderSizePixel = 0 }, bar)
	corner(fill, 3)
	return function(text, frac, color)
		v.Text = text
		tween(fill, { Size = UDim2.new(math.clamp(frac or 0, 0, 1), 0, 1, 0), BackgroundColor3 = color or T.Good })
	end
end

local card = row(212)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8) }, card)
local vPhase = tile(card, "Сейчас", 0, 0, 1)
local mHp    = meter(card, "Здоровье", 44)
local mFuel  = meter(card, "Топливо бура", 82)
local mBag   = meter(card, "Сумка", 120)
local vCoins = tile(card, "Монеты", 0, 158, 1 / 3)
local vDmg   = tile(card, "Урон бура", 1 / 3, 158, 1 / 3)
local vTime  = tile(card, "Время", 2 / 3, 158, 1 / 3)

local counters = new("TextLabel", {
	Text = "", Font = FONT, TextSize = 11, TextColor3 = T.Sub, BackgroundTransparency = 1, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nextOrder(),
}, page)
StatusLabel = new("TextLabel", {
	Text = "Лог: —", Font = FONT, TextSize = 11, TextColor3 = T.Accent, TextWrapped = true,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nextOrder(),
}, page)

----------------------------------------------------------------- Вкладка «Настройки»
addPage("settings", "Настройки")
section("Безопасность")
slider("Прятаться при HP ниже", "GuardHpPct", 20, 80, 5, "%")
slider("Выходить из укрытия при HP", "SafeHpPct", 50, 100, 5, "%")
section("Авто-фарм")
slider("Радиус работы от бура", "WorkRadius", 100, 600, 25)
slider("Заправлять при топливе ниже", "FuelTargetPct", 10, 90, 5, "%")
slider("Продавать при заполнении сумки", "SellAtPct", 30, 100, 10, "%")
slider("Радиус в подземелье", "DungeonRadius", 100, 800, 50)
section("Дополнительно")
slider("Радиус Kill Aura", "KillRadius", 10, 300, 10)
slider("Радиус поиска руды", "OreSearchRadius", 0, 500, 10)
slider("Копать руду у бура (0 = нет)", "AutoOreRadius", 0, 200, 10)

----------------------------------------------------------------- Вкладка «Ещё»
addPage("extra", "Ещё")
section("Функции")
toggle("NoDrive", "Авто-фарм без вождения", "делает всё (бой, лут, сундуки, данжи, заправка, продажа), но бур не водит")
toggle("DungeonFarm", "Фарм данжей", "по кругу проходит данжи и сундуки в уже открытой территории (бур стоит)")
toggle("SkipCutscenes", "Авто-скип катсцен", "работает всегда, даже без авто-фарма")
toggle("KillAura", "Kill Aura", "бьёт монстров рядом, прячется при низком HP")
toggle("Farm", "Фарм руды", "отдельно от авто-фарма")
toggle("Noclip", "Noclip")
toggle("Highlight", "Подсветка монстров")
section("Действия")
action("Телепорт к буру", function()
	local drill = getDrill()
	if not drill then return "Бур не найден" end
	tpToDrill(drill)
end)
action("Заправить сейчас", function()
	if #fuelTools() == 0 then return "Нет канистр" end
	return refuel() and "Заправлено ✓" or "Не вышло"
end)
action("Продать сейчас", function()
	local r = hrp()
	if not r then return "Нет персонажа" end
	return sellStep(r.Position, true) and "Продано ✓" or "Стол не найден"
end)
action("Прокачать бур сейчас", function()
	return upgradeStep(true) and "Куплено ✓" or "Нет монет/карточек"
end)
section("Отладка")
local lastScan
local function dumpValue(v, indent, out, depth)
	if type(v) ~= "table" or depth > 4 then table.insert(out, indent .. tostring(v)); return end
	for k, x in pairs(v) do
		if type(x) == "table" then
			table.insert(out, indent .. tostring(k) .. ":")
			dumpValue(x, indent .. "  ", out, depth + 1)
		else
			table.insert(out, indent .. tostring(k) .. " = " .. tostring(x))
		end
	end
end
action("Scan → F9", function() lastScan = scan(false); return "Готово · F9" end)
action("Scan рядом (25 st)", function() lastScan = scan(true); return "Готово · F9" end)
action("Инвентарь → F9", function()
	local out = { "[Inventory]" }
	dumpValue(inventory(true) or "нет данных", "  ", out, 0)
	lastScan = table.concat(out, "\n")
	print(lastScan)
end)
action("Копировать скан", function()
	if not lastScan then return "Сначала Scan" end
	return copyText(lastScan) and "Скопировано ✓" or "Нет буфера · F9"
end)
new("TextLabel", {
	Text = "RightShift — скрыть  ·  × — закрыть скрипт", Font = FONT, TextSize = 11, TextColor3 = T.Sub,
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder(),
}, page)

showPage("main")

-- Живой статус на главной
local coinsCache, coinsAt = nil, 0
task.spawn(function()
	while Running do
		pcall(function()
			if os.clock() - coinsAt > 3 then
				coinsAt = os.clock()
				task.spawn(function() local c = call("CurrencyService", "GetCurrency"); if type(c) == "number" then coinsCache = c end end)
			end
			vPhase.Text = Phase
			vPhase.TextColor3 = busy() and T.Text or T.Sub
			local h = hum()
			local hp = hpPct()
			mHp(h and ("%d / %d"):format(math.floor(h.Health), math.floor(h.MaxHealth)) or "—", hp / 100,
				hp < CONFIG.GuardHpPct and T.Bad or hp < CONFIG.SafeHpPct and T.Warn or T.Good)
			local fp = fuelPct()
			local nCans = #fuelTools()
			mFuel(("%d%%%s"):format(math.floor(fp), nCans > 0 and ("  +" .. nCans .. " кан.") or ""), fp / 100,
				fp < 20 and T.Bad or fp < CONFIG.FuelTargetPct and T.Warn or T.Accent)
			local n, cap = bagUsage()
			local bf = (n and cap and cap > 0) and n / cap or 0
			mBag((n and cap) and (n .. " / " .. cap) or "—", bf, bf * 100 >= CONFIG.SellAtPct and T.Warn or T.Accent)
			dot.BackgroundColor3 = State.Auto and T.Good or busy() and T.Warn or T.Off
			vCoins.Text = coinsCache and tostring(coinsCache) or "—"
			local d = getDrill()
			vDmg.Text = d and tostring(1 + (d:GetAttribute("DrillPower") or 0) + (d:GetAttribute("BonusDamage") or 0)) or "—"
			local t = math.floor(Stats.start and (os.clock() - Stats.start) or 0)
			vTime.Text = ("%d:%02d:%02d"):format(t // 3600, t % 3600 // 60, t % 60)
			counters.Text = ("Сундуки %d · Лут %d · Данжи %d · Убито %d · Укрытия %d\nАпгрейды %d · Покупки %d · Аптечки %d (есть %d) · Заправки %d · Продажи %d")
				:format(Stats.chests, Stats.items, Stats.dungeons, Stats.kills, Stats.hides,
					Stats.upgrades, Stats.bought or 0, Stats.heals or 0, #medkits(), Stats.refuels, Stats.sells)
			subLabel.Text = busy() and Phase or "Drill to Earth's Core"
			if (autoBtn.Text:find("ОСТАНОВИТЬ", 1, true) ~= nil) ~= State.Auto then renderAuto() end
		end)
		task.wait(0.5)
	end
end)

-- Профиль: куда уходит время (раз в 5 минут — топ фаз в лог), чтобы искать простои
task.spawn(function()
	local acc, t0 = {}, os.clock()
	while Running do
		task.wait(0.5)
		if busy() then
			local k = tostring(Phase):gsub("%d+", "#"):gsub("%s*%b()", "")
			acc[k] = (acc[k] or 0) + 0.5
		end
		if os.clock() - t0 >= 300 then
			local l = {}
			for k, v in pairs(acc) do table.insert(l, { k, v }) end
			table.sort(l, function(x, y) return x[2] > y[2] end)
			local out = {}
			for i = 1, math.min(8, #l) do table.insert(out, ("%s %.0fс"):format(l[i][1], l[i][2])) end
			local d = getDrill()
			status(("[Prof] 5 мин, X=%s: %s"):format(d and tostring(math.floor(pos(d).X)) or "?", table.concat(out, " | ")))
			acc, t0 = {}, os.clock()
		end
	end
end)

-- Закрыть скрипт полностью
local function shutdown()
	Running = false
	pcall(function() if driveStarted then driveStop() end end)
	pcall(function() local r = hrp(); if r then r.Anchored = false end end)
	pcall(function() game:GetService("ContextActionService"):UnbindAction("DF_MenuWheel") end)
	-- горячая перезагрузка (DF_Reloading): запомнить режимы, чтобы новая копия сразу продолжила —
	-- иначе персонаж секунды стоит без защиты (так погиб на 46% HP у орды)
	if getgenv and getgenv().DF_Reloading then
		getgenv().DF_PrevState = { Auto = State.Auto, NoDrive = State.NoDrive, DungeonFarm = State.DungeonFarm }
	end
	for k in pairs(State) do State[k] = false end
	for _, c in ipairs(Connections) do c:Disconnect() end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "_DF_HL" and d:IsA("Highlight") then d:Destroy() end
	end
	gui:Destroy()
	print("[DrillFarm] Скрипт закрыт")
end
closeBtn.MouseEnter:Connect(function() tween(closeBtn, { TextColor3 = Color3.fromRGB(255, 90, 90) }) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, { TextColor3 = T.Sub }) end)
closeBtn.MouseButton1Click:Connect(function()
	ask("Закрыть DrillFarm?", "Авто-фарм и все функции остановятся, меню исчезнет до перезапуска скрипта.", "Закрыть", shutdown)
end)
getgenv = getgenv or function() return _G end
getgenv().DrillFarmClose = shutdown

-- Свернуть / скрыть
local collapsed = false
minBtn.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	view.Visible = not collapsed
	tabHolder.Visible = not collapsed
	minBtn.Text = collapsed and "+" or "–"
end)
bind(UIS.InputBegan, function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

-- Перетаскивание за шапку
do
	local dragging, startPos, startInput
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, main.Position, i.Position
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then dragging = false; fitHeight() end
		end
	end)
end

-- доступ для отладочных команд (DF_cmd.lua)
getgenv().DF = { State = State, CONFIG = CONFIG, Stats = Stats, status = status, scan = scan, call = call,
	groundItems = groundItems, pickupItem = pickupItem, grabSack = grabSack, chestStep = chestStep, moveTo = moveTo,
	inventory = inventory, bagUsage = bagUsage, invEntries = invEntries, sellAll = sellAll, sellStep = sellStep,
	equipWeapon = equipWeapon, enemies = enemies, killOne = killOne, killStep = killStep, hide = hide,
	drive = drive, driveStop = driveStop, refuel = refuel, fuelPct = fuelPct, fuelTools = fuelTools,
	upgradeStep = upgradeStep, skipCutscene = skipCutscene, autoStep = autoStep, lootStep = lootStep,
	gateNear = gateNear, enterGate = enterGate, exitDungeon = exitDungeon, dungeonRun = dungeonRun,
	finalWallAhead = finalWallAhead, oldGear = oldGear, AS = AS, shopStep = shopStep, armorStep = armorStep, smeltStep = smeltStep, phase = function() return Phase end }
status("[DrillFarm] Загружен")
end)()
