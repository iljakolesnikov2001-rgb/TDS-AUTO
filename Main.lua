-- Main.lua - 4 вкладки + recorder + рабочий equip
local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "TDSAutoStrat"
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 450)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(200, 80, 255)
stroke.Parent = mainFrame

-- Заголовок + закрытие + вкладки + текст (полный код из предыдущей версии)

-- Recorder (как раньше)
-- ... (кнопка recorderBtn в contents[2])

-- Equip в Стратегии (полностью как в DuxiiT)
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local slot = 1
local selectedTower = towers[1]

local slotLabel = Instance.new("TextLabel")
slotLabel.Text = "Слот: " .. slot
slotLabel.Size = UDim2.new(0, 400, 0, 40)
slotLabel.Position = UDim2.new(0.5, -200, 0, 180)
slotLabel.BackgroundTransparency = 1
slotLabel.TextColor3 = Color3.fromRGB(220, 100, 255)
slotLabel.TextSize = 24
slotLabel.Parent = contents[2]

local changeSlotBtn = Instance.new("TextButton")
changeSlotBtn.Text = "Сменить слот"
changeSlotBtn.Size = UDim2.new(0, 200, 0, 50)
changeSlotBtn.Position = UDim2.new(0.5, -200, 0, 230)
changeSlotBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
changeSlotBtn.TextColor3 = Color3.new(1,1,1)
changeSlotBtn.Parent = contents[2]

changeSlotBtn.MouseButton1Click:Connect(function()
    slot = (slot % 6) + 1
    slotLabel.Text = "Слот: " .. slot
end)

local towerLabel = Instance.new("TextLabel")
towerLabel.Text = "Башня: " .. selectedTower
towerLabel.Size = UDim2.new(0, 400, 0, 40)
towerLabel.Position = UDim2.new(0.5, -200, 0, 290)
towerLabel.BackgroundTransparency = 1
towerLabel.TextColor3 = Color3.fromRGB(220, 100, 255)
towerLabel.TextSize = 24
towerLabel.Parent = contents[2]

local changeTowerBtn = Instance.new("TextButton")
changeTowerBtn.Text = "Сменить башню"
changeTowerBtn.Size = UDim2.new(0, 200, 0, 50)
changeTowerBtn.Position = UDim2.new(0.5, -200, 0, 340)
changeTowerBtn.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
changeTowerBtn.TextColor3 = Color3.new(1,1,1)
changeTowerBtn.Parent = contents[2]

changeTowerBtn.MouseButton1Click:Connect(function()
    local idx = table.find(towers, selectedTower) or 1
    idx = idx % #towers + 1
    selectedTower = towers[idx]
    towerLabel.Text = "Башня: " .. selectedTower
end)

local equipBtn = Instance.new("TextButton")
equipBtn.Text = "Экипировать"
equipBtn.Size = UDim2.new(0, 200, 0, 50)
equipBtn.Position = UDim2.new(0.5, 0, 0, 340)
equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
equipBtn.TextColor3 = Color3.new(1,1,1)
equipBtn.Parent = contents[2]

equipBtn.MouseButton1Click:Connect(function()
    if game.PlaceId ~= 3260590327 then
        print("Только в лобби TDS!")
        return
    end
    game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", {Slot = slot, Tower = selectedTower})
    print("Экипировано " .. selectedTower .. " в слот " .. slot)
end)

print("Equip работает как в DuxiiT!")
