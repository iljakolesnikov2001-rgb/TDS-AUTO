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
	GatePromptKey   = "Enter",

	-- Трупы
	CorpseKey       = "Corpse",
	CorpseMaxValue  = 300,
	BurnPromptKey   = "Burn",

	-- Сундуки
	ChestRadius     = 150,             -- авто-сбор открывает незапертые сундуки в этом радиусе

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
local Connections = {}
local State = { Farm=false, Collect=false, Ammo=false, AutoBuy=false,
                Fuel=false, Gate=false, Burn=false, Highlight=false, Noclip=false, AutoSell=false }

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

local function attr(name)
	local c = player.Character
	return player:GetAttribute(name) or (c and c:GetAttribute(name))
end

local function firePrompt(obj, key)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("ProximityPrompt") and (not key
			or hasKey(d.Name, {key}) or hasKey(d.ActionText, {key})) then
			if fireproximityprompt then
				fireproximityprompt(d)
			else
				d:InputHoldBegin(); task.wait(d.HoldDuration + 0.05); d:InputHoldEnd()
			end
			return true
		end
	end
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
local function bagFull()
	local n, cap = attr(CONFIG.BagCountAttr), attr(CONFIG.BagCapacityAttr)
	return n and cap and n >= cap
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
local function equipPickaxe()
	local c = player.Character
	if not c then return end
	local tool = c:FindFirstChildWhichIsA("Tool")
	if tool and hasKey(tool.Name, {CONFIG.PickaxeName}) then return tool end
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and hasKey(t.Name, {CONFIG.PickaxeName}) then
			c:FindFirstChildOfClass("Humanoid"):EquipTool(t)
			return t
		end
	end
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

local function swing(tool, target)
	if tool then pcall(function() tool:Activate() end) end
	local cam = workspace.CurrentCamera
	local p = pos(target)
	if cam and p then
		local v, on = cam:WorldToViewportPoint(p)
		if on then
			VIM:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 0)
			task.wait(0.03)
			VIM:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 0)
		end
	end
end

local pickupOresNear -- определяется ниже (после collect)

-- Точка продажи: ...TradingPost.SellParts.SellPart
local function nearestSellPart()
	local list = findAll(function(d)
		return d:IsA("BasePart") and d.Name == "SellPart" and d:FindFirstAncestor("TradingPost") ~= nil
	end)
	return nearest(list)
end

-- Сумка полна: к точке продажи (если есть), иначе к дрели
local sellAll -- определяется ниже
local function onBagFull(who)
	local sell = nearestSellPart()
	if sell then
		tp(sell)
		print("[" .. who .. "] Сумка полна — ТП к точке продажи")
		if State.AutoSell and sellAll then
			local ok, err = pcall(sellAll, sell)
			if not ok then warn("[Sell] ошибка: " .. tostring(err)) end
		end
	else
		local drill = workspace:FindFirstChild(CONFIG.DrillName)
		if drill then tp(drill, Vector3.new(0, 8, 0)) end
		print("[" .. who .. "] Сумка полна — ТП к дрели")
	end
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
		r = hrp()
		if r then
			r.CFrame = CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z))
			local cam = workspace.CurrentCamera
			if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, p) end
		end
		swing(tool, ore)
		task.wait(0.25)
	end
	task.wait(0.4)
	if State.Farm and not oreAlive(node) and pickupOresNear then pickupOresNear(p, 25) end
end

local function knit(service, name)
	local idx = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("_Index")
	if not idx then return end
	for _, d in ipairs(idx:GetDescendants()) do
		if d.Name == name and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == service then return d end
	end
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

local function collectItems()
	local pickup = knit("CarryInventoryService", "Pickup")
	if not pickup then return end
	local items = groundItems()
	table.sort(items, function(a, b) return dist(a) < dist(b) end)
	for _, it in ipairs(items) do
		if not State.Collect then return end
		if bagFull() then
			onBagFull("Collect")
			if bagFull() then State.Collect = false end
			return
		end
		local v = it:GetAttribute("Value") or 0
		local name = it:GetAttribute("DisplayName") or it.Name
		if v >= CONFIG.ItemsMinValue and not hasKey(name, CONFIG.IgnoredItems)
			and (skipUntil[it] or 0) < os.clock() then
			if moveTo(it, function() return State.Collect end) then
				task.wait(0.2)
				local before = attr(CONFIG.BagCountAttr)
				pcall(function() pickup:InvokeServer(it) end)
				task.wait(CONFIG.PickupDelay)
				-- не поднялся (не влез/нельзя) — не возвращаемся к нему 60 сек
				if it.Parent and attr(CONFIG.BagCountAttr) == before then skipUntil[it] = os.clock() + 60 end
			end
		end
	end
end

-- Поднять выпавшую руду (DisplayCategory=Ore) рядом с точкой
pickupOresNear = function(center, radius)
	local folder = workspace:FindFirstChild("Items")
	local pickup = knit("CarryInventoryService", "Pickup")
	if not folder or not pickup then return end
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
					local before = attr(CONFIG.BagCountAttr)
					pcall(function() pickup:InvokeServer(it) end)
					task.wait(CONFIG.PickupDelay)
					if it.Parent and attr(CONFIG.BagCountAttr) == before then skipUntil[it] = os.clock() + 60 end
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
local function invEntries()
	local rf = knit("CarryInventoryService", "GetInventory")
	if not rf then return {} end
	local ok, inv = pcall(function() return rf:InvokeServer() end)
	if not ok or type(inv) ~= "table" then return {} end
	local list = {}
	local function walk(t, depth)
		for k, v in pairs(t) do
			if type(v) == "table" then
				if v.ItemDatabaseId or v.ItemId or v.Id or v.GroupId or v.Name then
					table.insert(list, { key = k, data = v })
				elseif depth < 2 then
					walk(v, depth + 1)
				end
			end
		end
	end
	walk(inv, 0)
	return list
end

local function tryDrop(e)
	local usage = attr(CONFIG.BagCountAttr)
	local d = e.data
	local args = { e.key, d.GroupId, d.Id, d.ItemId, d.ItemDatabaseId, d.Name }
	local remotes = {
		knit("CarryInventoryService", "DropGroup"),
		knit("ToolService", "DropSpecificItem"),
	}
	for _, rf in ipairs(remotes) do
		for _, a in ipairs(args) do
			if a ~= nil then
				pcall(function() rf:InvokeServer(a) end)
				task.wait(0.4)
				if attr(CONFIG.BagCountAttr) ~= usage then return true end
			end
		end
	end
	return false
end

sellAll = function(sellPart)
	local folder = workspace:FindFirstChild("Items")
	local pickup = knit("CarryInventoryService", "Pickup")
	if not folder or not pickup then return end
	local spot = sellPart.Parent and sellPart.Parent.Parent
		and sellPart.Parent.Parent:FindFirstChild("SellSpot", true) or sellPart
	tp(spot, Vector3.new(0, 4, 0))
	task.wait(0.3)
	local mine = {}       -- то, что выкинули мы (продаётся)
	local kept = {}       -- ключи, которые нельзя продавать
	for _ = 1, 40 do
		local entries, dropped = invEntries(), false
		for _, e in ipairs(entries) do
			if not kept[e.key] then
				local before = {}
				for _, it in ipairs(folder:GetChildren()) do before[it] = true end
				if tryDrop(e) then
					dropped = true
					task.wait(0.3)
					for _, it in ipairs(folder:GetChildren()) do
						if not before[it] then
							local rar = it:GetAttribute("Rarity") or ""
							local cat = it:GetAttribute("Category") or ""
							if hasKey(rar, CONFIG.SellKeepRarity) or hasKey(cat, CONFIG.SellKeepCategory) then
								pcall(function() pickup:InvokeServer(it) end) -- вернуть в сумку
								kept[e.key] = true
								print("[Sell] оставляю: " .. (it:GetAttribute("DisplayName") or it.Name))
							else
								mine[it] = true
								print("[Sell] продаю: " .. (it:GetAttribute("DisplayName") or it.Name))
							end
						end
					end
					break -- инвентарь изменился — перечитать
				else
					kept[e.key] = true -- не получилось выкинуть — не трогаем
				end
			end
		end
		if not dropped then break end
		tp(spot, Vector3.new(0, 4, 0))
	end
	if next(mine) == nil then
		print("[Sell] нечего продавать (или не удалось выкинуть — нужен лог SimpleSpy)")
		return
	end
	-- ждём мешочек с золотом и подбираем всё новое рядом, что выкинули не мы
	local before = {}
	for _, it in ipairs(folder:GetChildren()) do before[it] = true end
	local t0 = os.clock()
	while os.clock() - t0 < 6 do
		for _, it in ipairs(folder:GetChildren()) do
			if not mine[it] and dist(it) < 30 and (not before[it] or not it:GetAttribute("Cost")) then
				local n = string.lower(it.Name .. " " .. tostring(it:GetAttribute("DisplayName") or ""))
				if n:find("gold") or n:find("coin") or n:find("bag") or n:find("money") or n:find("cash") then
					moveTo(it)
					pcall(function() pickup:InvokeServer(it) end)
					print("[Sell] подобрал: " .. it.Name)
					mine[it] = true
				end
			end
		end
		task.wait(0.4)
	end
end

-- Только предметы из Workspace.Items; сундуки/двери/NPC не трогаем
local function collectStep(onlyAmmo)
	if not onlyAmmo then return collectItems() end
	local folder = workspace:FindFirstChild("Items")
	if not folder then return end
	for _, it in ipairs(folder:GetChildren()) do
		local name = (it:GetAttribute("DisplayName") or it.Name)
		if it:GetAttribute("SessionSnapshotItemId") and hasKey(name, CONFIG.AmmoNames) and dist(it) <= CONFIG.AmmoRadius then
			local pickup = knit("CarryInventoryService", "Pickup")
			if pickup then pcall(function() pickup:InvokeServer(it) end) end
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

-- Сундуки: узел с SessionChestId; открываем только Locked=false и ChestOpenState=Idle
local chestTried = setmetatable({}, { __mode = "k" })
local function chestStep()
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:GetAttribute("SessionChestId") and d:GetAttribute("Locked") == false
			and d:GetAttribute("ChestOpenState") == "Idle" and (chestTried[d] or 0) < os.clock() then
			table.insert(list, d)
		end
	end
	local chest = nearest(list, CONFIG.ChestRadius)
	if not chest then return end
	chestTried[chest] = os.clock() + 20
	if moveTo(chest, function() return State.Collect end) then
		task.wait(0.2)
		firePrompt(chest)
		task.wait(1)
	end
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
}
for name, fn in pairs(loops) do
	task.spawn(function()
		while Running do
			if State[name] then pcall(fn) end
			task.wait(CONFIG.Tick)
		end
	end)
end
task.spawn(function()
	while Running do pcall(highlightStep); task.wait(1) end
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
		if t == Enum.UserInputType.MouseWheel then
			if over(i.Position) or over(UIS:GetMouseLocation()) then setScroll(scrollY - i.Position.Z * 40) end
		elseif dragging and not sliderActive and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
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
section("Бур")
toggle("Fuel", "Заправка")
toggle("Gate", "Ворота подземелья")
action("Телепорт к дрели", function(b)
	local drill = getDrill()
	if drill then
		tp(drill, Vector3.new(0, 8, 0))
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
new("TextLabel", {
	Text = "RightShift — скрыть  ·  × — закрыть", Font = FONT, TextSize = 11, TextColor3 = T.Sub,
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder(),
}, content)
fitHeight()

-- Закрыть скрипт полностью
local function shutdown()
	Running = false
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

print("[DrillFarm] Загружен. Нажмите Scan и настройте CONFIG.")
