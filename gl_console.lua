-- GL Console v1.7
-- Mengikuti pola resmi GL API docs secara ketat

local MAX_LOGS = 100
local LOG_H    = 160

-- State
local consoleOpen = false
local autoScroll  = true
local copyMode    = false
local logs        = {}
local logBuf      = ""
local filterFarm  = true
local filterChat  = true
local filterSys   = true

local C_farm    = ImVec4(0.4, 1.0, 0.4, 1.0)
local C_chat    = ImVec4(0.4, 0.8, 1.0, 1.0)
local C_sys     = ImVec4(1.0, 1.0, 1.0, 1.0)
local C_warn    = ImVec4(1.0, 0.8, 0.2, 1.0)
local C_err     = ImVec4(1.0, 0.3, 0.3, 1.0)
local C_stats   = ImVec4(0.9, 0.6, 1.0, 1.0)

local statsWorld = "N/A"
local statsX     = 0
local statsY     = 0
local statsGems  = 0
local statsDirt  = 0
local statsTick  = 0

-- PUBLIC: dipanggil dari script lain
function LogFarm(t)
    if not filterFarm then return end
    local line = "[FARM] " .. tostring(t)
    table.insert(logs, { text=line, col=C_farm })
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    logBuf = logBuf .. line .. "\n"
end

function LogChat(t)
    if not filterChat then return end
    local line = "[CHAT] " .. tostring(t)
    table.insert(logs, { text=line, col=C_chat })
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    logBuf = logBuf .. line .. "\n"
end

function LogSystem(t)
    if not filterSys then return end
    local line = "[SYS] " .. tostring(t)
    table.insert(logs, { text=line, col=C_sys })
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    logBuf = logBuf .. line .. "\n"
end

function LogWarning(t)
    local line = "[WARN] " .. tostring(t)
    table.insert(logs, { text=line, col=C_warn })
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    logBuf = logBuf .. line .. "\n"
end

function LogError(t)
    local line = "[ERR] " .. tostring(t)
    table.insert(logs, { text=line, col=C_err })
    if #logs > MAX_LOGS then table.remove(logs, 1) end
    logBuf = logBuf .. line .. "\n"
end

-- HOOKS - sesuai pola dari docs
function onVariant(var, pkt)
    if not var then return end
    local v1 = tostring(var.v1 or "")
    local v2 = tostring(var.v2 or "")
    if v1 == "OnConsoleMessage" then
        LogChat(v2)
    elseif v1 == "OnAddNotification" then
        LogSystem("Notif: " .. tostring(var.v3 or v2))
    end
end

function OnDrawImGui(delta)
    -- Update stats tiap ~60 frame
    statsTick = statsTick + 1
    if statsTick >= 60 then
        statsTick = 0
        local p = getLocal()
        if p then
            statsX = math.floor(p.posX / 32)
            statsY = math.floor(p.posY / 32)
        end
        statsGems  = getGems() or 0
        statsWorld = GetWorldName() or "N/A"
        local dirt = 0
        for _, item in pairs(getInventory()) do
            if item.id == 2 then dirt = item.amount end
        end
        statsDirt = dirt
    end

    if not consoleOpen then return end

    ImGui.Begin("GL Console")

    ImGui.TextColored(C_stats, string.format(
        "[%s] %d,%d Gems:%d Dirt:%d",
        statsWorld, statsX, statsY, statsGems, statsDirt
    ))
    ImGui.Separator()

    local _, f
    _, f = ImGui.Checkbox("Farm", filterFarm) filterFarm = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Chat", filterChat) filterChat = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Sys",  filterSys)  filterSys  = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Scroll", autoScroll) autoScroll = f  ImGui.SameLine()
    _, f = ImGui.Checkbox("Copy", copyMode)   copyMode   = f  ImGui.SameLine()
    if ImGui.SmallButton("X") then logs = {} logBuf = "" end

    ImGui.Separator()

    if copyMode then
        ImGui.InputTextMultiline("##lb", logBuf, #logBuf + 1,
            ImVec2(-1, LOG_H), ImGui.InputTextFlags.ReadOnly)
    else
        if ImGui.BeginListBox("##logs", ImVec2(-1, LOG_H)) then
            for _, e in ipairs(logs) do
                ImGui.TextColored(e.col, e.text)
            end
            if autoScroll then ImGui.SetScrollHereY(1.0) end
            ImGui.EndListBox()
        end
    end

    ImGui.Separator()
    ImGui.TextDisabled(string.format("%d/%d", #logs, MAX_LOGS))
    ImGui.End()
end

-- OnValue - sesuai docs, dipanggil hanya saat value berubah
function OnValue(type, name, value)
    if name == "console_open" then
        consoleOpen = value
        -- simpan ke prefs
        local pref = require("preferences")
        local cfg  = pref:new("gl_console.json")
        cfg:load()
        cfg:set("open", value)
        cfg:save()
    end
    -- Forward ke farm jika ada
    if OnValueFarm then
        OnValueFarm(type, name, value)
    end
end

function OnDraw(d)
    removeHook("OnDraw")
    runCoroutine(function()
        sleep(6000)
        addCategory("Tools", "Terminal")
        local ui = UserInterface.new("GL Console", "Terminal")
        ui:addLabelApp("GL Console", "Terminal")
        ui:addDivider()
        -- Load saved state
        local pref = require("preferences")
        local cfg  = pref:new("gl_console.json")
        cfg:load()
        consoleOpen = cfg:get("open", false)
        ui:addToggle("Show Console", consoleOpen, "console_open", false)
        addIntoModule(ui:generateJSON(), "Tools")
    end)
end

-- Register sesuai pola docs
addHook(onVariant,    "onVariant")
addHook(OnDrawImGui,  "OnDrawImGui")
addHook(OnValue,      "OnValue")
addHook(OnDraw,       "OnDraw")
applyHook()

LogSystem("GL Console v1.7 loaded!")
