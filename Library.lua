-- Library.lua - Все функции
local Library = {}

-- Recorder (локальный)
local recording = false
local log = {}

function Library:StartRecorder()
    recording = not recording
    print("Recorder: " .. (recording and "ВКЛ" or "ВЫКЛ"))
    if not recording then
        if #log > 0 then
            writefile("Strat.txt", table.concat(log, "\n"))
            print("Сохранено в Strat.txt (" .. #log .. " строк)")
            log = {}
        end
    end
end

function Library:Record(action)
    if recording then
        table.insert(log, action)
    end
end

-- Equip (локальный)
local towers = {"Scout","Sniper","Paintballer","Demoman","Hunter","Soldier","Militant","Freezer","Assassin","Shotgunner","Pyromancer","Ace Pilot","Medic","Farm","Rocketeer","Trapper","Military Base","Crook Boss","Electroshocker","Commander","Warden","Cowboy","DJ Booth","Minigunner","Ranger","Pursuit","Gatling Gun","Turret","Mortar","Mercenary Base","Brawler","Necromancer","Accelerator","Engineer","Hacker","Gladiator","Commando","Frost Blaster","Archer","Swarmer","Toxic Gunner","Sledger","Executioner","Elf Camp","Jester","Cryomancer","Hallow Punk","Harvester","Snowballer","Elementalist","Firework Technician","Biologist","Warlock","Spotlight Tech","Mecha Base"}

local selected = towers[1]

function Library:EquipTower()
    if game.PlaceId ~= 3260590327 then
        print("Только в лобби TDS!")
        return
    end
    game:GetService("ReplicatedStorage").RemoteEvent:FireServer("Towers", "Equip", selected)
    print("Экипировано: " .. selected)
    Library:Record("Equip " .. selected)
end

-- Для смены башни (можно добавить кнопку в Main)
function Library:NextTower()
    local idx = table.find(towers, selected) or 1
    idx = idx % #towers + 1
    selected = towers[idx]
    print("Выбрана башня: " .. selected)
end

return Library
