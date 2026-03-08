--[[
    main.lua - Script Loader v1.2
    Simpan di ScriptLua/ di HP, tidak perlu diubah lagi.
]]

local GITHUB_USER = "botgrowtopiakalss2-bit"
local GITHUB_REPO = "Growlauncher-Script"
local BRANCH      = "main"

local SCRIPTS = {
    "gl_console.lua",
    "auto_dirt_farm.lua",
}

local BASE_URL = "https://raw.githubusercontent.com/"
    .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/"

log("[Loader] =============================")
log("[Loader] GL Script Loader v1.2")
log("[Loader] =============================")

local loaded = 0
local failed = 0

local function stripResponse(res)
    -- Kalau fetch() return HTTP headers, ambil body saja
    -- HTTP response format: "HTTP/1.x STATUS\r\n...headers...\r\n\r\nbody"
    local body = res:match("\r\n\r\n(.+)$")
    if body then return body end
    -- Coba tanpa \r
    body = res:match("\n\n(.+)$")
    if body then return body end
    -- Tidak ada header, return as-is
    return res
end

for _, scriptName in ipairs(SCRIPTS) do
    log("[Loader] Fetching: " .. scriptName .. "...")
    local res, err = fetch(BASE_URL .. scriptName)

    if not res then
        log("[Loader] GAGAL fetch " .. scriptName .. ": " .. tostring(err))
        failed = failed + 1
    else
        -- Strip HTTP headers jika ada
        res = stripResponse(res)
        -- Trim whitespace/BOM di awal
        res = res:match("^%s*(.-)%s*$") or res

        local firstByte = string.byte(res, 1)
        log("[Loader] first byte: " .. tostring(firstByte))

        local chunk, loadErr = load(res, scriptName)
        if not chunk then
            log("[Loader] ERROR compile " .. scriptName .. ": " .. tostring(loadErr))
            failed = failed + 1
        else
            local ok, runErr = pcall(chunk)
            if not ok then
                log("[Loader] ERROR run " .. scriptName .. ": " .. tostring(runErr))
                failed = failed + 1
            else
                log("[Loader] OK: " .. scriptName)
                loaded = loaded + 1
            end
        end
    end
end

log("[Loader] Load: " .. loaded .. " | Gagal: " .. failed)
