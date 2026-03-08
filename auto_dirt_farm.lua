--[[
    Auto Dirt Farm — Human Action + Anti-Ban
    GrowLauncher Lua API (Lua 5.4)
    v1.2 — Fix: place packet, equip item, koordinat, OnValue rename,
                doPlace beda dari doPunch, batas world 100x54
]]

-- ============================================================
-- REQUIRE & CONFIG
-- ============================================================
local pref = require("preferences")
local cfg  = pref:new("auto_dirt_farm.json")
cfg:load()

-- ============================================================
-- CONSTANTS
-- ============================================================
local DIRT_ID  = 2
-- ID 8=Lava, 10=Lava2, 674=Acid Lava
local LAVA_IDS = { [8]=true, [10]=true, [674]=true }

-- World Growtopia: 100x54 tile (index 0-99 x, 0-53 y)
-- Baris paling bawah = bedrock (y=54-59), jangan disentuh
local WORLD_MAX_X = 99
local WORLD_MAX_Y = 53

-- Range default (tile coordinate, bukan pixel)
local START_X       = cfg:get("start_x",    1)
local START_Y       = cfg:get("start_y",    3)
local END_X         = cfg:get("end_x",      98)
local END_ROW_COUNT = cfg:get("row_count",  10)

-- Delay dasar (ms)
local BASE_PUNCH_MIN = 200
local BASE_PUNCH_MAX = 350
local BASE_PLACE_MIN = 180
local BASE_PLACE_MAX = 300

-- Human behavior config
local IDLE_CHANCE            = 4
local BURST_CHANCE           = 8
local FAKE_ACTION_CHANCE     = 12
local MICRO_CORRECT_CHANCE   = 15
local SESSION_BREAK_INTERVAL = 180
local SESSION_BREAK_MIN      = 4000
local SESSION_BREAK_MAX      = 9000
local FATIGUE_RATE           = 0.0008
local MAX_FATIGUE            = 0.45

-- ============================================================
-- STATE
-- ============================================================
local State = {
    running       = false,
    totalBroken   = 0,
    totalPlanted  = 0,
    fatigue       = 0.0,
    burstLeft     = 0,
    tileCount     = 0,
    lastBreakTime = 0,
}

-- ============================================================
-- HUMAN BEHAVIOR HELPERS
-- ============================================================
local function humanDelay(min, max)
    local r = (math.random() + math.random() + math.random()) / 3
    local base = min + r * (max - min)
    return math.floor(base + base * State.fatigue)
end

local function updateFatigue()
    State.tileCount = State.tileCount + 1
    State.fatigue = math.min(MAX_FATIGUE, State.tileCount * FATIGUE_RATE)
end

local function checkSessionBreak()
    local now = os.clock()
    if (now - State.lastBreakTime) >= SESSION_BREAK_INTERVAL then
        local dur = math.random(SESSION_BREAK_MIN, SESSION_BREAK_MAX)
        log("[Human] Istirahat " .. math.floor(dur/1000) .. "s...")
        growtopia.notify("Santai sebentar...")
        CSleep(dur)
        State.lastBreakTime = os.clock()
        State.fatigue = math.max(0, State.fatigue - 0.1)
    end
end

local function maybeIdle()
    if math.random(IDLE_CHANCE) == 1 then
        CSleep(math.random(600, 4000))
    end
end

local function maybeFakeAction()
    if math.random(FAKE_ACTION_CHANCE) ~= 1 then return end
    local roll = math.random(3)
    if roll == 1 then
        sendPacket(2, "action|dialog_request\ndialog_name|backpack\n")
        CSleep(math.random(500, 1800))
        sendPacket(2, "action|dialog_cancel\n")
        CSleep(math.random(200, 400))
    elseif roll == 2 then
        local p = getLocal()
        if p then
            sendPacketRaw(false, {
                type=0, value=0,
                x=p.posX+14, y=p.posY,
                xspeed=100, yspeed=0,
                px=math.floor(p.posX/32), py=math.floor(p.posY/32)
            })
            CSleep(math.random(120, 300))
            sendPacketRaw(false, {
                type=0, value=0,
                x=p.posX, y=p.posY,
                xspeed=0, yspeed=0,
                px=math.floor(p.posX/32), py=math.floor(p.posY/32)
            })
        end
    else
        CSleep(math.random(800, 2500))
    end
end

local function isBursting()
    if State.burstLeft > 0 then
        State.burstLeft = State.burstLeft - 1
        return true
    end
    if math.random(BURST_CHANCE) == 1 then
        State.burstLeft = math.random(3, 7)
        return true
    end
    return false
end

local function maybeMicroCorrect(tx, ty)
    if math.random(MICRO_CORRECT_CHANCE) ~= 1 then return end
    local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
    local d = dirs[math.random(#dirs)]
    local wx, wy = tx + d[1], ty + d[2]
    if wx < 0 or wy < 0 or wx > WORLD_MAX_X or wy > WORLD_MAX_Y then return end
    local t = getTile(wx, wy)
    if t and t.fg ~= 0 and not LAVA_IDS[t.fg] then
        sendPacketRaw(false, {
            type=3, value=18,
            x=wx*32 + math.random(-6,6),
            y=wy*32 + math.random(-4,4),
            px=wx, py=wy
        })
        CSleep(humanDelay(80, 180))
    end
end

-- Offset punch (tidak selalu tepat tengah tile)
local function ox() return math.random(-8, 8) end
local function oy() return math.random(-6, 6) end

-- ============================================================
-- UTILITY
-- ============================================================
local function isDangerous(tx, ty)
    if tx < 0 or ty < 0 or tx > WORLD_MAX_X or ty > WORLD_MAX_Y then return true end
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
    local tx = math.floor(p.posX / 32)
    local ty = math.floor(p.posY / 32)
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
-- EQUIP ITEM — kirim packet pilih item di tangan
-- FIX: Sebelum place, harus equip dirt dulu
-- ============================================================
local function equipItem(itemId)
    sendPacket(2, "action|item_activate\nnetid|-1\nitem_id|" .. itemId .. "\n")
    CSleep(humanDelay(80, 150))
end

-- ============================================================
-- CORE: Punch (break) tile
-- type=3 = PACKET_TILE_CHANGE_REQUEST
-- value=18 = punch/fist
-- ============================================================
local function doPunch(tx, ty)
    sendPacketRaw(false, {
        type  = 3,
        value = 18,    -- fist punch
        x     = tx * 32 + ox(),
        y     = ty * 32 + oy(),
        px    = tx,
        py    = ty
    })
end

-- ============================================================
-- CORE: Place tile (beda dari punch!)
-- FIX: value = item ID yang diplace (DIRT_ID = 2)
--      Harus equip item dulu sebelum place
-- ============================================================
local function doPlace(tx, ty)
    sendPacketRaw(false, {
        type  = 3,
        value = DIRT_ID,   -- FIX: bukan 18! ini ID item yang diplace
        x     = tx * 32 + ox(),
        y     = ty * 32 + oy(),
        px    = tx,
        py    = ty
    })
end

-- ============================================================
-- CORE: Break tile sampai fg == 0
-- ============================================================
local function breakTile(tx, ty)
    local t = getTile(tx, ty)
    if not t or t.fg == 0 then return true end
    if isDangerous(tx, ty) then
        log("[Farm] Skip tile berbahaya " .. tx .. "," .. ty)
        return true
    end

    FindPath(tx, ty)
    CSleep(humanDelay(180, 400))

    local attempts = 0
    while State.running do
        t = getTile(tx, ty)
        if not t or t.fg == 0 then
            State.totalBroken = State.totalBroken + 1
            updateFatigue()
            return true
        end

        if not isPlayerSafe() then
            log("[Farm] Bahaya lava! Pause...")
            growtopia.notify("Bahaya! Pause 2s")
            CSleep(2000)
            FindPath(START_X, START_Y)
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

        if attempts >= 35 then
            log("[Farm] Skip tile " .. tx .. "," .. ty .. " (max attempts)")
            return false
        end
    end
    return false
end

-- ============================================================
-- CORE: Place dirt di tile
-- FIX: equip dirt dulu, lalu place dengan value=DIRT_ID
-- ============================================================
local function plantTile(tx, ty)
    -- Kalau ada fg, break dulu
    local t = getTile(tx, ty)
    if t and t.fg ~= 0 then
        breakTile(tx, ty)
        CSleep(humanDelay(100, 250))
    end

    if getDirtCount() <= 0 then return false end

    -- FIX: Equip dirt sebelum place!
    equipItem(DIRT_ID)

    FindPath(tx, ty)
    CSleep(humanDelay(150, 300))

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
-- PHASE: BREAK — baris GENAP (index 1,3,5,...)
-- Growtopia tile Y: 0 = atas, WORLD_MAX_Y = bawah
-- ============================================================
local function doBreakPhase()
    log("[Farm] === BREAK PHASE ===")
    log("[Farm] Area: X=" .. START_X .. "-" .. END_X .. " Y=" .. START_Y .. " +" .. END_ROW_COUNT .. " baris")
    State.lastBreakTime = os.clock()

    for row = 0, END_ROW_COUNT - 1 do
        if not State.running then return end

        if row % 2 == 1 then  -- baris genap (index 1,3,5,...)
            local ty = START_Y + row
            if ty > WORLD_MAX_Y then break end

            local goLeft = (math.floor(row / 2) % 2 == 1)
            local xStart = goLeft and END_X   or START_X
            local xEnd   = goLeft and START_X or END_X
            local xStep  = goLeft and -1       or 1

            log("[Farm] Break Y=" .. ty .. (goLeft and " <--" or " -->"))

            local tx = xStart
            while State.running do
                if xStep > 0 and tx > xEnd   then break end
                if xStep < 0 and tx < xEnd   then break end
                if tx < 0 or tx > WORLD_MAX_X then break end

                checkSessionBreak()
                maybeIdle()

                if not isDangerous(tx, ty) then
                    breakTile(tx, ty)
                end

                tx = tx + xStep
                CSleep(humanDelay(20, 60))
            end

            log("[Farm] Y=" .. ty .. " selesai | broken=" .. State.totalBroken)
            maybeFakeAction()
            CSleep(humanDelay(300, 900))
        end
    end

    log("[Farm] BREAK selesai! Total: " .. State.totalBroken)
    growtopia.notify("Break selesai! " .. State.totalBroken .. " tile")
end

-- ============================================================
-- PHASE: PLANT — baris GANJIL (index 0,2,4,...)
-- ============================================================
local function doPlantPhase()
    log("[Farm] === PLANT PHASE ===")
    log("[Farm] Dirt tersedia: " .. getDirtCount())
    State.lastBreakTime = os.clock()

    for row = 0, END_ROW_COUNT - 1 do
        if not State.running then return end

        if row % 2 == 0 then  -- baris ganjil (index 0,2,4,...)
            local ty = START_Y + row
            if ty > WORLD_MAX_Y then break end

            local goLeft = (math.floor(row / 2) % 2 == 1)
            local xStart = goLeft and END_X   or START_X
            local xEnd   = goLeft and START_X or END_X
            local xStep  = goLeft and -1       or 1

            log("[Farm] Plant Y=" .. ty .. (goLeft and " <--" or " -->"))

            local tx = xStart
            while State.running do
                if xStep > 0 and tx > xEnd    then break end
                if xStep < 0 and tx < xEnd    then break end
                if tx < 0 or tx > WORLD_MAX_X then break end

                local dirtLeft = getDirtCount()
                if dirtLeft <= 0 then
                    log("[Farm] Dirt habis!")
                    growtopia.notify("Dirt habis! Stop.")
                    State.running = false
                    return
                end
                if dirtLeft <= 10 then
                    growtopia.notify("Dirt sisa " .. dirtLeft .. "!")
                    log("[Farm] WARNING: Dirt sisa " .. dirtLeft)
                end

                checkSessionBreak()
                maybeIdle()
                plantTile(tx, ty)
                maybeFakeAction()

                tx = tx + xStep
                CSleep(humanDelay(20, 55))
            end

            log("[Farm] Y=" .. ty .. " planted | dirt=" .. getDirtCount())
            CSleep(humanDelay(300, 800))
        end
    end

    log("[Farm] PLANT selesai! Total planted: " .. State.totalPlanted)
    growtopia.notify("Plant selesai! " .. State.totalPlanted .. " dirt")
end

-- ============================================================
-- MAIN FARM LOOP
-- ============================================================
local function startFarm()
    State.totalBroken   = 0
    State.totalPlanted  = 0
    State.fatigue       = 0.0
    State.burstLeft     = 0
    State.tileCount     = 0
    State.lastBreakTime = os.clock()

    log("[Farm] =====================")
    log("[Farm] Auto Dirt Farm v1.2")
    log("[Farm] World : " .. (GetWorldName() or "N/A"))
    log("[Farm] Dirt  : " .. getDirtCount())
    log("[Farm] Area  : X" .. START_X .. "-" .. END_X ..
        " Y" .. START_Y .. " (" .. END_ROW_COUNT .. " baris)")
    log("[Farm] =====================")

    -- Jeda awal
    CSleep(humanDelay(800, 2000))

    if State.running then doBreakPhase() end
    if State.running then CSleep(humanDelay(1000, 3000)) end
    if State.running then doPlantPhase() end

    if State.running then
        log("[Farm] SEMUA SELESAI! Broken=" .. State.totalBroken .. " Planted=" .. State.totalPlanted)
        growtopia.notify("Farm selesai!")
    end

    State.running = false
    log("[Farm] Stopped.")
end

-- ============================================================
-- GUI
-- ============================================================
local ui = UserInterface.new("Auto Dirt Farm", "Grass")
ui:addLabelApp("Auto Dirt Farm", "Grass")
ui:addTooltip("Info",
    "Break baris genap, plant baris ganjil. World: 100x54 tile (0-99, 0-53).",
    "Info", false)
ui:addDivider()
ui:addToggle("Enable Farm", cfg:get("enabled", false), "enable_farm", false)
ui:addDivider()

local expCfg = ui:addExpandableToggle("Range Config", false, "cfg_exp", false, true)
ui:addChildInputInt(expCfg.list_child, "Start X",   tostring(START_X),       "X", "Tile X awal (0-99)",     "Home", "cfg_start_x")
ui:addChildInputInt(expCfg.list_child, "Start Y",   tostring(START_Y),       "Y", "Tile Y awal (0-53)",     "Home", "cfg_start_y")
ui:addChildInputInt(expCfg.list_child, "End X",     tostring(END_X),         "X", "Tile X akhir (0-99)",    "Home", "cfg_end_x")
ui:addChildInputInt(expCfg.list_child, "Row Count", tostring(END_ROW_COUNT), "N", "Jumlah baris (max 54)",  "Home", "cfg_row_count")

local expH = ui:addExpandableToggle("Human Behavior", false, "human_exp", false, true)
ui:addChildSlider(expH.list_child, "Idle Chance (1/N)",    2,   20,  IDLE_CHANCE,            1, false, "idle_chance")
ui:addChildSlider(expH.list_child, "Burst Chance (1/N)",   4,   20,  BURST_CHANCE,           1, false, "burst_chance")
ui:addChildSlider(expH.list_child, "Fake Action (1/N)",    5,   30,  FAKE_ACTION_CHANCE,     1, false, "fake_chance")
ui:addChildSlider(expH.list_child, "Session Break (detik)",60, 600, SESSION_BREAK_INTERVAL, 10, false, "session_break")

-- ============================================================
-- HOOKS
-- FIX: OnValue → OnValueFarm supaya tidak bentrok dengan gl_console
-- ============================================================
function OnValueFarm(type, name, value)
    if name == "enable_farm" then
        if value and not State.running then
            State.running = true
            cfg:set("enabled", true) cfg:save()
            log("[Farm] Dimulai!")
            runThread(startFarm)
        elseif not value then
            State.running = false
            cfg:set("enabled", false) cfg:save()
            log("[Farm] Dihentikan.")
        end
    elseif name == "cfg_start_x"   then START_X = math.max(0, math.min(WORLD_MAX_X, tonumber(value) or START_X)); cfg:set("start_x", START_X); cfg:save()
    elseif name == "cfg_start_y"   then START_Y = math.max(0, math.min(WORLD_MAX_Y, tonumber(value) or START_Y)); cfg:set("start_y", START_Y); cfg:save()
    elseif name == "cfg_end_x"     then END_X = math.max(0, math.min(WORLD_MAX_X, tonumber(value) or END_X)); cfg:set("end_x", END_X); cfg:save()
    elseif name == "cfg_row_count" then END_ROW_COUNT = math.max(1, math.min(54, tonumber(value) or END_ROW_COUNT)); cfg:set("row_count", END_ROW_COUNT); cfg:save()
    elseif name == "idle_chance"   then IDLE_CHANCE = tonumber(value) or IDLE_CHANCE
    elseif name == "burst_chance"  then BURST_CHANCE = tonumber(value) or BURST_CHANCE
    elseif name == "fake_chance"   then FAKE_ACTION_CHANCE = tonumber(value) or FAKE_ACTION_CHANCE
    elseif name == "session_break" then SESSION_BREAK_INTERVAL = tonumber(value) or SESSION_BREAK_INTERVAL
    end
end

function OnDrawFarm(d)
    removeHook("OnDrawFarm")
    runCoroutine(function()
        sleep(5000)
        addCategory("Farming", "Grass")
        addIntoModule(ui:generateJSON(), "Farming")
    end)
end

addHook(OnValueFarm, "OnValue")
addHook(OnDrawFarm,  "OnDraw")
applyHook()

log("[Auto Dirt Farm] v1.2 loaded!")
log("[Auto Dirt Farm] Dirt: " .. getDirtCount())
log("[Auto Dirt Farm] Buka modul 'Farming' di GL.")
