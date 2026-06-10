-- Vanir Zone Builder - server: persist exported zones to disk
local RES = GetCurrentResourceName()

-- Optional access control. Grant in server.cfg with:
--   add_ace group.admin vnr_zonebuilder.save allow
-- and set Config.RequireAce = true (see config.lua note below).
local REQUIRE_ACE = Config.RequireAce == true
local SAVE_ACE    = Config.SaveAce or 'vnr_zonebuilder.save'
local MAX_BYTES   = 256 * 1024

local function cleanName(name)
    name = tostring(name or ''):gsub('[^%w_%-]', '')
    if name == '' then name = 'my_zone' end
    return name
end

-- Per-player write cooldown: these events are client-triggered, so rate-limit
-- them to stop a malicious client from flood-writing files into output/.
local lastSave = {}
local COOLDOWN = 2 -- seconds

local function onCooldown(src, op)
    lastSave[src] = lastSave[src] or {}
    local now = os.time()
    if lastSave[src][op] and (now - lastSave[src][op]) < COOLDOWN then return true end
    lastSave[src][op] = now
    return false
end

AddEventHandler('playerDropped', function()
    lastSave[source] = nil
end)

RegisterNetEvent('vnr_zb:save', function(name, format, code, jsonStr)
    local src = source

    if onCooldown(src, 'single') then
        TriggerClientEvent('vnr_zb:saved', src, false)
        return
    end
    if REQUIRE_ACE and not IsPlayerAceAllowed(src, SAVE_ACE) then
        print(('[vnr_zonebuilder] %s denied (missing ace %s)'):format(GetPlayerName(src) or src, SAVE_ACE))
        TriggerClientEvent('vnr_zb:saved', src, false)
        return
    end

    if type(code) ~= 'string' or #code == 0 or #code > MAX_BYTES then
        TriggerClientEvent('vnr_zb:saved', src, false)
        return
    end

    name   = cleanName(name)
    format = cleanName(format)
    local dir      = Config.OutputDir or 'output'
    local luaPath  = ('%s/%s_%s.lua'):format(dir, name, format)
    local jsonPath = ('%s/%s.json'):format(dir, name)

    local okLua = SaveResourceFile(RES, luaPath, code, -1)
    if type(jsonStr) == 'string' and #jsonStr <= MAX_BYTES then
        SaveResourceFile(RES, jsonPath, jsonStr, -1)
    end

    if okLua then
        print(('[vnr_zonebuilder] %s exported %s'):format(GetPlayerName(src) or src, luaPath))
        TriggerClientEvent('vnr_zb:saved', src, true, ('%s/%s'):format(RES, luaPath))
    else
        print('[vnr_zonebuilder] SaveResourceFile failed for ' .. luaPath)
        TriggerClientEvent('vnr_zb:saved', src, false)
    end
end)

RegisterNetEvent('vnr_zb:saveAll', function(format, code, count)
    local src = source

    if onCooldown(src, 'all') then
        TriggerClientEvent('vnr_zb:savedAll', src, false)
        return
    end
    if REQUIRE_ACE and not IsPlayerAceAllowed(src, SAVE_ACE) then
        TriggerClientEvent('vnr_zb:savedAll', src, false)
        return
    end
    if type(code) ~= 'string' or #code == 0 or #code > MAX_BYTES then
        TriggerClientEvent('vnr_zb:savedAll', src, false)
        return
    end

    format = cleanName(format)
    local path = ('%s/all_zones_%s.lua'):format(Config.OutputDir or 'output', format)
    local ok = SaveResourceFile(RES, path, code, -1)
    if ok then
        -- log bytes (server-trusted), not the client-supplied count
        print(('[vnr_zonebuilder] %s exported all_zones (%d bytes) -> %s'):format(GetPlayerName(src) or src, #code, path))
        TriggerClientEvent('vnr_zb:savedAll', src, true, ('%s/%s'):format(RES, path), tonumber(count) or 0)
    else
        TriggerClientEvent('vnr_zb:savedAll', src, false)
    end
end)
