-- DrillFarm.lua — Drill to Earth's Core
-- Фарм руды, сбор, автопокупка, топливо, ворота подземелья, сжигание трупов, подсветка монстров.
-- ВАЖНО: имена объектов в игре неизвестны заранее. Сначала нажмите "Scan" в меню,
-- посмотрите вывод в консоли (F9) и поправьте CONFIG.

----------------------------------------------------------------- CONFIG
local CONFIG = {
	-- Руда
	OreNames        = { "Coal", "Iron", "Gold", "Diamond" }, -- подстроки имён руд
	MaxTimePerOre   = 8,     -- сек; 0 = без лимита
	OreSearchRadius = 150,   -- студов; 0 = без лимита
	PickaxeName     = "Pickaxe",

	-- Сумка (атрибуты игрока/персонажа)
	BagCountAttr    = "BagCount",
	BagCapacityAttr = "BagCapacity",

	-- Магазин
	ShopName        = "Shop",
	RegisterName    = "Register",
	BuyRemoteName   = "Buy",          -- RemoteFunction/RemoteEvent внутри ShopService
	AutoBuyItems    = { "Ammo", "Medkit", "Grenade" },
	AutoBuyLimit    = 3,              -- держать в инвентаре не меньше N штук

	-- Сбор
	IgnoredItems    = { "Rock" },
	AmmoNames       = { "Ammo" },
	AmmoRadius      = 25,

	-- Бур
	DrillName       = "Drill",
	FuelAttr        = "Fuel",
	MaxFuelAttr     = "MaxFuel",
	FuelTargetPct   = 95,
	RefuelPromptKey = "Fuel",          -- подстрока в ActionText/Name промпта
	GateName        = "DungeonGate",
	GateStopDist    = 60,
	GatePromptKey   = "DungeonDoorReady",

	-- Трупы
	CorpseKey       = "Corpse",
	CorpseMaxValue  = 300,
	BurnPromptKey   = "Burn",

	-- Подсветка
	MonsterFilter   = {},              -- пусто = все монстры
	HighlightColor  = Color3.fromRGB(255, 60, 60),

	Tick            = 0.25,
}

----------------------------------------------------------------- SERVICES
local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local VIM      = game:GetService("VirtualInputManager")
local player   = Players.LocalPlayer

local State = { Farm=false, Collect=false, Ammo=false, AutoBuy=false,
                Fuel=false, Gate=false, Burn=false, Highlight=false }

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

local function farmStep()
	if bagFull() then
		local _, reg = nearestShop()
		if reg then tp(reg) end
		State.Farm = false
		print("[Farm] Сумка полна — телепорт к магазину, фарм выключен")
		return
	end
	local ores = findAll(function(d)
		return (d:IsA("Model") or d:IsA("BasePart")) and hasKey(d.Name, CONFIG.OreNames)
			and not isCharacter(d)
	end)
	local ore = nearest(ores, CONFIG.OreSearchRadius)
	if not ore then return end
	local tool = equipPickaxe()
	local start = os.clock()
	while State.Farm and ore.Parent do
		if CONFIG.MaxTimePerOre > 0 and os.clock() - start > CONFIG.MaxTimePerOre then break end
		tp(ore, Vector3.new(0, 0, 3))
		if tool then tool:Activate() end
		firePrompt(ore)
		task.wait(0.15)
	end
end

local function collectStep(onlyAmmo)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("TouchTransmitter") then
			local item = d.Parent
			if item and not isCharacter(item:FindFirstAncestorOfClass("Model") or item) then
				local isAmmo = hasKey(item.Name, CONFIG.AmmoNames)
				local inShop = item:FindFirstAncestor(CONFIG.ShopName) ~= nil
				local ok = (onlyAmmo and isAmmo and dist(item) <= CONFIG.AmmoRadius)
					or (not onlyAmmo and not hasKey(item.Name, CONFIG.IgnoredItems))
				if ok and not inShop then
					if d:IsA("ProximityPrompt") then
						if not onlyAmmo then tp(item) end
						if fireproximityprompt then fireproximityprompt(d) end
					else
						touch(item)
					end
				end
			end
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
	return workspace:FindFirstChild(CONFIG.DrillName, true)
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
	local gates = findAll(function(d) return d.Name == CONFIG.GateName end)
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

local function highlightStep()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Humanoid") then
			local m = d.Parent
			if m and m:IsA("Model") and not isCharacter(m) then
				local want = #CONFIG.MonsterFilter == 0 or hasKey(m.Name, CONFIG.MonsterFilter)
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
end

----------------------------------------------------------------- SCANNER
local function scan()
	local seen = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local key = d.Parent.Name .. " | " .. d.ActionText
			if not seen[key] then seen[key] = true; print("[Prompt]", d.Parent:GetFullName(), "|", d.ActionText) end
		elseif d:IsA("Model") and next(d:GetAttributes()) then
			if not seen[d.Name] then
				seen[d.Name] = true
				local a = {}
				for k, v in pairs(d:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
				print("[Attr]", d:GetFullName(), table.concat(a, ", "))
			end
		end
	end
	for k, v in pairs(player:GetAttributes()) do print("[PlayerAttr]", k, v) end
	for _, d in ipairs(RS:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then print("[Remote]", d:GetFullName()) end
	end
	print("[Scan] Готово")
end

----------------------------------------------------------------- LOOPS
local loops = {
	Farm = farmStep, Collect = function() collectStep(false) end,
	Ammo = function() collectStep(true) end, AutoBuy = autoBuyStep,
	Fuel = fuelStep, Gate = gateStep, Burn = burnStep,
}
for name, fn in pairs(loops) do
	task.spawn(function()
		while true do
			if State[name] then pcall(fn) end
			task.wait(CONFIG.Tick)
		end
	end)
end
task.spawn(function()
	while true do pcall(highlightStep); task.wait(1) end
end)

----------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "DrillFarm", false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", gui)
frame.Size, frame.Position = UDim2.new(0, 180, 0, 0), UDim2.new(0, 20, 0.3, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.BackgroundColor3, frame.BorderSizePixel = Color3.fromRGB(20, 20, 20), 0
frame.Active, frame.Draggable = true, true
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 2)

local function button(text, onClick)
	local b = Instance.new("TextButton", frame)
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BackgroundColor3, b.BorderSizePixel = Color3.fromRGB(35, 35, 35), 0
	b.TextColor3, b.Font, b.TextSize = Color3.new(1, 1, 1), Enum.Font.Gotham, 14
	b.Text = text
	b.MouseButton1Click:Connect(function() onClick(b) end)
	return b
end

local labels = {
	{ "Farm", "Авто-фарм руды" }, { "Collect", "Авто-сбор" }, { "Ammo", "Патроны 25 st" },
	{ "AutoBuy", "Автопокупка" }, { "Fuel", "Топливо" }, { "Gate", "Ворота подземелья" },
	{ "Burn", "Сжигание трупов" }, { "Highlight", "Подсветка монстров" },
}
for _, l in ipairs(labels) do
	local key, title = l[1], l[2]
	button(title .. ": OFF", function(b)
		State[key] = not State[key]
		b.Text = title .. (State[key] and ": ON" or ": OFF")
		b.BackgroundColor3 = State[key] and Color3.fromRGB(40, 90, 50) or Color3.fromRGB(35, 35, 35)
	end)
end
button("Scan (F9)", scan)

print("[DrillFarm] Загружен. Нажмите Scan и настройте CONFIG.")
