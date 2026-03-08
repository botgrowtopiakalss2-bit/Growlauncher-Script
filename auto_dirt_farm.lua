--[[
    Auto Dirt Farm — Human Action + Anti-Ban
    GrowLauncher Lua API (Lua 5.4)

    Fitur Utama:
    - Break baris GENAP (2, 4, 6, ...)
    - Plant baris GANJIL (1, 3, 5, ...)
    - Stop otomatis jika dirt habis + notifikasi
    - Lava avoidance
    - Maksimal human behavior & anti-ban

    Human Behavior System:
    - Gaussian-like random delay (tidak seragam)
    - Fatigue system (makin lama makin lambat)
    - Random idle/pause (seolah distraksi)
    - Punch offset (tidak selalu tepat tengah tile)
    - Fake actions (buka inventory, gerak kecil)
    - Speed burst (kadang tiba-tiba cepat)
    - Arah sweep alternating (kiri→kanan / kanan→kiri bergantian)
    - Micro-correction (sesekali salah tile lalu koreksi)
    - Session break (istirahat setelah beberapa menit)
]]

-- ============================================================
-- REQUIRE & PERSISTENT CONFIG
-- ============================================================
local pref = require("preferences")
local cfg  = pref:new("auto_dirt_farm.json")

-- ============================================================
-- CONSTANTS
-- ============================================================
local DIRT_ID  = 2
local LAVA_IDS = { [8]=true, [10]=true, [674]=true }

-- Range default
local START_X       = cfg:get("start_x",    1)
local START_Y       = cfg:get("start_y",    3)
local END_X         = cfg:get("end_x",      99)
local END_ROW_COUNT = cfg:get("row_count",  20)

-- Delay dasar (ms)
local BASE_PUNCH_MIN = 180
local BASE_PUNCH_MAX = 320
local BASE_PLACE_MIN = 160
local BASE_PLACE_MAX = 280

-- Human behavior config (bisa diubah via GUI)
local IDLE_CHANCE            = 4    -- 1/N chance per tile → idle
local BURST_CHANCE           = 8    -- 1/N chance → speed burst
local FAKE_ACTION_CHANCE     = 12   -- 1/N chance → fake action
local MICRO_CORRECT_CHANCE   = 15   -- 1/N chance → micro-correction
local SESSION_BREAK_INTERVAL = 180  -- detik sebelum istirahat panjang
local SESSION_BREAK_MIN      = 4000 -- ms istirahat min
local SESSION_BREAK_MAX      = 9000 -- ms istirahat max
local FATIGUE_RATE           = 0.0008  -- kenaikan delay per tile
local MAX_FATIGUE            = 0.45    -- maks 45% tambahan delay

-- ============================================================
-- STATE
-- ============================================================
local State = {
    running        = false,
    totalBroken    = 0,
    totalPlanted   = 0,
    fatigue        = 0.0,
    burstLeft      = 0,
    sessionStart   = 0,
    lastBreakTime  = 0,
    tileCount      = 0,
}

-- ============================================================
-- HUMAN BEHAVIOR HELPERS
-- ============================================================

-- Gaussian-like delay: rata-rata 3 random = distribusi natural
local function humanDelay(min, max)
    local r = (math.random() + math.random() + math.random()) / 3
    local base = min + r * (max - min)
    local fatigueBonus = base * State.fatigue
    return math.floor(base + fatigueBonus)
end

-- Update fatigue per tile
local function updateFatigue()
    State.tileCount = State.tileCount + 1
    State.fatigue = math.min(MAX_FATIGUE, State.tileCount * FATIGUE_RATE)
end

-- Session break setelah interval tertentu
local function checkSessionBreak()
    local now = os.clock()
    if (now - State.lastBreakTime) >= SESSION_BREAK_INTERVAL then
        local dur = math.random(SESSION_BREAK_MIN, SESSION_BREAK_MAX)
        log("[Human] Istirahat " .. math.floor(dur/1000) .. " detik...")
        growtopia.notify("Santai sebentar...")
        CSleep(dur)
        State.lastBreakTime = os.clock()
        State.fatigue = math.max(0, State.fatigue - 0.1)
        log("[Human] Lanjut!")
    end
end

-- Random idle seolah distraksi
local function maybeIdle()
    if math.random(IDLE_CHANCE) == 1 then
        local ms = math.random(600, 4000)
        log("[Human] Idle " .. ms .. "ms")
        CSleep(ms)
    end
end

-- Fake actions: buka inventory / gerak kecil / pause
local function maybeFakeAction()
    if math.random(FAKE_ACTION_CHANCE) ~= 1 then return end
    local roll = math.random(3)
    if roll == 1 then
        -- Buka inventory
        log("[Human] Fake: buka inventory")
        sendPacket(2, "action|dialog_request\ndialog_name|backpack\n")
        CSleep(math.random(500, 1800))
        sendPacket(2, "action|dialog_cancel\n")
        CSleep(math.random(200, 400))
    elseif roll == 2 then
        -- Gerak kecil
        log("[Human] Fake: gerak kecil")
        local p = getLocal()
        if p then
            sendPacketRaw(false, {
                type=0, value=0,
                x=p.posX+12, y=p.posY,
                xspeed=80, yspeed=0,
                px=p.posX//32, py=p.posY//32
            })
            CSleep(math.random(120, 300))
            sendPacketRaw(false, {
                type=0, value=0,
                x=p.posX, y=p.posY,
                xspeed=0, yspeed=0,
                px=p.posX//32, py=p.posY//32
            })
        end
        CSleep(math.random(100, 250))
    else
        -- Pause lihat layar
        log("[Human] Fake: pause")
        CSleep(math.random(1000, 2800))
    end
end

-- Speed burst: beberapa tile berikutnya lebih cepat
local function isBursting()
    if State.burstLeft > 0 then
        State.burstLeft = State.burstLeft - 1
        return true
    end
    if math.random(BURST_CHANCE) == 1 then
        State.burstLeft = math.random(3, 7)
        log("[Human] Speed burst " .. State.burstLeft .. " tiles")
        return true
    end
    return false
end

-- Micro-correction: sesekali punch tile sebelah lalu koreksi
local function maybeMicroCorrect(tx, ty)
    if math.random(MICRO_CORRECT_CHANCE) ~= 1 then return end
    local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
    local d = dirs[math.random(#dirs)]
    local wx, wy = tx + d[1], ty + d[2]
    if wx < 0 or wy < 0 or wx > END_X or wy > (START_Y + END_ROW_COUNT) then return end
    local t = getTile(wx, wy)
    if t and t.fg ~= 0 and not LAVA_IDS[t.fg] then
        log("[Human] Micro-correct punch " .. wx .. "," .. wy)
        sendPacketRaw(false, {
            type=3, value=18,
            x=wx*32 + math.random(-6,6),
            y=wy*32 + math.random(-4,4),
            px=wx, py=wy
        })
        CSleep(humanDelay(80, 180))
    end
end

-- Punch offset: tidak selalu tepat tengah tile
local function ox() return math.random(-8, 8) end
local function oy() return math.random(-6, 6) end

-- ============================================================
-- UTILITY
-- ============================================================
local function isDangerous(tx, ty)
    local t = getTile(tx, ty)
    if not t then return false end
    if LAVA_IDS[t.fg] or LAVA_IDS[t.bg] then return true end
    local tb = getTile(tx, ty + 1)
    if tb and (LAVA_IDS[tb.fg] or LAVA_IDS[tb.bg]) then return true end
    return false
end

local function isPlayerSafe()
    local p = getLocal()
    if not p then return false end
    local tx, ty = p.posX // 32, p.posY // 32
    for dx = -1, 1 do
        for dy = -1, 1 do
            local t = getTile(tx+dx, ty+dy)
            if t and LAVA_IDS[t.fg] then return false end
        end
    end
    return true
end

local function getDirtCount()
    for _, item in pairs(getInventory()) do
        if item.id == DIRT_ID then return item.amount end
    end
    return 0
end

-- ============================================================
-- CORE: Punch sekali dengan offset
-- ============================================================
local function doPunch(tx, ty)
    sendPacketRaw(false, {
        type=3, value=18,
        x=tx*32 + ox(), y=ty*32 + oy(),
        px=tx, py=ty
    })
end

-- ============================================================
-- CORE: Place sekali dengan offset
-- ============================================================
local function doPlace(tx, ty)
    sendPacketRaw(false, {
        type=3, value=18,
        x=tx*32 + ox(), y=ty*32 + oy(),
        px=tx, py=ty
    })
end

-- ============================================================
-- CORE: Break tile sampai fg == 0
-- ============================================================
local function breakTile(tx, ty)
    local t = getTile(tx, ty)
    if not t or t.fg == 0 then return true end
    if isDangerous(tx, ty) then
        log("[Farm] Skip berbahaya " .. tx .. "," .. ty)
        return true
    end

    FindPath(tx, ty)
    CSleep(humanDelay(200, 450))

    local attempts = 0
    while State.running do
        t = getTile(tx, ty)
        if not t or t.fg == 0 then
            State.totalBroken = State.totalBroken + 1
            updateFatigue()
            return true
        end

        if not isPlayerSafe() then
            log("[Farm] Bahaya lava! Mundur...")
            growtopia.notify("Bahaya lava! Pause...")
            CSleep(2000)
            FindPath(START_X, START_Y - 1)
            CSleep(humanDelay(500, 900))
        end

        maybeMicroCorrect(tx, ty)
        doPunch(tx, ty)
        attempts = attempts + 1

        if isBursting() then
            CSleep(humanDelay(70, 140))
        else
            CSleep(humanDelay(BASE_PUNCH_MIN, BASE_PUNCH_MAX))
        end

        maybeFakeAction()

        if attempts >= 32 then
            log("[Farm] Skip tile " .. tx .. "," .. ty .. " (tidak bisa break)")
            return false
        end
    end
    return false
end

-- ============================================================
-- CORE: Plant tile
-- ============================================================
local function plantTile(tx, ty)
    local t = getTile(tx, ty)
    if t and t.fg ~= 0 then
        breakTile(tx, ty)
        CSleep(humanDelay(100, 250))
    end

    if getDirtCount() <= 0 then return false end

    FindPath(tx, ty)
    CSleep(humanDelay(150, 320))

    doPlace(tx, ty)
    State.totalPlanted = State.totalPlanted + 1
    updateFatigue()

    if isBursting() then
        CSleep(humanDelay(70, 140))
    else
        CSleep(humanDelay(BASE_PLACE_MIN, BASE_PLACE_MAX))
    end

    return true
end

-- ============================================================
-- PHASE: BREAK — baris GENAP, arah alternating
-- ============================================================
local function doBreakPhase()
    log("[Farm] BREAK phase mulai...")
    State.lastBreakTime = os.clock()

    for row = 0, END_ROW_COUNT - 1 do
        if not State.running then return end
        if row % 2 == 1 then   -- baris GENAP (index 1,3,5,...)
            local ty = START_Y + row
            local goLeft = (math.floor(row / 2) % 2 == 1)
            local xStart = goLeft and END_X   or START_X
            local xEnd   = goLeft and START_X or END_X
            local xStep  = goLeft and -1       or 1

            log("[Farm] Break Y=" .. ty .. (goLeft and " (←)" or " (→)"))

            local tx = xStart
            while State.running and ((xStep>0 and tx<=xEnd) or (xStep<0 and tx>=xEnd)) do
                checkSessionBreak()
                maybeIdle()
                if not isDangerous(tx, ty) then
                    breakTile(tx, ty)
                end
                tx = tx + xStep
                CSleep(humanDelay(25, 70))
            end

            log("[Farm] Baris " .. ty .. " done | broken=" .. State.totalBroken)
            CSleep(humanDelay(300, 1000))
        end
    end

    log("[Farm] BREAK selesai! Total: " .. State.totalBroken)
    growtopia.notify("Break selesai! " .. State.totalBroken .. " tile.")
end

-- ============================================================
-- PHASE: PLANT — baris GANJIL, arah alternating
-- ============================================================
local function doPlantPhase()
    log("[Farm] PLANT phase mulai...")
    State.lastBreakTime = os.clock()

    for row = 0, END_ROW_COUNT - 1 do
        if not State.running then return end
        if row % 2 == 0 then   -- baris GANJIL (index 0,2,4,...)
            local ty = START_Y + row
            local goLeft = (math.floor(row / 2) % 2 == 1)
            local xStart = goLeft and END_X   or START_X
            local xEnd   = goLeft and START_X or END_X
            local xStep  = goLeft and -1       or 1

            log("[Farm] Plant Y=" .. ty .. (goLeft and " (←)" or " (→)"))

            local tx = xStart
            while State.running and ((xStep>0 and tx<=xEnd) or (xStep<0 and tx>=xEnd)) do

                -- Cek dirt
                local dirtLeft = getDirtCount()
                if dirtLeft <= 0 then
                    log("[Farm] Dirt habis!")
                    growtopia.notify("Dirt habis! Kumpulkan lagi.")
                    sendVariant({
                        v1 = "OnAddNotification",
                        v2 = "interface/large/chest_golden.rttex",
                        v3 = "Dirt habis! Kumpulkan lagi dulu.",
                        v4 = "audio/item_punch.wav"
                    })
                    State.running = false
                    return
                end

                if dirtLeft <= 10 then
                    growtopia.notify("Dirt sisa " .. dirtLeft .. "!")
                end

                checkSessionBreak()
                maybeIdle()
                plantTile(tx, ty)
                maybeFakeAction()

                tx = tx + xStep
                CSleep(humanDelay(20, 60))
            end

            log("[Farm] Baris " .. ty .. " planted | dirt=" .. getDirtCount())
            CSleep(humanDelay(300, 900))
        end
    end

    log("[Farm] PLANT selesai! Total: " .. State.totalPlanted)
    growtopia.notify("Plant selesai! " .. State.totalPlanted .. " dirt.")
    sendVariant({
        v1 = "OnAddNotification",
        v2 = "interface/large/chest_golden.rttex",
        v3 = "Plant selesai! " .. State.totalPlanted .. " dirt tertanam.",
        v4 = "audio/item_equip.wav"
    })
end

-- ============================================================
-- MAIN
-- ============================================================
local function startFarm()
    State.totalBroken   = 0
    State.totalPlanted  = 0
    State.fatigue       = 0.0
    State.burstLeft     = 0
    State.tileCount     = 0
    State.sessionStart  = os.clock()
    State.lastBreakTime = os.clock()

    log("[Farm] Auto Dirt Farm dimulai!")
    log("[Farm] World: " .. GetWorldName())
    log("[Farm] Dirt : " .. getDirtCount())

    -- Jeda awal natural
    CSleep(humanDelay(1000, 3000))

    if State.running then doBreakPhase() end

    if State.running then
        CSleep(humanDelay(1500, 4000))
    end

    if State.running then doPlantPhase() end

    if State.running then
        log("[Farm] Semua fase selesai! Broken=" .. State.totalBroken .. " Planted=" .. State.totalPlanted)
    end

    State.running = false
end

-- ============================================================
-- GUI
-- ============================================================
local ui = UserInterface.new("Auto Dirt Farm", "Grass")
ui:addLabelApp("Auto Dirt Farm", "Grass")
ui:addTooltip("Info", "Break baris genap, plant baris ganjil. Human behavior maksimal.", "Info", false)
ui:addDivider()
ui:addToggle("Enable Farm", cfg:get("enabled", false), "enable_farm", false)
ui:addDivider()

local expCfg = ui:addExpandableToggle("Range Config", false, "cfg_exp", false, true)
ui:addChildInputInt(expCfg.list_child, "Start X",   tostring(START_X),       "X", "Tile X awal",        "Home", "cfg_start_x")
ui:addChildInputInt(expCfg.list_child, "Start Y",   tostring(START_Y),       "Y", "Tile Y awal",        "Home", "cfg_start_y")
ui:addChildInputInt(expCfg.list_child, "End X",     tostring(END_X),         "X", "Tile X akhir",       "Home", "cfg_end_x")
ui:addChildInputInt(expCfg.list_child, "Row Count", tostring(END_ROW_COUNT), "N", "Jumlah baris total", "Home", "cfg_row_count")

local expH = ui:addExpandableToggle("Human Behavior", false, "human_exp", false, true)
ui:addChildSlider(expH.list_child, "Idle Chance (1/N)",   2, 20,  IDLE_CHANCE,            1, false, "idle_chance")
ui:addChildSlider(expH.list_child, "Burst Chance (1/N)",  4, 20,  BURST_CHANCE,           1, false, "burst_chance")
ui:addChildSlider(expH.list_child, "Fake Action (1/N)",   5, 30,  FAKE_ACTION_CHANCE,     1, false, "fake_chance")
ui:addChildSlider(expH.list_child, "Session Break (det)", 60, 600, SESSION_BREAK_INTERVAL, 10, false, "session_break")

-- ============================================================
-- HOOKS
-- ============================================================
function OnValue(type, name, value)
    if name == "enable_farm" then
        if value and not State.running then
            State.running = true
            cfg:set("enabled", true) cfg:save()
            runThread(startFarm)
        elseif not value then
            State.running = false
            cfg:set("enabled", false) cfg:save()
            log("[Farm] Dihentikan.")
        end
    elseif name == "cfg_start_x"   then START_X = tonumber(value) or START_X; cfg:set("start_x", START_X); cfg:save()
    elseif name == "cfg_start_y"   then START_Y = tonumber(value) or START_Y; cfg:set("start_y", START_Y); cfg:save()
    elseif name == "cfg_end_x"     then END_X = tonumber(value) or END_X; cfg:set("end_x", END_X); cfg:save()
    elseif name == "cfg_row_count" then END_ROW_COUNT = tonumber(value) or END_ROW_COUNT; cfg:set("row_count", END_ROW_COUNT); cfg:save()
    elseif name == "idle_chance"   then IDLE_CHANCE = tonumber(value) or IDLE_CHANCE
    elseif name == "burst_chance"  then BURST_CHANCE = tonumber(value) or BURST_CHANCE
    elseif name == "fake_chance"   then FAKE_ACTION_CHANCE = tonumber(value) or FAKE_ACTION_CHANCE
    elseif name == "session_break" then SESSION_BREAK_INTERVAL = tonumber(value) or SESSION_BREAK_INTERVAL
    end
end

function OnDraw(d)
    removeHook("OnDraw")
    runCoroutine(function()
        sleep(6000)
        addCategory("Farming", "Grass")
        addIntoModule(ui:generateJSON(), "Farming")
    end)
end

addHook(OnValue, "OnValue")
addHook(OnDraw, "OnDraw")
applyHook()

log("[Auto Dirt Farm] Loaded! Buka modul 'Farming' di GL.")
log("[Auto Dirt Farm] Dirt: " .. getDirtCount())
