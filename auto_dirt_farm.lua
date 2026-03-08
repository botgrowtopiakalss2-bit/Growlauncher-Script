-- Auto Dirt Farm v1.3
-- Break baris genap, plant baris ganjil
-- Mengikuti pola resmi GL API docs

local pref = require("preferences")
local cfg  = pref:new("auto_dirt_farm.json")
cfg:load()

-- Config
local START_X       = cfg:get("start_x",   1)
local START_Y       = cfg:get("start_y",   3)
local END_X         = cfg:get("end_x",    98)
local END_ROW_COUNT = cfg:get("row_count", 10)
local DIRT_ID       = 2
local LAVA_IDS      = { [8]=true, [10]=true, [674]=true }

-- State
local farmRunning = false
local totalBroken = 0
local totalPlanted = 0

-- Helpers
local function tileX(px) return math.floor(px / 32) end
local function tileY(py) return math.floor(py / 32) end

local function getDirtCount()
    for _, item in pairs(getInventory()) do
        if item.id == DIRT_ID then return item.amount end
    end
    return 0
end

local function isDangerous(tx, ty)
    local t = getTile(tx, ty)
    if not t then return false end
    return LAVA_IDS[t.fg] or LAVA_IDS[t.bg]
end

local function punchTile(tx, ty)
    local ox = math.random(-6, 6)
    local oy = math.random(-4, 4)
    sendPacketRaw(false, {
        type  = 3,
        value = 18,
        x     = tx * 32 + ox,
        y     = ty * 32 + oy,
        px    = tx,
        py    = ty
    })
end

local function placeTile(tx, ty)
    -- Equip dirt
    sendPacket(2, "action|item_activate\nnetid|-1\nitem_id|" .. DIRT_ID .. "\n")
    CSleep(100)
    local ox = math.random(-6, 6)
    local oy = math.random(-4, 4)
    sendPacketRaw(false, {
        type  = 3,
        value = DIRT_ID,
        x     = tx * 32 + ox,
        y     = ty * 32 + oy,
        px    = tx,
        py    = ty
    })
end

local function breakTile(tx, ty)
    local t = getTile(tx, ty)
    if not t or t.fg == 0 then return true end
    if isDangerous(tx, ty) then return true end
    FindPath(tx, ty)
    CSleep(math.random(200, 350))
    local attempts = 0
    while farmRunning do
        t = getTile(tx, ty)
        if not t or t.fg == 0 then
            totalBroken = totalBroken + 1
            return true
        end
        punchTile(tx, ty)
        CSleep(math.random(220, 380))
        attempts = attempts + 1
        if attempts >= 30 then return false end
    end
    return false
end

local function plantAt(tx, ty)
    if getDirtCount() <= 0 then return false end
    local t = getTile(tx, ty)
    if t and t.fg ~= 0 then
        breakTile(tx, ty)
        CSleep(100)
    end
    if getDirtCount() <= 0 then return false end
    placeTile(tx, ty)
    totalPlanted = totalPlanted + 1
    CSleep(math.random(200, 320))
    return true
end

local function doFarm()
    totalBroken  = 0
    totalPlanted = 0
    log("[Farm] Mulai! Dirt=" .. getDirtCount())
    CSleep(1000)

    -- BREAK phase: baris index ganjil (1,3,5...)
    log("[Farm] === BREAK ===")
    for row = 0, END_ROW_COUNT - 1 do
        if not farmRunning then break end
        if row % 2 == 1 then
            local ty = START_Y + row
            local goLeft = (math.floor(row / 2) % 2 == 1)
            local tx = goLeft and END_X or START_X
            while farmRunning do
                if goLeft and tx < START_X then break end
                if not goLeft and tx > END_X then break end
                if not isDangerous(tx, ty) then
                    breakTile(tx, ty)
                end
                CSleep(math.random(30, 80))
                tx = tx + (goLeft and -1 or 1)
            end
            log("[Farm] Break Y=" .. ty .. " done")
            CSleep(math.random(300, 700))
        end
    end

    if not farmRunning then
        log("[Farm] Dihentikan.")
        return
    end

    CSleep(math.random(1000, 2000))

    -- PLANT phase: baris index genap (0,2,4...)
    log("[Farm] === PLANT ===")
    for row = 0, END_ROW_COUNT - 1 do
        if not farmRunning then break end
        if row % 2 == 0 then
            local ty = START_Y + row
            local goLeft = (math.floor(row / 2) % 2 == 1)
            local tx = goLeft and END_X or START_X
            while farmRunning do
                if goLeft and tx < START_X then break end
                if not goLeft and tx > END_X then break end
                local dirt = getDirtCount()
                if dirt <= 0 then
                    log("[Farm] Dirt habis!")
                    growtopia.notify("Dirt habis!")
                    farmRunning = false
                    break
                end
                if dirt <= 10 then
                    growtopia.notify("Dirt sisa " .. dirt)
                end
                if not isDangerous(tx, ty) then
                    plantAt(tx, ty)
                end
                CSleep(math.random(25, 65))
                tx = tx + (goLeft and -1 or 1)
            end
            log("[Farm] Plant Y=" .. ty .. " done, dirt=" .. getDirtCount())
            CSleep(math.random(300, 600))
        end
    end

    log("[Farm] Selesai! Broken=" .. totalBroken .. " Planted=" .. totalPlanted)
    growtopia.notify("Farm selesai!")
    farmRunning = false
end

-- UI
local ui = UserInterface.new("Auto Dirt Farm", "Grass")
ui:addLabelApp("Auto Dirt Farm", "Grass")
ui:addDivider()
ui:addToggle("Enable Farm", cfg:get("enabled", false), "enable_farm", false)
ui:addDivider()

local expCfg = ui:addExpandableToggle("Range", false, "cfg_exp", false, true)
ui:addChildInputInt(expCfg.list_child, "Start X",   tostring(START_X),       "X", "X awal",  "Home", "cfg_sx")
ui:addChildInputInt(expCfg.list_child, "Start Y",   tostring(START_Y),       "Y", "Y awal",  "Home", "cfg_sy")
ui:addChildInputInt(expCfg.list_child, "End X",     tostring(END_X),         "X", "X akhir", "Home", "cfg_ex")
ui:addChildInputInt(expCfg.list_child, "Row Count", tostring(END_ROW_COUNT), "N", "Baris",   "Home", "cfg_rc")

-- OnValueFarm: global, dipanggil dari OnValue di gl_console
function OnValueFarm(type, name, value)
    if name == "enable_farm" then
        if value and not farmRunning then
            farmRunning = true
            cfg:set("enabled", true) cfg:save()
            runThread(doFarm)
        elseif not value then
            farmRunning = false
            cfg:set("enabled", false) cfg:save()
            log("[Farm] Dihentikan.")
        end
    elseif name == "cfg_sx" then START_X = tonumber(value) or START_X; cfg:set("start_x", START_X); cfg:save()
    elseif name == "cfg_sy" then START_Y = tonumber(value) or START_Y; cfg:set("start_y", START_Y); cfg:save()
    elseif name == "cfg_ex" then END_X = tonumber(value) or END_X; cfg:set("end_x", END_X); cfg:save()
    elseif name == "cfg_rc" then END_ROW_COUNT = tonumber(value) or END_ROW_COUNT; cfg:set("row_count", END_ROW_COUNT); cfg:save()
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

addHook(OnDrawFarm, "OnDraw")
applyHook()

log("[Farm] v1.3 loaded! Dirt=" .. getDirtCount())
