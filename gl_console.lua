--[[
    GL Console v1.3
    Fix: ImGui.Begin 2 return values, toggle UI
]]

local MAX_LOGS = 150
local LOG_H    = 180

local Console = {
    open       = false,
    logs       = {},
    logBuf     = "",
    copyMode   = false,
    autoScroll = true,
    filter     = { farm=true, chat=true, packet=false, system=true, warning=true },
    stats      = { gems=0, world="N/A", posX=0, posY=0, dirt=0 }
}

local C = {
    farm    = ImVec4(0.4, 1.0, 0.4, 1.0),
    chat    = ImVec4(0.4, 0.8, 1.0, 1.0),
    packet  = ImVec4(0.7, 0.7, 0.7, 1.0),
    system  = ImVec4(1.0, 1.0, 1.0, 1.0),
    warning = ImVec4(1.0, 0.8, 0.2, 1.0),
    error   = ImVec4(1.0, 0.3, 0.3, 1.0),
    stats   = ImVec4(0.9, 0.6, 1.0, 1.0),
}

-- ============================================================
-- PUBLIC LOG API
-- ============================================================
local function addLog(cat, text, col)
    if not Console.filter[cat] then return end
    local line = "[" .. string.upper(cat) .. "] " .. tostring(text)
    table.insert(Console.logs, { text=line, col=col })
    if #Console.logs > MAX_LOGS then table.remove(Console.logs, 1) end
    Console.logBuf = Console.logBuf .. line .. "\n"
    if #Console.logBuf > 20000 then Console.logBuf = Console.logBuf:sub(-15000) end
end

function LogFarm(t)    addLog("farm",    t, C.farm)    end
function LogChat(t)    addLog("chat",    t, C.chat)    end
function LogPacket(t)  addLog("packet",  t, C.packet)  end
function LogSystem(t)  addLog("system",  t, C.system)  end
function LogWarning(t) addLog("warning", t, C.warning) end
function LogError(t)
    local line = "[ERROR] " .. tostring(t)
    table.insert(Console.logs, { text=line, col=C.error })
    if #Console.logs > MAX_LOGS then table.remove(Console.logs, 1) end
    Console.logBuf = Console.logBuf .. line .. "\n"
end

-- ============================================================
-- STATS
-- ============================================================
local statTimer = 0
local function updateStats(delta)
    statTimer = statTimer + delta
    if statTimer < 1.0 then return end
    statTimer = 0
    local p = getLocal()
    if p then
        Console.stats.posX = math.floor(p.posX / 32)
        Console.stats.posY = math.floor(p.posY / 32)
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
-- FIX: ImGui.Begin() return 2 values di GL:
--      local visible, open = ImGui.Begin(...)
--      Harus cek 'visible' sebelum render konten!
-- ============================================================
function OnDrawImGui(delta)
    if not Console.open then return end

    updateStats(delta)

    -- FIX: SetNextWindowSize tanpa Cond (pakai 0 = always, 4 = once)
    ImGui.SetNextWindowSize(ImVec2(440, 340), 4)

    -- FIX: Begin() return visible, open
    -- p_open = true supaya ada tombol X di window
    local visible, p_open = ImGui.Begin("GL Console##gc", true, 0)

    -- Kalau user klik X, tutup console
    if not p_open then
        Console.open = false
        ImGui.End()
        return
    end

    -- FIX: Kalau tidak visible (window collapsed), tetap panggil End() tapi skip konten
    if not visible then
        ImGui.End()
        return
    end

    -- STATS
    ImGui.TextColored(C.stats, string.format(
        "[%s] %d,%d | Gems:%d Dirt:%d",
        Console.stats.world, Console.stats.posX, Console.stats.posY,
        Console.stats.gems, Console.stats.dirt
    ))
    ImGui.Separator()

    -- FILTER
    local _, f
    _, f = ImGui.Checkbox("Farm",   Console.filter.farm)    Console.filter.farm    = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Chat",   Console.filter.chat)    Console.filter.chat    = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Pkt",    Console.filter.packet)  Console.filter.packet  = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Sys",    Console.filter.system)  Console.filter.system  = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Warn",   Console.filter.warning) Console.filter.warning = f

    _, f = ImGui.Checkbox("Scroll", Console.autoScroll) Console.autoScroll = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Copy",   Console.copyMode)   Console.copyMode   = f  ImGui.SameLine()
    if ImGui.SmallButton("Clear") then Console.logs = {} Console.logBuf = "" end

    ImGui.Separator()

    if Console.copyMode then
        ImGui.TextColored(C.warning, "Hold teks lalu Select All -> Copy")
        ImGui.InputTextMultiline("##lb", Console.logBuf, #Console.logBuf + 1, ImVec2(-1, LOG_H), 1)
    else
        if ImGui.BeginListBox("##logs", ImVec2(-1, LOG_H)) then
            for _, e in ipairs(Console.logs) do
                ImGui.TextColored(e.col, e.text)
            end
            if Console.autoScroll then ImGui.SetScrollHereY(1.0) end
            ImGui.EndListBox()
        end
    end

    ImGui.Separator()
    ImGui.TextDisabled(string.format("%d/%d", #Console.logs, MAX_LOGS))
    ImGui.End()
end

-- ============================================================
-- EVENT HOOKS
-- ============================================================
function onVariantConsole(var, pkt)
    if not var then return end
    local v1 = tostring(var.v1 or "")
    local v2 = tostring(var.v2 or "")
    if v1 == "OnConsoleMessage" then
        LogChat(v2)
    elseif v1 == "OnAddNotification" then
        LogSystem("Notif: " .. tostring(var.v3 or v2))
    elseif v1 == "OnDialogRequest" then
        LogSystem("Dialog: " .. v2:sub(1, 40))
    elseif Console.filter.packet then
        LogPacket(v1 .. "|" .. v2)
    end
end

function onGamePacketConsole(pkt)
    if not Console.filter.packet or not pkt then return end
    LogPacket("t=" .. tostring(pkt.type) .. " v=" .. tostring(pkt.value))
end

-- ============================================================
-- UI MODULE
-- ============================================================
local pref = require("preferences")
local cfg  = pref:new("gl_console.json")
cfg:load()

local ui = UserInterface.new("GL Console", "Terminal")
ui:addLabelApp("GL Console", "Terminal")
ui:addDivider()
ui:addToggle("Show Console", cfg:get("open", false), "console_open", true)

-- FIX: OnValue handler untuk toggle
function OnValueConsole(type, name, value)
    if name == "console_open" then
        Console.open = (value == true or value == 1)
        cfg:set("open", Console.open)
        cfg:save()
        log("[Console] open=" .. tostring(Console.open))
    end
end

function OnDrawConsole(d)
    removeHook("OnDrawConsole")
    runCoroutine(function()
        sleep(4000)
        addCategory("Tools", "Terminal")
        addIntoModule(ui:generateJSON(), "Tools")
    end)
end

-- ============================================================
-- INIT
-- ============================================================
Console.open = cfg:get("open", false)
log("[Console] loaded, open=" .. tostring(Console.open))

addHook(onVariantConsole,    "onVariant")
addHook(onGamePacketConsole, "onGamePacket")
addHook(OnDrawImGui,         "OnDrawImGui")
addHook(OnValueConsole,      "OnValue")
addHook(OnDrawConsole,       "OnDraw")
applyHook()

LogSystem("GL Console v1.3 loaded!")
