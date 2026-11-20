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

local Running = true
local Connections = {}
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
		while Running do
			if State[name] then pcall(fn) end
			task.wait(CONFIG.Tick)
		end
	end)
end
task.spawn(function()
	while Running do pcall(highlightStep); task.wait(1) end
end)

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
-- Прокручиваемый контент (для телефонов)
local content = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, BorderSizePixel = 0,
	LayoutOrder = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent, ScrollingDirection = Enum.ScrollingDirection.Y,
	ElasticBehavior = Enum.ElasticBehavior.Always,
}, main)
local list = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12) }, content)

-- Высота = контент, но не больше 65% экрана
local function fitHeight()
	local vp = workspace.CurrentCamera.ViewportSize.Y
	local h = list.AbsoluteContentSize.Y + 12
	content.Size = UDim2.new(1, 0, 0, math.min(h, math.floor(vp * 0.65) - 44))
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
	hit.MouseButton1Click:Connect(function()
		State[key] = not State[key]
		local on = State[key]
		tween(track, { BackgroundColor3 = on and T.Accent or T.Off })
		tween(knob, { Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) })
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
			dragging = true; content.ScrollingEnabled = false; set(i.Position.X)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			set(i.Position.X)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false; content.ScrollingEnabled = true
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
	b.MouseButton1Click:Connect(fn)
end

section("Фарм")
toggle("Farm", "Авто-фарм руды")
toggle("Collect", "Авто-сбор")
toggle("Ammo", "Патроны (25 st)")
toggle("AutoBuy", "Автопокупка")
section("Бур")
toggle("Fuel", "Заправка")
toggle("Gate", "Ворота подземелья")
section("Прочее")
toggle("Burn", "Сжигание трупов")
toggle("Highlight", "Подсветка монстров")
section("Настройки")
slider("Радиус поиска руды", "OreSearchRadius", 0, 500, 10)
slider("Время на руду, сек", "MaxTimePerOre", 0, 30, 1)
slider("Топливо, %", "FuelTargetPct", 10, 100, 5)
slider("Макс. цена трупа", "CorpseMaxValue", 0, 2000, 50)
action("Scan  ·  F9", scan)
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
	content.Visible = not collapsed
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
