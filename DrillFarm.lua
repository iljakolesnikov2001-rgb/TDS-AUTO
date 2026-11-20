-- DrillFarm.lua — Drill to Earth's Core
-- Фарм руды, сбор, автопокупка, топливо, ворота подземелья, сжигание трупов, подсветка монстров.
-- ВАЖНО: имена объектов в игре неизвестны заранее. Сначала нажмите "Scan" в меню,
-- посмотрите вывод в консоли (F9) и поправьте CONFIG.

----------------------------------------------------------------- CONFIG
local CONFIG = {
	-- Руда
	OreNames        = {},    -- типы руды (SessionOreType: "Coal", "Iron"...); пусто = любая
	MaxTimePerOre   = 8,     -- сек; 0 = без лимита
	OreSearchRadius = 150,   -- студов; 0 = без лимита
	PickaxeName     = "Pickaxe",

	-- Сумка (атрибуты игрока/персонажа)
	BagCountAttr    = "CarryUsage",     -- атрибут игрока (из скана)
	BagCapacityAttr = "CarryCapacity",

	-- Магазин
	ShopName        = "Shop",
	RegisterName    = "Register",
	BuyRemoteName   = "Buy",          -- RemoteFunction/RemoteEvent внутри ShopService
	AutoBuyItems    = { "Ammo", "Medkit", "Grenade" },
	AutoBuyLimit    = 3,              -- держать в инвентаре не меньше N штук

	-- Сбор
	IgnoredItems    = { "Rock" },
	ItemsMinValue   = 0,               -- собирать предметы с Value >= N (Workspace.Items)
	AmmoNames       = { "Ammo" },
	AmmoRadius      = 25,

	-- Бур
	DrillName       = "Drill",
	FuelAttr        = "Fuel",
	MaxFuelAttr     = "MaxFuel",
	FuelTargetPct   = 95,
	RefuelPromptKey = "Fuel",          -- подстрока в ActionText/Name промпта
	GateName        = "DungeonGate_",  -- Workspace.DungeonGate_Tier1B и т.д.
	GateStopDist    = 60,
	DriveMinFuel    = 3,               -- Авто-поездка: стоп, когда топлива меньше (ед.)
	DriveMinHpPct   = 30,              -- Авто-поездка: стоп, когда здоровья меньше (%)
	GatePromptKey   = "Enter",

	-- Трупы
	CorpseKey       = "Corpse",
	CorpseMaxValue  = 300,
	BurnPromptKey   = "Burn",

	-- Сундуки
	ChestRadius     = 150,             -- авто-сбор открывает незапертые сундуки в этом радиусе

	-- Убийство монстров из-под земли (киркой: хитбокс удара считается от персонажа, пол не мешает)
	KillRadius      = 80,              -- Kill Aura: монстры в этом радиусе
	GateRadius      = 1500,            -- как далеко искать ворота подземелья (летим к ним)
	DungeonRadius   = 400,             -- Авто-данж: ищем монстров и сундуки в этом радиусе
	KillTimeout     = 30,              -- сек на одного монстра

	-- Подсветка
	MonsterFilter   = {},              -- пусто = все монстры
	HighlightColor  = Color3.fromRGB(255, 60, 60),

	SellKeepRarity  = { "Legendary", "Mythic", "Exotic", "Secret", "Divine" }, -- не продавать
	SellKeepCategory= { "Fuel" },        -- не продавать (топливо)
	MoveSpeed       = 540,              -- студов/сек при перелёте к предмету (меньше = безопаснее)
	PickupDelay     = 0.6,             -- пауза после подбора, сек
	Tick            = 0.25,
}

----------------------------------------------------------------- SERVICES
local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local VIM      = game:GetService("VirtualInputManager")
local player   = Players.LocalPlayer

local Running = true
local Selling = false -- пока идёт продажа, остальные функции ждут
local Connections = {}
local State = { Farm=false, Collect=false, Ammo=false, AutoBuy=false,
                Fuel=false, Gate=false, Burn=false, Highlight=false, Noclip=false, AutoSell=false, KillAura=false, Dungeon=false, AutoDrive=false }
local function collecting() return State.Collect or State.Dungeon end

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
	while true do
		r = hrp()
		if not r or not obj.Parent or (stillOk and not stillOk()) then return false end
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

local function nearestShop()
	local shops = findAll(function(d)
		return d:IsA("Model") and hasKey(d.Name, {CONFIG.ShopName})
	end)
	local shop = nearest(shops)
	return shop, shop and (shop:FindFirstChild(CONFIG.RegisterName, true) or shop)
end

local function buyRemote()
	for _, d in ipairs(RS:GetDescendants()) do
		if (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) and d.Name == CONFIG.BuyRemoteName then
			return d
		end
	end
end

local function countTool(name)
	local n = 0
	for _, src in ipairs({ player.Backpack, player.Character }) do
		if src then
			for _, t in ipairs(src:GetChildren()) do
				if t:IsA("Tool") and hasKey(t.Name, {name}) then n += 1 end
			end
		end
	end
	return n
end

----------------------------------------------------------------- FEATURES
local gameTool -- ниже (рядом со swing)
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
	-- EquipTool — переключатель: повторный вызов на уже экипированном инструменте СНИМАЕТ его
	if best.Parent == c then
		for _ = 1, 6 do
			at = gameTool()
			if at and at.Tool == best then break end
			task.wait(0.1)
		end
		return best
	end
	local eq = knit("ToolService", "EquipTool")
	if not eq then return end
	pcall(function() eq:InvokeServer(best) end)
	for _ = 1, 10 do
		at = gameTool()
		if at and at.Tool == best then return best end
		task.wait(0.1)
	end
	return best
end
-- экипируем только через ToolService.EquipTool (Humanoid:EquipTool не создаёт ActiveTool — удары не засчитываются)
local function equipPickaxe()
	return equipBest(function(t) return hasKey(t.Name, { CONFIG.PickaxeName }) and 1 end)
end
-- оружие для монстров: ближний бой с наибольшим уроном (меч бьёт в 5 раз сильнее кирки)
local function equipWeapon()
	return equipBest(function(t)
		if t:GetAttribute("ActionType") == "Swing" and not hasKey(t.Name, { CONFIG.PickaxeName }) then
			return t:GetAttribute("Damage") or 1
		end
	end) or equipPickaxe()
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
	if at and at.Tool == tool and at.Swing then pcall(at.Swing, at) end
end

local pickupOresNear -- определяется ниже (после collect)

-- Точка продажи: ...TradingPost.SellParts.SellPart
-- Если стол далеко, игра его не прогружает (streaming) — запоминаем позицию,
-- летим туда и просим сервер прогрузить область.
local lastSellPos
local function findSellParts()
	return findAll(function(d)
		return d:IsA("BasePart") and d.Name == "SellPart" and d:FindFirstAncestor("TradingPost") ~= nil
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
	local sell = State.AutoSell and nearestSellPart()
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

local function farmStep()
	if bagFull() then
		onBagFull("Farm")
		if bagFull() then State.Farm = false end
		return
	end
	local node = nearest(oreNodes(), CONFIG.OreSearchRadius)
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

	if not moveTo(ore, function() return State.Farm end, stand) then return end
	local tool = equipPickaxe()
	local start = os.clock()
	while State.Farm and oreAlive(node) do
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
	if State.Farm and oreAlive(node) then
		-- не добили (слабая кирка/монстр мешает) — 30 сек не возвращаемся, иначе крутимся на одной жиле
		node:SetAttribute("_DF_Skip", true)
		task.delay(30, function() if node.Parent then node:SetAttribute("_DF_Skip", nil) end end)
	end
	task.wait(0.4)
	if State.Farm and not oreAlive(node) and pickupOresNear then pickupOresNear(p, 25) end
end


-- Предметы лежат в Workspace.Items (атрибуты Value, Category, DisplayName)
-- Предметы на земле: Workspace.Items + лут (атрибут SessionSnapshotItemId), не на персонажах
local skipUntil = setmetatable({}, { __mode = "k" })
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
local function collectItems()
	local items = groundItems()
	table.sort(items, function(a, b) return dist(a) < dist(b) end)
	for _, it in ipairs(items) do
		if not collecting() then return end
		if bagFull() then
			onBagFull("Collect")
			if bagFull() then State.Collect = false; State.Dungeon = false end
			return
		end
		local v = it:GetAttribute("Value") or 0
		local name = it:GetAttribute("DisplayName") or it.Name
		-- в режиме данжа не летаем за лутом по всей карте (там и погибал персонаж)
		if not State.Collect and dist(it) > CONFIG.DungeonRadius then
			-- пропуск
		elseif it:GetAttribute("ItemDatabaseId") == "Money_Sack" then
			if (skipUntil[it] or 0) < os.clock() and not grabSack(it) then skipUntil[it] = os.clock() + 30 end
		elseif v >= CONFIG.ItemsMinValue and not hasKey(name, CONFIG.IgnoredItems)
			and (skipUntil[it] or 0) < os.clock() then
			if moveTo(it, collecting) then
				task.wait(0.15)
				if pickupItem(it) then
					status("[Collect] подобрал: " .. name)
					task.wait(CONFIG.PickupDelay)
				else
					-- не поднялся (не влез/нельзя) — не возвращаемся к нему 60 сек
					skipUntil[it] = os.clock() + 60
					status("[Collect] не поднялся: " .. name)
				end
			end
		end
	end
end

-- Поднять выпавшую руду (DisplayCategory=Ore) рядом с точкой
pickupOresNear = function(center, radius)
	local folder = workspace:FindFirstChild("Items")
	if not folder then return end
	local t0 = os.clock()
	repeat -- руда может появиться не сразу
		local found = false
		for _, it in ipairs(folder:GetChildren()) do
			if not State.Farm or bagFull() then return end
			local p = pos(it)
			if it:GetAttribute("DisplayCategory") == "Ore" and it:GetAttribute("SessionSnapshotItemId") and p and (p - center).Magnitude <= radius
				and (skipUntil[it] or 0) < os.clock() then
				found = true
				if moveTo(it, function() return State.Farm end) then
					task.wait(0.15)
					if pickupItem(it) then task.wait(CONFIG.PickupDelay) else skipUntil[it] = os.clock() + 60 end
				end
			end
		end
		if found then return end
		task.wait(0.3)
	until os.clock() - t0 > 2
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
	local tries = {
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

-- Только предметы из Workspace.Items; сундуки/двери/NPC не трогаем
local function collectStep(onlyAmmo)
	if not onlyAmmo then return collectItems() end
	local folder = workspace:FindFirstChild("Items")
	if not folder then return end
	for _, it in ipairs(folder:GetChildren()) do
		local name = (it:GetAttribute("DisplayName") or it.Name)
		if it:GetAttribute("SessionSnapshotItemId") and hasKey(name, CONFIG.AmmoNames) and dist(it) <= CONFIG.AmmoRadius then
			pickupItem(it)
		end
	end
end

local function autoBuyStep()
	local remote = buyRemote()
	if not remote then return end
	for _, name in ipairs(CONFIG.AutoBuyItems) do
		if countTool(name) < CONFIG.AutoBuyLimit then
			pcall(function()
				if remote:IsA("RemoteFunction") then remote:InvokeServer(name)
				else remote:FireServer(name) end
			end)
		end
	end
end

local function getDrill()
	return workspace:FindFirstChild(CONFIG.DrillName) or workspace:FindFirstChild(CONFIG.DrillName, true)
end

local function fuelStep()
	local drill = getDrill()
	if not drill then return end
	local fuel, max = drill:GetAttribute(CONFIG.FuelAttr), drill:GetAttribute(CONFIG.MaxFuelAttr)
	if fuel and max and max > 0 and fuel / max * 100 < CONFIG.FuelTargetPct then
		firePrompt(drill, CONFIG.RefuelPromptKey)
	end
end

-- Авто-поездка бура: DrillService.StartDriving → в LocalDriverSeat → UpdateDriverThrottle(1) каждый тик.
-- Нужна, чтобы не срабатывал телепорт обратно к буру, когда мы далеко уходим от него.
-- Защиты: все вызовы в pcall; стоп при пустом топливе, низком здоровье, смерти и у ворот подземелья;
-- при любом выключении газ сбрасывается и мы выходим из водительского места.
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
local function driveStop(why)
	if driveStarted then
		local d = getDrill()
		local seat = d and d:FindFirstChild("LocalDriverSeat", true)
		if seat then pcall(function() seat.ThrottleFloat = 0; seat.Throttle = 0 end) end
		driveCall("UpdateDriverThrottle", 0)
		driveCall("StopDriving")
		driveStarted = false
	end
	if why then status("[Drive] стоп: " .. why) end
	State.AutoDrive = false
end
local function driveStep()
	local drill = getDrill()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (drill and hum) then return end
	if hum.Health <= 0 then return driveStop("персонаж умер") end
	if hum.Health < hum.MaxHealth * CONFIG.DriveMinHpPct / 100 then return driveStop("мало здоровья") end
	local fuel = drill:GetAttribute(CONFIG.FuelAttr)
	if fuel and fuel < CONFIG.DriveMinFuel then return driveStop("кончилось топливо") end
	for _, g in ipairs(workspace:GetChildren()) do
		if g:IsA("Model") and string.sub(g.Name, 1, #CONFIG.GateName) == CONFIG.GateName and not g.Name:find("Tutorial") then
			local p1, p2 = pos(g), pos(drill)
			if p1 and p2 and (p1 - p2).Magnitude <= CONFIG.GateStopDist then return driveStop("доехали до ворот " .. g.Name) end
		end
	end
	if drill:GetAttribute("DriverUserId") ~= player.UserId then
		-- сесть: подлететь к месту водителя и попросить сервер
		local seat = drill:FindFirstChild("LocalDriverSeat", true)
		local r = hrp()
		if seat and r then r.CFrame = seat.CFrame * CFrame.new(0, 3, 0) end
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
	-- газ даём через само место водителя: клиент игры читает seat.ThrottleFloat и сам шлёт UpdateDriverThrottle
	-- (если слать самим, игра перебивает наш газ своим нулём)
	local seat = drill:FindFirstChild("LocalDriverSeat", true)
	if seat then pcall(function() seat.ThrottleFloat = 1; seat.Throttle = 1 end) end
end

local function gateStep()
	local drill = getDrill()
	if not drill then return end
	local gates = {}
	for _, g in ipairs(workspace:GetChildren()) do
		if g:IsA("Model") and string.sub(g.Name, 1, #CONFIG.GateName) == CONFIG.GateName then table.insert(gates, g) end
	end
	for _, g in ipairs(gates) do
		local p1, p2 = pos(g), pos(drill)
		if p1 and p2 and (p1 - p2).Magnitude <= CONFIG.GateStopDist then
			VIM:SendKeyEvent(false, Enum.KeyCode.W, false, game) -- отпустить газ
			firePrompt(g, CONFIG.GatePromptKey)
		end
	end
end

local function burnStep()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and hasKey(d.Name, {CONFIG.CorpseKey}) then
			local v = d:GetAttribute("Value")
			if v and v <= CONFIG.CorpseMaxValue and not d:GetAttribute("Bounty") then
				firePrompt(d, CONFIG.BurnPromptKey)
			end
		end
	end
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
local function chestStep()
	if os.clock() < chestNextScan then return end
	chestNextScan = os.clock() + 2
	-- Enabled не проверяем: игра часто включает промпт сундука, только когда игрок рядом.
	-- Текст промпта тоже не важен — достаточно, что он висит на сундуке.
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and (chestTried[d] or 0) < os.clock() and chestInfo(d) then
			table.insert(list, d)
		end
	end
	local best, bd = nil, CONFIG.ChestRadius > 0 and CONFIG.ChestRadius or math.huge
	for _, pr in ipairs(list) do
		local d = dist(pr.Parent)
		if d < bd then best, bd = pr, d end
	end
	if not best then return false end
	chestTried[best] = os.clock() + 120 -- не открылся — вернёмся не раньше чем через 2 мин
	local chest = chestNode(best) or best.Parent
	if moveTo(best.Parent, collecting) then
		task.wait(0.3) -- дать игре включить промпт
		local wasOn = best.Enabled
		local function opened() return changed("chest", chest) or not best.Parent or (wasOn and not best.Enabled) end
		local ok = replay("chest", chest) or usePrompt(best, opened)
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

----------------------------------------------------------------- KILL AURA / DUNGEON
-- Бьём монстров мечом, паря над макушкой монстра и глядя на него.
local RunService = game:GetService("RunService")
local killSkip = setmetatable({}, { __mode = "k" })
local Killing = false
local lastSurface

local function enemies(radius)
	local out, folder, r = {}, workspace:FindFirstChild("Npc"), hrp()
	if not (folder and r) then return out end
	for _, m in ipairs(folder:GetChildren()) do
		local h = m:IsA("Model") and m:FindFirstChild("Humanoid")
		-- мимики (Health ~1e11) — сундуки-монстры, их не бьём
		if h and h.Health > 0 and h.MaxHealth < 1e6 and m:GetAttribute("NpcFaction") == "Enemy"
			and (killSkip[m] or 0) < os.clock() then
			local p = pos(m)
			if p and (radius <= 0 or (p - r.Position).Magnitude <= radius) then table.insert(out, m) end
		end
	end
	table.sort(out, function(a, b) return dist(a) < dist(b) end)
	return out
end

-- Позиция для удара (смещение от центра монстра). Опытным путём: над монстром не выше макушки+2 и
-- сбоку в пределах ~6 st работает; точное зависит от монстра и стен — поэтому перебираем по кругу,
-- пока не пойдёт урон, и запоминаем рабочий вариант.
local killCands = {
	Vector3.new(0, 4, 0),  -- над головой (моб снизу не достаёт)
	Vector3.new(6, 3, 0),  -- сбоку, подальше
	Vector3.new(0, 3, 6),
	Vector3.new(3, 0, 0),  -- вплотную на уровне груди (всегда работает, но моб бьёт в ответ)
}
local killIdx = 1
local function standUnder(m)
	local ok, cf, size = pcall(m.GetBoundingBox, m)
	if not ok then local p = pos(m); return p and p + Vector3.new(0, 3, 0), p, p end
	local mid = cf.Position
	local base = Vector3.new(mid.X, mid.Y - size.Y / 2, mid.Z)
	return mid + killCands[killIdx], base, mid
end

local function killOne(m)
	local h = m:FindFirstChild("Humanoid")
	local tool = equipWeapon()
	if not (h and tool) then killSkip[m] = os.clock() + 30; return end
	local stand, base, mid = standUnder(m)
	if not stand then return end
	if not moveTo(m, function() return State.KillAura or State.Dungeon end, stand) then return end
	Moving = true -- ноклип на время удара
	local t0, lastHp, lastHit = os.clock(), h.Health, os.clock()
	local misses = 0
	while Running and (State.KillAura or State.Dungeon) and m.Parent and h.Health > 0 do
		local r = hrp()
		stand, base, mid = standUnder(m)
		if not (r and stand) then break end
		lastSurface = base
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(stand, mid)
		swing(tool)
		if h.Health < lastHp - 0.01 then lastHp, lastHit = h.Health, os.clock() end
		if os.clock() - lastHit > 1.2 then -- урона нет: следующая позиция из списка
			killIdx = killIdx % #killCands + 1
			lastHit, misses = os.clock(), misses + 1
			if misses > #killCands * 2 then break end -- два круга без урона — пропускаем монстра
		end
		if CONFIG.KillTimeout > 0 and os.clock() - t0 > CONFIG.KillTimeout then break end
		RunService.Heartbeat:Wait()
	end
	Moving = false
	local dead = not m.Parent or h.Health <= 0
	if not dead then killSkip[m] = os.clock() + 30 end
	status(("[Kill] %s: %s за %.1fс"):format(m.Name, dead and "убит" or "не убил", os.clock() - t0))
end

-- true — были монстры (шаг занят), false — убивать некого
local function killStep(radius, back)
	if Killing then return true end
	if #enemies(radius) == 0 then return false end
	Killing, Selling = true, true
	local r = hrp()
	local origin = r and r.CFrame
	pcall(function()
		while Running and (State.KillAura or State.Dungeon) do
			local list = enemies(radius)
			if #list == 0 then break end
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

-- Вход в подземелье: летим к воротам DungeonGate_* и жмём их промпт.
-- Вызывается ПЕРЕД зачисткой: пока рядом (в DungeonRadius) есть ворота, мы ещё снаружи — входим.
local gateNext, gateSkip = 0, setmetatable({}, { __mode = "k" })
-- у каждых ворот два промпта: "Enter" (вход, у ворот) и "Exit" (выход из данжа, внутри) — нужен только Enter
local function enterPrompt(g)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == CONFIG.GatePromptKey then return d end
	end
end
local function enterGate()
	if os.clock() < gateNext or bagFull() then return false end
	gateNext = os.clock() + 8
	local best, bd
	for _, g in ipairs(workspace:GetChildren()) do
		if g:IsA("Model") and string.sub(g.Name, 1, #CONFIG.GateName) == CONFIG.GateName and not g.Name:find("Tutorial")
			and (gateSkip[g] or 0) < os.clock() then
			local d = dist(g)
			if d <= CONFIG.GateRadius and (not bd or d < bd) then best, bd = g, d end
		end
	end
	if not best then return false end
	local gp = pos(best)
	if bd > 40 and not moveTo(best, function() return State.Dungeon end) then return true end
	pcall(function() player:RequestStreamAroundAsync(gp, 5) end)
	-- ворота могли не прогрузиться: ждём промпт входа
	local pr
	for _ = 1, 20 do
		pr = enterPrompt(best)
		if pr then break end
		task.wait(0.25)
	end
	if not pr then
		gateSkip[best] = os.clock() + 120
		status("[Dungeon] у ворот нет промпта Enter: " .. best.Name)
		return true
	end
	local r = hrp()
	local target = pr.Parent:IsA("Attachment") and pr.Parent.WorldPosition or pos(pr.Parent)
	if r and target then r.CFrame = CFrame.new(target + Vector3.new(0, 3, 4)) end
	task.wait(0.4)
	status("[Dungeon] вход: " .. best.Name .. " (" .. tostring(pr.ObjectText) .. ")")
	local from = r and r.Position
	local function teleported() local c = hrp(); return c and from and (c.Position - from).Magnitude > 100 end
	local ok = usePrompt(pr, teleported)
	if not ok then -- запасной путь: Interact самой игры
		local inter = knit("InteractionService", "Interact")
		if inter then pcall(function() inter:InvokeServer(pr.Parent.Parent) end) end
	end
	for _ = 1, 20 do if teleported() then break end task.wait(0.25) end
	status(teleported() and "[Dungeon] вошёл" or "[Dungeon] вход не сработал: " .. best.Name)
	gateSkip[best] = os.clock() + 60 -- не входим в те же ворота сразу снова
	return true
end

-- Авто-данж: вход в ворота → все монстры → сундуки и лут
local function dungeonStep()
	if enterGate() then return end
	if killStep(CONFIG.DungeonRadius, false) then return end
	if chestStep() ~= false then return end -- nil = ждём следующий скан, true = занимались сундуком
	collectStep(false)
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

----------------------------------------------------------------- LOOPS
local loops = {
	Farm = farmStep, Collect = function() chestStep(); collectStep(false) end,
	Ammo = function() collectStep(true) end, AutoBuy = autoBuyStep,
	Fuel = fuelStep, Gate = gateStep, Burn = burnStep,
	KillAura = function() killStep(CONFIG.KillRadius, true) end, Dungeon = dungeonStep,
	AutoDrive = driveStep,
}
for name, fn in pairs(loops) do
	task.spawn(function()
		while Running do
			if State[name] and not Selling then pcall(fn) end
			task.wait(CONFIG.Tick)
		end
	end)
end
task.spawn(function()
	while Running do pcall(highlightStep); task.wait(1) end
end)
-- тумблер выключили вручную — сбросить газ и выйти из водительского места
task.spawn(function()
	while Running do
		if driveStarted and not State.AutoDrive then pcall(driveStop, "выключено") end
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

local main = new("Frame", {
	Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0, 24, 0.25, 0), BackgroundColor3 = T.Bg, BorderSizePixel = 0,
}, gui)
corner(main, 12); stroke(main)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, main)

-- Шапка
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 0 }, main)
new("TextLabel", {
	Text = "DrillFarm", Font = FONT_B, TextSize = 16, TextColor3 = T.Text,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 16, 0, 6), Size = UDim2.new(1, -90, 0, 18),
}, header)
new("TextLabel", {
	Text = "Drill to Earth's Core", Font = FONT, TextSize = 11, TextColor3 = T.Sub,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.new(0, 16, 0, 24), Size = UDim2.new(1, -90, 0, 14),
}, header)
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

-- Контент
-- Прокручиваемый контент: своя реализация (колесо, ЛКМ, палец)
local view = new("Frame", {
	Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, BorderSizePixel = 0,
	ClipsDescendants = true, LayoutOrder = 1,
}, main)
local content = new("Frame", {
	Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, BorderSizePixel = 0,
}, view)
local list = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 12) }, content)
local thumb = new("Frame", { Size = UDim2.new(0, 3, 0, 40), Position = UDim2.new(1, -5, 0, 0),
	BackgroundColor3 = T.Accent, BackgroundTransparency = 0.3, BorderSizePixel = 0 }, view)
corner(thumb, 2)

local scrollY, scrollMoved, sliderActive = 0, false, false
local function contentH() return list.AbsoluteContentSize.Y + 12 end
local function setScroll(y)
	local viewH = view.AbsoluteSize.Y
	local maxY = math.max(0, contentH() - viewH)
	scrollY = math.clamp(y, 0, maxY)
	content.Position = UDim2.new(0, 0, 0, -scrollY)
	thumb.Visible = maxY > 0
	if maxY > 0 then
		local th = math.max(24, viewH * viewH / contentH())
		thumb.Size = UDim2.new(0, 3, 0, th)
		thumb.Position = UDim2.new(1, -5, 0, (viewH - th) * scrollY / maxY)
	end
end
-- Высота = контент, но не больше 65% экрана
local function fitHeight()
	local vp = workspace.CurrentCamera.ViewportSize.Y
	view.Size = UDim2.new(1, 0, 0, math.min(contentH(), math.floor(vp * 0.65) - 44))
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
bind(list:GetPropertyChangedSignal("AbsoluteContentSize"), fitHeight)
bind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitHeight)

local order = 0
local function nextOrder() order += 1; return order end

local function section(title)
	new("TextLabel", {
		Text = string.upper(title), Font = FONT_B, TextSize = 10, TextColor3 = T.Sub,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(),
	}, content)
end

local function row(height)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.Card,
		BorderSizePixel = 0, LayoutOrder = nextOrder() }, content)
	corner(r, 8)
	return r
end

local function toggle(key, title)
	local r = row(34)
	new("TextLabel", {
		Text = title, Font = FONT, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -64, 1, 0),
	}, r)
	local track = new("Frame", { Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -46, 0.5, -9),
		BackgroundColor3 = T.Off, BorderSizePixel = 0 }, r)
	corner(track, 9)
	local knob = new("Frame", { Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = T.Text, BorderSizePixel = 0 }, track)
	corner(knob, 7)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, r)
	hit.MouseEnter:Connect(function() tween(r, { BackgroundColor3 = T.Hover }) end)
	hit.MouseLeave:Connect(function() tween(r, { BackgroundColor3 = T.Card }) end)
	local shown = false
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
	-- если скрипт сам выключил функцию (сумка полна и т.п.) — обновить переключатель
	task.spawn(function()
		while Running do
			if State[key] ~= shown then render() end
			task.wait(0.3)
		end
	end)
end

local function slider(title, cfgKey, min, max, step)
	local r = row(46)
	new("TextLabel", {
		Text = title, Font = FONT, TextSize = 13, TextColor3 = T.Text, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -70, 0, 16),
	}, r)
	local val = new("TextLabel", {
		Text = tostring(CONFIG[cfgKey]), Font = FONT_B, TextSize = 12, TextColor3 = T.Accent,
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -62, 0, 6), Size = UDim2.new(0, 50, 0, 16),
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
		val.Text = tostring(v)
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

local function action(title, fn)
	local b = new("TextButton", {
		Text = title, Font = FONT_B, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false,
		BackgroundColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(),
	}, content)
	corner(b, 8)
	b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.15 }) end)
	b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0 }) end)
	b.MouseButton1Click:Connect(function() if not scrollMoved then fn(b) end end)
	return b
end

section("Фарм")
toggle("Farm", "Авто-фарм руды")
toggle("Collect", "Авто-сбор")
toggle("Ammo", "Патроны (25 st)")
toggle("AutoBuy", "Автопокупка")
toggle("AutoSell", "Автопродажа (сумка полна)")
section("Подземелье")
toggle("Dungeon", "Авто-данж (монстры + сундуки)")
toggle("KillAura", "Kill Aura (из-под земли)")
section("Бур")
toggle("Fuel", "Заправка")
toggle("Gate", "Ворота подземелья")
toggle("AutoDrive", "Авто-поездка бура")
action("Телепорт к дрели", function(b)
	local drill = getDrill()
	if drill then
		tpToDrill(drill)
		b.Text = "Готово ✓"
	else
		b.Text = "Дрель не найдена"
	end
	task.delay(1.5, function() if b.Parent then b.Text = "Телепорт к дрели" end end)
end)
section("Прочее")
toggle("Burn", "Сжигание трупов")
toggle("Noclip", "Noclip")
toggle("Highlight", "Подсветка монстров")
section("Настройки")
slider("Радиус поиска руды", "OreSearchRadius", 0, 500, 10)
slider("Радиус Kill Aura", "KillRadius", 10, 300, 10)
slider("Радиус данжа", "DungeonRadius", 50, 1000, 50)
slider("Время на руду, сек", "MaxTimePerOre", 0, 30, 1)
slider("Топливо, %", "FuelTargetPct", 10, 100, 5)
slider("Макс. цена трупа", "CorpseMaxValue", 0, 2000, 50)
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
local copyBtn
local function scanBtn(title, nearOnly)
	action(title, function(b)
		b.Text = "Сканирую..."
		lastScan = scan(nearOnly)
		b.Text = title .. "  ✓"
		copyBtn.BackgroundColor3 = T.Accent
		copyBtn.TextColor3 = T.Text
		copyBtn.Text = "Копировать скан"
		task.delay(2, function() if b.Parent then b.Text = title end end)
	end)
end
scanBtn("Scan", false)
scanBtn("Scan рядом (25 st)", true)
action("Инвентарь → F9", function(b)
	local rf = knit("CarryInventoryService", "GetInventory")
	local out = { "[Inventory]" }
	if rf then
		local ok, res = pcall(function() return rf:InvokeServer() end)
		dumpValue(ok and res or ("ошибка: " .. tostring(res)), "  ", out, 0)
	else
		table.insert(out, "  GetInventory не найден")
	end
	lastScan = table.concat(out, "\n")
	print(lastScan)
	copyBtn.BackgroundColor3 = T.Accent
	copyBtn.TextColor3 = T.Text
	copyBtn.Text = "Копировать скан"
	b.Text = "Готово ✓"
	task.delay(1.5, function() if b.Parent then b.Text = "Инвентарь → F9" end end)
end)
copyBtn = action("Копировать скан", function(b)
	if not lastScan then return end
	local ok = copyText(lastScan)
	b.Text = ok and "Скопировано ✓" or "Нет буфера · F9"
	task.delay(2, function() if b.Parent then b.Text = "Копировать скан" end end)
end)
copyBtn.BackgroundColor3 = T.Off
copyBtn.TextColor3 = T.Sub
copyBtn.Text = "Копировать · сначала Scan"
StatusLabel = new("TextLabel", {
	Text = "Статус: —", Font = FONT, TextSize = 11, TextColor3 = T.Accent, TextWrapped = true,
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, 0, 0, 28), LayoutOrder = nextOrder(),
}, content)
new("TextLabel", {
	Text = "RightShift — скрыть  ·  × — закрыть", Font = FONT, TextSize = 11, TextColor3 = T.Sub,
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder(),
}, content)
fitHeight()

-- Закрыть скрипт полностью
local function shutdown()
	Running = false
	pcall(function() if driveStarted then driveStop() end end)
	pcall(function() game:GetService("ContextActionService"):UnbindAction("DF_MenuWheel") end)
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
closeBtn.MouseButton1Click:Connect(shutdown)
getgenv = getgenv or function() return _G end
getgenv().DrillFarmClose = shutdown

-- Свернуть / скрыть
local collapsed = false
minBtn.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	view.Visible = not collapsed
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
			dragging = false
		end
	end)
end

-- доступ для отладочных команд (DF_cmd.lua)
getgenv().DF = { State = State, CONFIG = CONFIG, Learned = Learned, status = status, scan = scan,
	groundItems = groundItems, pickupItem = pickupItem, grabSack = grabSack, chestStep = chestStep,
	chestInfo = chestInfo, chestNode = chestNode, usePrompt = usePrompt, moveTo = moveTo, inventory = inventory,
	oreNodes = oreNodes, farmStep = farmStep, oreAlive = oreAlive, equipPickaxe = equipPickaxe, equipWeapon = equipWeapon, bagUsage = bagUsage,
	tryDrop = tryDrop, invEntries = invEntries, nearestSellPart = nearestSellPart, isMySack = isMySack, sellAll = sellAll,
	enterGate = enterGate, driveStep = driveStep, driveStop = driveStop, enemies = enemies, killOne = killOne, killStep = killStep, dungeonStep = dungeonStep }
status("[DrillFarm] Загружен")
