-- Vanir Zone Builder - NUI bridge (HUD overlay + export / zone-manager menu)
local RES = GetCurrentResourceName()

local function keyMap()
    local k = Config.Keys
    return {
        toggle = Config.ToggleKey,
        place = k.place.label, undo = k.undo.label, redo = k.redo.label,
        mode = k.mode.label, insert = k.insert.label, grab = k.grab.label,
        del = k.del.label, type = k.type.label, anchor = k.anchor.label,
        snap = k.snap.label, raise = k.raise.label, lower = k.lower.label,
        menu = k.menu.label, new = k.new.label, select = k.select.label,
        clean = k.clean.label,
    }
end

local function zoneList()
    local list = {}
    for i, z in ipairs(Editor.zones) do
        list[i] = { name = z.name, type = z.zoneType, count = #z.points, active = (i == Editor.idx) }
    end
    return list
end

local function menuState()
    local z = ZB_CurrentZone()
    local area, per = ZB.metrics(z)
    return {
        name = z.name, zoneType = z.zoneType, count = #z.points,
        height = z.height, anchor = z.anchor, snap = Editor.snap,
        format = Editor.format, area = area, perimeter = per,
        valid = ZB.isValid(z), zones = zoneList(),
        idx = Editor.idx, total = #Editor.zones,
    }
end

function ZB_ShowHud(show)
    SendNUIMessage({ action = 'hud', show = show, resource = RES })
    if show then ZB_UpdateHud() end
end

function ZB_UpdateHud()
    local z = ZB_CurrentZone()
    local area, per = ZB.metrics(z)
    SendNUIMessage({
        action = 'state',
        data = {
            name = z.name, zoneType = z.zoneType, count = #z.points,
            mode = Editor.mode, insert = Editor.insertMode, height = z.height,
            anchor = z.anchor, snap = Editor.snap, area = area, perimeter = per,
            zoneIdx = Editor.idx, zoneTotal = #Editor.zones, keys = keyMap(),
        },
    })
end

function ZB_OpenMenu()
    Editor.menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMenu', data = menuState() })
end

function ZB_CloseMenu()
    Editor.menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

----------------------------------------------------------------------
-- callbacks from the UI
----------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    ZB_CloseMenu()
    cb({ ok = true })
end)

RegisterNUICallback('setName', function(data, cb)
    ZB_SetName(data.name)
    cb({ name = ZB_CurrentZone().name })
end)

RegisterNUICallback('setFormat', function(data, cb)
    ZB_SetFormat(data.format)
    cb({ ok = true })
end)

RegisterNUICallback('setHeight', function(data, cb)
    ZB_SetHeight(data.height)
    cb({ height = ZB_CurrentZone().height })
end)

RegisterNUICallback('setType', function(data, cb)
    ZB_SetType(data.zoneType)
    cb(menuState())
end)

RegisterNUICallback('setAnchor', function(data, cb)
    ZB_SetAnchor(data.anchor)
    cb(menuState())
end)

RegisterNUICallback('setSnap', function(data, cb)
    ZB_SetSnap(data.snap)
    cb(menuState())
end)

RegisterNUICallback('newZone', function(_, cb)
    ZB_NewZone(nil)
    cb(menuState())
end)

RegisterNUICallback('editZone', function(data, cb)
    ZB_EditZone(tonumber(data.index))
    cb(menuState())
end)

RegisterNUICallback('deleteZone', function(data, cb)
    ZB_DeleteZone(tonumber(data.index))
    cb(menuState())
end)

RegisterNUICallback('clear', function(_, cb)
    ZB_ClearCurrent()
    cb(menuState())
end)

RegisterNUICallback('export', function(data, cb)
    if data.name then ZB_SetName(data.name) end
    if data.format then ZB_SetFormat(data.format) end
    local z = ZB_CurrentZone()
    if not ZB.isValid(z) then
        ZB_Notify(L('need_points'))
        cb({ error = 'invalid' })
        return
    end
    local code = ZB.generate(Editor.format, z)
    local jsonStr = ZB.gen.json(z)
    TriggerServerEvent('vnr_zb:save', z.name, Editor.format, code, jsonStr)
    cb({ code = code })
end)

RegisterNUICallback('exportAll', function(data, cb)
    if data.format then ZB_SetFormat(data.format) end
    local all = {}
    for _, z in ipairs(Editor.zones) do
        if ZB.isValid(z) then all[#all + 1] = z end
    end
    if #all == 0 then
        ZB_Notify(L('need_points'))
        cb({ error = 'empty' })
        return
    end
    local code = ZB.generateAll(Editor.format, all)
    TriggerServerEvent('vnr_zb:saveAll', Editor.format, code, #all)
    cb({ code = code, count = #all })
end)

RegisterNetEvent('vnr_zb:saved', function(ok, path)
    if ok then ZB_Notify(L('saved', path)) else ZB_Notify(L('save_failed')) end
end)

RegisterNetEvent('vnr_zb:savedAll', function(ok, path, count)
    if ok then ZB_Notify(L('saved_all', count, path)) else ZB_Notify(L('save_failed')) end
end)
