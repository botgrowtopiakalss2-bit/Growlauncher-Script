--[[
    main.lua - Script Loader Utama
    Simpan file ini di HP: ScriptLua/main.lua
]]

local GITHUB_USER = "botgrowtopiakalss2-bit"
local GITHUB_REPO = "Growlauncher-Script"
local BRANCH      = "main"

local SCRIPTS = {
    "gl_console.lua",
    "auto_dirt_farm.lua",
}

local BASE_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/",
    GITHUB_USER, GITHUB_REPO, BRANCH
)

log("[Loader] =============================")
log("[Loader] GL Script Loader v1.1")
log("[Loader] Repo: " .. GITHUB_USER .. "/" .. GITHUB_REPO)
log("[Loader] =============================")

local loaded = 0
local failed = 0

for _, scriptName in ipairs(SCRIPTS) do
    local url = BASE_URL .. scriptName
    log("[Loader] Fetching: " .. scriptName .. "...")

    local res, err = fetch(url)

    if not res then
        log("[Loader] Gagal fetch " .. scriptName .. ": " .. tostring(err))
        failed = failed + 1
    else
        -- FIX: Strip BOM (EF BB BF) dan karakter invisible di awal
        -- GitHub CDN kadang tambahkan byte-order mark
        res = res:gsub("^%s+", "")           -- trim whitespace awal
        res = res:gsub("^\239\187\191", "") -- strip UTF-8 BOM jika ada
        -- Strip karakter non-printable di awal (< ASCII 32, kecuali newline/tab)
        res = res:match("^[%c]*(.+)$") or res
        -- Pastikan mulai dari karakter valid
        local firstChar = res:sub(1, 1)
        if firstChar ~= "-" and firstChar ~= "l" and firstChar ~= "f" then
            log("[Loader] Warning: unexpected first char in " .. scriptName .. ": " .. string.byte(firstChar))
        end

        local chunk, loadErr = load(res)
        if not chunk then
            log("[Loader] Error compile " .. scriptName .. ": " .. tostring(loadErr))
            failed = failed + 1
        else
            local ok, runErr = pcall(chunk)
            if not ok then
                log("[Loader] Error run " .. scriptName .. ": " .. tostring(runErr))
                failed = failed + 1
            else
                log("[Loader] OK: " .. scriptName)
                loaded = loaded + 1
            end
        end
    end
end

log("[Loader] =============================")
log("[Loader] Selesai! Load: " .. loaded .. " | Gagal: " .. failed)
log("[Loader] =============================")
