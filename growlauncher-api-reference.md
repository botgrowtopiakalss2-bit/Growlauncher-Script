# GrowLauncher Lua API — Complete Reference
> Growtopia | Lua 5.4 | Docs: inieyyy.github.io/Growlauncher-Documentation

---

## 📁 Script Path

| Version | Path |
|---|---|
| GL < v6.1.25 | `Android/data/launcher.powerkuy.growlauncher/ScriptLua/` |
| GL v6.1.25+ | `Android/data/launcher.powerkuy.growlauncher/files/ScriptLua/` |
| GL v7.0.0 | `Android/data/launcher.powerkuy.growlauncher/media/ScriptLua/` |
| GL v7.0.1+ | `Android/media/launcher.powerkuy.growlauncher/ScriptLua/` |

---

## 🖥️ Console Functions

```lua
log(text)                -- Log ke console (string|number|boolean)
logToConsole(text)       -- Alias dari log()
dumpTable(o)             -- Convert table → string, returns string
```

---

## 📡 Network Functions

```lua
-- Kirim text packet ke server
sendPacket(type, packet, to_client_first?)
sendPacket(2, "action|input\ntext|Hi")

-- Kirim VariantList
sendVariant(variantlist, packet_data?, netid?, value?)
sendVariant({v1 = "OnConsoleMessage", v2 = "Hello!"})

-- Notifikasi via variant:
local var = {}
var.v1 = "OnAddNotification"
var.v2 = "interface/large/adventure.rttex"
var.v3 = "Pesan notifikasi!"
var.v4 = "audio/gong.wav"
sendVariant(var)

-- Kirim raw TankPacket
sendPacketRaw(flag, packet)
local p = getLocal()
sendPacketRaw(false, {
    type  = 3,       -- PACKET_TILE_CHANGE_REQUEST
    value = 18,      -- punch flag
    x     = p.posX,
    y     = p.posY,
    px    = p.posX // 32,
    py    = p.posY // 32
})
```

---

## 👤 Player Info Functions

```lua
getGems()              -- → number
getLocal()             -- → NetAvatar
getInventory()         -- → InventoryItem[]

log(getLocal().name)
for _, item in pairs(getInventory()) do
    log(item.id .. " x" .. item.amount)
end
```

---

## 🧰 Item Info Functions

```lua
findItemID("Dirt")              -- → number
getItemInfoByID(id)             -- → ItemInfo
getItemInfoByName("Dirt")       -- → ItemInfo
```

---

## 🌍 World & Game State Functions

```lua
getTile(x, y)                   -- → Tile
getTiles()                      -- → Tile[]
FindPath(x, y, check_only?)     -- → boolean
isInside(cx, cy, rad, x, y)     -- → boolean
getNPCList()                    -- → ClientNPC[]
getPlayerList()                 -- → NetAvatar[]
getObjectList()                 -- → WorldObject[]
getWorldTileMap()               -- → WorldTileMap
getPlayerByNetID(netid)         -- → NetAvatar
GetWorldName()                  -- → string (alias: getCurrentWorldName())
```

---

## 🔧 Math & Utility Functions

```lua
split(str, regex)               -- → string[]
str:split(",")                  -- → string[] (method)
ImVec2(x, y)                    -- → Vec2
ImVec4(r, g, b, a)              -- → Vec4
getTime()                       -- → number (ms)
writeToLocal(name, content)     -- Simpan file lokal
getAppLibrary()                 -- → string
error("teks")                   -- Error warning
fetch(url)                      -- → response, error
getDiscordID()                  -- → discord ID

-- Fetch & execute remote script:
local res, err = fetch("https://raw.githubusercontent.com/.../script.lua")
if not res then log(err) return end
local chunk = load(res)
if chunk then chunk() end
```

---

## ⏱️ Threading & Coroutine

```lua
sleep(ms)                        -- Blocking sleep
CSleep(ms)                       -- Coroutine sleep (non-blocking)
randomSleep(min, max)            -- → number, random blocking
randomCSleep(min, max)           -- → number, random coroutine
await(function() return cond end, timeout?)

runThread(function() ... end)    -- Thread baru
runCoroutine(function() ... end) -- Coroutine
```

---

## 🎣 Hooks & Callbacks

### Hook Event Functions
```lua
function onVariant(var, pkt) end          -- Terima VariantList dari server
function onGamePacket(pkt) end            -- Terima TankPacket dari server
function onSendPacketRaw(pkt) end         -- Intercept packet keluar (raw)
function onSendPacket(type, pkt) end      -- Intercept packet keluar (text)
function onValue(type, name, value) end   -- UI value berubah
function OnDrawImGui(deltaTime) end       -- Tiap frame (ImGui rendering)
function OnDraw(deltaTime) end            -- Tiap frame
function onDialog(title, alias, isAccepted) end
```

### Registrasi Hook
```lua
-- Cara 1: addHook (high-level)
addHook(onVariant, "onVariant")
addHook(OnDrawImGui, "OnDrawImGui")
addHook(OnValue, "OnValue")
applyHook()       -- ← WAJIB setelah semua addHook!
removeHook("onVariant")

-- Cara 2: AddHookCallback (low-level inline)
AddHookCallback(function(var, pkt)
    log("Variant: " .. tostring(var.v1))
end, "onVariant")
RemoveHookCallback("onVariant")
CallHookCallback("onVariant", {...})
```

---

## 📦 Structs

### Vectors
```lua
Vector2: { x, y }
Vector3: { x, y, z }
Vector4: { x, y, z, w }   -- RGBA
Rect:    { x, y, w, h }
```

### Variant / VariantList
```lua
Variant:     { x?, y?, z? }
VariantList: { v1, v2, v3, v4, v5, v6, v7 }
-- v1-v7 bisa string/number/boolean/Variant
```

### InventoryItem
```lua
{ id, amount }
```

### WorldObject
```lua
{ pos, itemid, amount, invbit, id }
-- pos = Vector2 (tile units)
```

### Dialog
```lua
{ title, alias, message, confirm, ignore, url }
```

### NetAvatar
```lua
{
    pos, size,          -- Vector2
    posX, posY,         -- pixel
    posXenc, posYenc,
    sizeX, sizeY,
    sizeXenc, sizeYenc,
    punchID,            -- item di tangan
    userID, netID,
    name,               -- string
    isLeft,             -- boolean
    status,
    irisColor, pupilColor,
    onGround,           -- boolean
    country,
    equip, effect       -- NetAvatarClothes
}
```

### NetAvatarClothes
```lua
{ hair, shirt, pants, feet, hand, back, face, mask, necklace }
```

### ClientNPC
```lua
{ pos, targetpos, id, type }
```

### Tile
```lua
{
    fg, bg,          -- tile ID
    flag, collidable,
    x, y, coltype,
    extra,           -- TileExtra? (optional)
    progress,        -- break progress
    readyharvest     -- boolean
}
```

### TileExtra
```lua
{
    type, label, label2, label3,
    owner, owner_signed,
    vend_price, vend_item,
    dshelf1..4, flag, admin,
    lastupdate, lastupdate2,
    alttype, growth, volume,
    fruitcount, visible, color
}
```

### ItemInfo
```lua
{ id, type, name, breakHits, rarity, collisiontype, growTime }
```

### TankPacket
```lua
{
    netid, secnetid, type, state, value,
    x, y, xspeed, yspeed, px, py,
    padding1..5, time
}
```

### WorldTileMap
```lua
{ size }  -- size = Vector2 (biasanya 100x60)
```

---

## 🗂️ Namespaces

### growtopia.*
```lua
growtopia.enter()
growtopia.warpTo("WORLDNAME")
growtopia.notify("msg")
growtopia.isOnPos(x, y)                  -- → boolean
growtopia.sendChat("Hello", toClient?)
growtopia.enterPos()
growtopia.dropItem(itemID)
growtopia.confirmDropItem(itemID, amount)
growtopia.getItemID("Dirt")              -- → number
growtopia.getItemName(id)                -- → string
growtopia.tileChange(x, y, value)
growtopia.sendDialog("dialog_string")
growtopia.setWeather(weatherID)
growtopia.enterGateway(x, y, n)
growtopia.checkInventory(itemID)         -- → boolean
growtopia.checkInventoryCount(itemID)    -- → number
```

### tile.*
```lua
tile.getTile(x, y)           -- → Tile
tile.setFg(tileObj, itemid)  -- visual only (client-side)
tile.setBg(tileObj, itemid)  -- visual only (client-side)
```

### growlauncher.*
```lua
growlauncher.version                                   -- → number (property)
growlauncher.getVersion()                              -- → string
growlauncher.getVersionInt(growlauncher.getVersion())  -- → number
```

### preferences (require)
```lua
local pref = require("preferences")
local cfg = pref:new("config.json")
cfg:load()
cfg:save()
cfg:set("key", value)
cfg:get("key", default)   -- → any
```

### UserInterface.*
```lua
local ui = UserInterface.new("Name", "icon")

ui:addLabel("teks")
ui:addLabelApp("teks", "icon")
ui:addDivider()
ui:addTooltip("title", "support", "icon", bg?)

ui:addToggle("text", default?, "alias", autosave?)
ui:addToggleButton("text", default?, "alias")
ui:addButton("text", "alias")
ui:addSlider("text", min?, max?, default?, step?, dot?, "alias")
ui:addInputInt("text", "default", "label", "placeholder", "icon", "alias")
ui:addInputString("text", "default", "label", "placeholder", "icon", "alias")
ui:addItemPicker("text", "item", "default", "alias")
ui:addTileSelect("text", "default", "alias", count?)
ui:addDisplayList("text", "default", "alias")

-- Expandable dengan children:
local exp = ui:addExpandableToggle("text", default?, "alias", always?, bg?)
ui:addChildToggle(exp.list_child, ...)
ui:addChildSlider(exp.list_child, ...)
ui:addChildButton(exp.list_child, ...)
ui:addChildTooltip(exp.list_child, ...)
ui:addChildItemPicker(exp.list_child, ...)
ui:addChildInputInt(exp.list_child, ...)
ui:addChildInputString(exp.list_child, ...)

-- Dialog popup:
local dlg = ui:addDialog("title", "sub", {})
ui:addChildToggle(dlg.menu, ...)

ui:generateJSON()    -- → string
ui:printJSON()       -- debug
```

### UIManager.*
```lua
local mgr = UIManager.new()
mgr:generateJSON(ui)
mgr:printJSON(ui)
mgr:addSubCategory(ui, { name="Sub", icon="icon" })
```

---

## 🎨 ImGui

### Window
```lua
ImGui.Begin("Title", p_open?, flags?)   -- → boolean, boolean
ImGui.End()

-- Contoh overlay window:
function OnDrawImGui(delta)
    ImGui.Begin("My Overlay")
    ImGui.Text("Hello!")
    ImGui.End()
end
addHook(OnDrawImGui, "OnDrawImGui")
applyHook()
```

### Text Widgets
```lua
ImGui.Text("teks")
ImGui.Text("Score: %d", score)
ImGui.TextUnformatted("teks")
ImGui.TextColored(ImVec4(r,g,b,a), "teks")
ImGui.TextColored(ImVec4(1,0,0,1), "fmt %s", val)
ImGui.TextDisabled("teks abu-abu")
ImGui.TextWrapped("teks panjang")
ImGui.LabelText("Label", "Value")
ImGui.BulletText("item")
ImGui.Bullet()
```

### Main Widgets
```lua
-- Button
ImGui.Button("label", ImVec2(w,h)?)        -- → boolean
ImGui.SmallButton("label")                  -- → boolean
ImGui.InvisibleButton("id", ImVec2(w,h))   -- → boolean
ImGui.ArrowButton("id", dir)               -- → boolean

-- Checkbox
local clicked, val = ImGui.Checkbox("label", bool_val)

-- Radio
ImGui.RadioButton("label", active)          -- → boolean
local clicked, val = ImGui.RadioButtonInt("label", v, v_button)

-- Progress Bar
ImGui.ProgressBar(fraction, ImVec2(w,h)?, "overlay?")

-- Slider
local changed, val = ImGui.SliderFloat("label", v, min, max, fmt?, flags?)
local changed, val = ImGui.SliderInt("label", v, min, max, fmt?, flags?)
local changed, val = ImGui.SliderFloat2("label", {v1,v2}, min, max)
local changed, val = ImGui.VSliderFloat("label", ImVec2(w,h), v, min, max)
local changed, val = ImGui.VSliderInt("label", ImVec2(w,h), v, min, max)

-- Drag
local changed, val = ImGui.DragFloat("label", v, speed?, min?, max?)
local changed, val = ImGui.DragInt("label", v, speed?, min?, max?)
local changed, mn, mx = ImGui.DragFloatRange2("label", vmin, vmax)
local changed, mn, mx = ImGui.DragIntRange2("label", vmin, vmax)

-- List & Combo
local clicked, idx = ImGui.ListBox("label", cur_idx, {"a","b","c"})
local open = ImGui.BeginListBox("label", ImVec2(w,h)?)
ImGui.EndListBox()
local open = ImGui.BeginCombo("label", "preview", flags?)
ImGui.EndCombo()
local clicked, idx = ImGui.Combo("label", cur_idx, {"a","b","c"})

-- Tree / Collapsing
local open = ImGui.TreeNode("label", flags?)
ImGui.TreePush("id")
ImGui.TreePop()
local open = ImGui.CollapsingHeader("label", flags?)
```

### Scrolling
```lua
ImGui.GetScrollX()                    -- → number
ImGui.GetScrollY()                    -- → number
ImGui.SetScrollX(x)
ImGui.SetScrollY(y)
ImGui.GetScrollMaxX()                 -- → number
ImGui.GetScrollMaxY()                 -- → number
ImGui.SetScrollHereX(ratio?)          -- scroll ke posisi sekarang (X)
ImGui.SetScrollHereY(ratio?)          -- scroll ke posisi sekarang (Y)
ImGui.SetScrollFromPosX(local_x, ratio?)
ImGui.SetScrollFromPosY(local_y, ratio?)

-- Auto scroll ke bawah (untuk log/console):
ImGui.SetScrollHereY(1.0)
```

### Input Text Widgets
```lua
-- Single line
local changed, text = ImGui.InputText("label", buf, buf_size, flags?)

-- Multiline (untuk log/console yang bisa di-select & copy!)
local changed, text = ImGui.InputTextMultiline(
    "label", buf, buf_size,
    ImVec2(w, h)?,
    flags?
)

-- With hint
local changed, text = ImGui.InputTextWithHint("label", "hint...", buf, buf_size)

-- Number inputs
local changed, val = ImGui.InputFloat("label", v, step?, step_fast?, fmt?)
local changed, val = ImGui.InputInt("label", v, step?, step_fast?)
local changed, val = ImGui.InputDouble("label", v, step?, step_fast?, fmt?)
local changed, arr = ImGui.InputFloat2("label", {v1,v2})
local changed, arr = ImGui.InputInt2("label", {v1,v2})

-- Flag penting:
-- ImGui.InputTextFlags.ReadOnly  → tidak bisa diedit, tapi bisa di-select & copy
-- ImGui.InputTextFlags.None      → normal

-- Contoh readonly multiline log (bisa copy):
local logBuf = ""
ImGui.InputTextMultiline(
    "##log", logBuf, #logBuf + 1,
    ImVec2(-1, 200),
    ImGui.InputTextFlags.ReadOnly
)
```

### Contoh Real-time Log Window
```lua
local logs = {}

local function addLog(msg)
    table.insert(logs, msg)
    if #logs > 100 then table.remove(logs, 1) end
end

function OnDrawImGui(delta)
    ImGui.Begin("Console")
    for _, line in ipairs(logs) do
        ImGui.TextWrapped(line)
    end
    ImGui.SetScrollHereY(1.0)  -- auto scroll ke bawah
    ImGui.End()
end

function onVariant(var, pkt)
    if var.v1 == "OnConsoleMessage" then
        addLog("[Chat] " .. tostring(var.v2))
    end
end

addHook(OnDrawImGui, "OnDrawImGui")
addHook(onVariant, "onVariant")
applyHook()
```

---

## 🔢 Enums

### Menu Types
| MenuType | Num |
|---|---|
| Toggle | 0 |
| Slider | 1 |
| Item_Picker | 2 |
| Json_Data | 3 |
| Module | 4 |
| String | 5 |
| Select Tile | 6 |
| Display List | 7 |

### Packet Types
| Packet Type | Value |
|---|---|
| PACKET_STATE | 0 |
| PACKET_CALL_FUNCTION | 1 |
| PACKET_UPDATE_STATUS | 2 |
| PACKET_TILE_CHANGE_REQUEST | 3 |
| PACKET_SEND_MAP_DATA | 4 |
| PACKET_SEND_TILE_UPDATE_DATA | 5 |
| PACKET_SEND_TILE_UPDATE_DATA_MULTIPLE | 6 |
| PACKET_TILE_ACTIVATE_REQUEST | 7 |
| PACKET_TILE_APPLY_DAMAGE | 8 |
| PACKET_SEND_INVENTORY_STATE | 9 |
| PACKET_ITEM_ACTIVATE_REQUEST | 10 |
| PACKET_ITEM_ACTIVATE_OBJECT_REQUEST | 11 |
| PACKET_SEND_TILE_TREE_STATE | 12 |
| PACKET_MODIFY_ITEM_INVENTORY | 13 |
| PACKET_ITEM_CHANGE_OBJECT | 14 |
| PACKET_SEND_LOCK | 15 |
| PACKET_SEND_ITEM_DATABASE_DATA | 16 |
| PACKET_SEND_PARTICLE_EFFECT | 17 |
| PACKET_SET_ICON_STATE | 18 |
| PACKET_ITEM_EFFECT | 19 |
| PACKET_SET_CHARACTER_STATE | 20 |
| PACKET_PING_REPLY | 21 |
| PACKET_PING_REQUEST | 22 |
| PACKET_GOT_PUNCHED | 23 |
| PACKET_APP_CHECK_RESPONSE | 24 |
| PACKET_APP_INTEGRITY_FAIL | 25 |
| PACKET_DISCONNECT | 26 |
| PACKET_BATTLE_JOIN | 27 |
| PACKET_BATTLE_EVEN | 28 |
| PACKET_USE_DOOR | 29 |
| PACKET_SEND_PARENTAL | 30 |
| PACKET_GONE_FISHIN | 31 |
| PACKET_STEAM | 32 |
| PACKET_PET_BATTLE | 33 |
| PACKET_NPC | 34 |
| PACKET_SPECIAL | 35 |
| PACKET_SEND_PARTICLE_EFFECT_V2 | 36 |
| GAME_ACTIVE_ARROW_TO_ITEM | 37 |
| GAME_SELECT_TILE_INDEX | 38 |

---

## ⚠️ Common Mistakes

| ❌ Salah | ✅ Benar |
|---|---|
| `getLocalPlayer()` | `getLocal()` |
| `GetGems()` | `getGems()` |
| `LogToConsole()` | `log()` atau `logToConsole()` |
| `FindItemID()` | `findItemID()` |
| `growtopia.sendTankPacket(pkt)` | `sendPacketRaw(false, {...})` |
| `growtopia.getWorldObjects()` | `getObjectList()` |
| `Tile.getTile(x,y)` | `getTile(x,y)` atau `tile.getTile(x,y)` |
| `coroutine.create(fn) + resume` | `runThread(fn)` / `runCoroutine(fn)` |
| `addHook("onVariant", fn)` | `addHook(onVariant, "onVariant")` |
| Lupa `applyHook()` | Selalu panggil setelah semua `addHook`! |
| `growtopia.warpTo` via sendPacket | `growtopia.warpTo("WORLD")` |

---

## 📜 Pola Dasar Script GL

```lua
local pref = require("preferences")
local cfg = pref:new("myscript.json")

-- State
local enabled = cfg:get("enabled", false)

-- Hooks
function onVariant(var, pkt)
    if var.v1 == "OnConsoleMessage" then
        -- handle
    end
end

function OnDrawImGui(delta)
    if enabled then
        ImGui.Begin("My Script")
        ImGui.Text("Running!")
        ImGui.End()
    end
end

function OnValue(type, name, value)
    if name == "enable_myscript" then
        enabled = value
        cfg:set("enabled", value)
        cfg:save()
    end
end

-- UI
local ui = UserInterface.new("My Script", "Home")
ui:addLabelApp("My Script", "Home")
ui:addToggle("Enable", cfg:get("enabled", false), "enable_myscript", false)

-- Register
function OnDraw(d)
    removeHook("OnDraw")
    runCoroutine(function()
        sleep(6000)
        addCategory("My Category", "Home")
        addIntoModule(ui:generateJSON(), "My Category")
    end)
end

addHook(onVariant, "onVariant")
addHook(OnDrawImGui, "OnDrawImGui")
addHook(OnValue, "OnValue")
addHook(OnDraw, "OnDraw")
applyHook()
```
