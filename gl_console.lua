--[[
    GL Console — Real-time Overlay UI
    GrowLauncher Lua API (Lua 5.4)

    Fitur:
    - Log aktivitas farm real-time
    - Chat global & server messages
    - Stats player (gems, posisi, world, dirt)
    - Color-coded log (farm/chat/packet/system/warning/error)
    - Auto scroll ke bawah
    - Filter log per kategori
    - ✅ Copy log: tampil di InputTextMultiline readonly (bisa select & copy)
    - Toggle antara mode "Colored View" dan "Copy Mode"
]]

-- ============================================================
-- CONFIG
-- ============================================================
local MAX_LOGS  = 150
local WIN_W     = 450
local WIN_H     = 360
local LOG_H     = 200   -- tinggi area log

-- ============================================================
-- STATE
-- ============================================================
local Console = {
    open       = false,
    logs       = {},        -- { text, col } untuk colored view
    logBuf     = "",        -- plain text untuk copy mode
    copyMode   = false,     -- false = colored view, true = copy mode
    autoScroll = true,
    filter     = {
        farm    = true,
        chat    = true,
        packet  = false,
        system  = true,
        warning = true,
    },
    stats = {
        gems  = 0,
        world = "",
        posX  = 0,
        posY  = 0,
        dirt  = 0,
    }
}

-- ============================================================
-- WARNA
-- ============================================================
local COLOR = {
    farm    = ImVec4(0.4, 1.0, 0.4, 1.0),
    chat    = ImVec4(0.4, 0.8, 1.0, 1.0),
    packet  = ImVec4(0.7, 0.7, 0.7, 1.0),
    system  = ImVec4(1.0, 1.0, 1.0, 1.0),
    warning = ImVec4(1.0, 0.8, 0.2, 1.0),
    error   = ImVec4(1.0, 0.3, 0.3, 1.0),
    stats   = ImVec4(0.9, 0.6, 1.0, 1.0),
}

-- ============================================================
-- PUBLIC LOG FUNCTIONS (bisa dipanggil dari script lain)
-- ============================================================
local function addLog(category, text, col)
    if not Console.filter[category] then return end

    local line = "[" .. string.upper(category) .. "] " .. tostring(text)

    -- Colored view
    table.insert(Console.logs, { text = line, col = col })
    if #Console.logs > MAX_LOGS then
        table.remove(Console.logs, 1)
    end

    -- Plain text buffer untuk copy mode
    Console.logBuf = Console.logBuf .. line .. "\n"
    -- Batasi ukuran buffer (maks ~20KB)
    if #Console.logBuf > 20000 then
        Console.logBuf = Console.logBuf:sub(-15000)
    end
end

function LogFarm(text)
    addLog("farm", text, COLOR.farm)
end

function LogChat(text)
    addLog("chat", text, COLOR.chat)
end

function LogPacket(text)
    addLog("packet", text, COLOR.packet)
end

function LogSystem(text)
    addLog("system", text, COLOR.system)
end

function LogWarning(text)
    addLog("warning", text, COLOR.warning)
end

function LogError(text)
    -- Error selalu masuk tanpa cek filter
    local line = "[ERROR] " .. tostring(text)
    table.insert(Console.logs, { text = line, col = COLOR.error })
    if #Console.logs > MAX_LOGS then table.remove(Console.logs, 1) end
    Console.logBuf = Console.logBuf .. line .. "\n"
end

-- ============================================================
-- UPDATE STATS
-- ============================================================
local function updateStats()
    local p = getLocal()
    if p then
        Console.stats.posX = p.posX // 32
        Console.stats.posY = p.posY // 32
    end
    Console.stats.gems  = getGems() or 0
    Console.stats.world = GetWorldName() or "N/A"
    local dirt = 0
    for _, item in pairs(getInventory()) do
        if item.id == 2 then dirt = item.amount end
    end
    Console.stats.dirt = dirt
end

-- ============================================================
-- IMGUI DRAW
-- ============================================================
function OnDrawImGui(delta)
    if not Console.open then return end

    updateStats()

    ImGui.SetNextWindowSize(ImVec2(WIN_W, WIN_H), ImGui.Cond.Once)
    ImGui.Begin("GL Console")

    -- ── STATS BAR ──────────────────────────────────────────
    ImGui.TextColored(COLOR.stats,
        string.format("🌍 %s  📍 %d,%d  💎 %d  🪨 %d",
            Console.stats.world,
            Console.stats.posX,
            Console.stats.posY,
            Console.stats.gems,
            Console.stats.dirt
        )
    )
    ImGui.Separator()

    -- ── TOOLBAR ────────────────────────────────────────────
    -- Filter checkboxes
    local _, f
    _, f = ImGui.Checkbox("Farm",    Console.filter.farm)    Console.filter.farm    = f
    ImGui.SameLine()
    _, f = ImGui.Checkbox("Chat",    Console.filter.chat)    Console.filter.chat    = f
    ImGui.SameLine()
    _, f = ImGui.Checkbox("Packet",  Console.filter.packet)  Console.filter.packet  = f
    ImGui.SameLine()
    _, f = ImGui.Checkbox("System",  Console.filter.system)  Console.filter.system  = f
    ImGui.SameLine()
    _, f = ImGui.Checkbox("Warn",    Console.filter.warning) Console.filter.warning = f

    -- Baris kedua toolbar
    _, f = ImGui.Checkbox("Auto Scroll", Console.autoScroll) Console.autoScroll = f
    ImGui.SameLine()

    -- Toggle Copy Mode
    _, f = ImGui.Checkbox("Copy Mode", Console.copyMode)
    Console.copyMode = f
    ImGui.SameLine()

    -- Clear
    if ImGui.SmallButton("Clear") then
        Console.logs   = {}
        Console.logBuf = ""
    end

    ImGui.Separator()

    -- ── LOG AREA ───────────────────────────────────────────
    if Console.copyMode then
        -- MODE COPY: InputTextMultiline readonly
        -- Semua log ditampilkan sebagai plain text
        -- User bisa tap & hold → select all → copy
        ImGui.TextColored(COLOR.warning, "Copy Mode: tap & hold teks → select & copy")
        ImGui.InputTextMultiline(
            "##logbuf",
            Console.logBuf,
            #Console.logBuf + 1,
            ImVec2(-1, LOG_H),
            ImGui.InputTextFlags.ReadOnly
        )
    else
        -- MODE COLORED: ListBox dengan warna per kategori
        if ImGui.BeginListBox("##logs", ImVec2(-1, LOG_H)) then
            for _, entry in ipairs(Console.logs) do
                ImGui.TextColored(entry.col, entry.text)
            end
            if Console.autoScroll then
                ImGui.SetScrollHereY(1.0)
            end
            ImGui.EndListBox()
        end
    end

    ImGui.Separator()
    ImGui.TextDisabled(string.format("Logs: %d/%d", #Console.logs, MAX_LOGS))

    ImGui.End()
end

-- ============================================================
-- HOOKS: Tangkap event dari game
-- ============================================================
function onVariant(var, pkt)
    if not var then return end
    local v1 = tostring(var.v1 or "")
    local v2 = tostring(var.v2 or "")

    if v1 == "OnConsoleMessage" then
        LogChat(v2)
    elseif v1 == "OnAddNotification" then
        LogSystem("Notif: " .. tostring(var.v3 or v2))
    elseif v1 == "OnDialogRequest" then
        LogSystem("Dialog: " .. v2:sub(1, 50))
    elseif Console.filter.packet then
        LogPacket(v1 .. " | " .. v2)
    end
end

function onGamePacket(pkt)
    if not Console.filter.packet or not pkt then return end
    LogPacket("Pkt type=" .. tostring(pkt.type) .. " val=" .. tostring(pkt.value))
end

-- ============================================================
-- UI MODULE
-- ============================================================
local pref = require("preferences")
local cfg  = pref:new("gl_console.json")

local ui = UserInterface.new("GL Console", "Terminal")
ui:addLabelApp("GL Console", "Terminal")
ui:addTooltip("Info",
    "Real-time overlay. Copy Mode: aktifkan lalu tap & hold teks untuk copy.",
    "Info", false)
ui:addDivider()
ui:addToggle("Show Console", cfg:get("open", false), "console_open", false)

function OnValue(type, name, value)
    if name == "console_open" then
        Console.open = value
        cfg:set("open", value) cfg:save()
    end
end

function OnDraw(d)
    removeHook("OnDraw")
    runCoroutine(function()
        sleep(6000)
        addCategory("Tools", "Terminal")
        addIntoModule(ui:generateJSON(), "Tools")
    end)
end

-- ============================================================
-- INIT
-- ============================================================
Console.open = cfg:get("open", false)

addHook(onVariant,    "onVariant")
addHook(onGamePacket, "onGamePacket")
addHook(OnDrawImGui,  "OnDrawImGui")
addHook(OnValue,      "OnValue")
addHook(OnDraw,       "OnDraw")
applyHook()

LogSystem("GL Console v1.1 loaded!")
LogSystem("World: " .. (GetWorldName() or "N/A"))
LogSystem("Aktifkan Copy Mode untuk select & copy teks log.")
