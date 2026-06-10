-- Vanir Zone Builder - editor state, input and main loop (multi-zone)
local function defaultZone(t)
    return {
        name = 'zone_1', zoneType = t or Config.DefaultType, points = {},
        height = Config.DefaultHeight, anchor = Config.DefaultAnchor,
    }
end

Editor = {
    active = false,
    menuOpen = false,
    mode = Config.DefaultMode,
    snap = false,
    cleanView = false,
    format = Config.DefaultFormat,
    previewCoord = nil,
    insertMode = false,
    insertEdge = nil,
    grabbedIndex = nil,
    zones = {},   -- all zones; the active one is editable, ALL are rendered
    idx = 1,      -- active zone index
    seq = 1,      -- name counter
    undoStack = {},
    redoStack = {},
}
Editor.zones[1] = defaultZone()

local function cur() return Editor.zones[Editor.idx] end

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end
ZB_Notify = notify

local function refresh()
    if ZB_UpdateHud then ZB_UpdateHud() end
end

local function RotationToDirection(rot)
    local zr = math.rad(rot.z)
    local xr = math.rad(rot.x)
    local num = math.abs(math.cos(xr))
    return vector3(-math.sin(zr) * num, math.cos(zr) * num, math.sin(xr))
end

local function getFeetCoord()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    return vector3(ZB.round(c.x, 3), ZB.round(c.y, 3), ZB.round(found and gz or c.z, 3))
end

local function getAimCoord()
    local cam = GetGameplayCamCoord()
    local dir = RotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * Config.AimDistance
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16 + 256, PlayerPedId(), 7)
    local _, hit, coords = GetShapeTestResult(handle)
    if hit then
        return vector3(ZB.round(coords.x, 3), ZB.round(coords.y, 3), ZB.round(coords.z, 3))
    end
    return nil
end

local function snapCoord(c)
    if not c or not Editor.snap then return c end
    local g = Config.GridSize
    return vector3(math.floor(c.x / g + 0.5) * g, math.floor(c.y / g + 0.5) * g, c.z)
end

local function distSqToSeg(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = 0.0
    if len2 > 0 then
        t = ((px - ax) * dx + (py - ay) * dy) / len2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cx, cy = ax + t * dx, ay + t * dy
    local ex, ey = px - cx, py - cy
    return ex * ex + ey * ey
end

local function nearestEdge(points, coord)
    local n = #points
    if n < 2 then return nil end
    local best, bestD = 1, math.huge
    for i = 1, n do
        local a = points[i]
        local b = points[(i % n) + 1]
        local d = distSqToSeg(coord.x, coord.y, a.x, a.y, b.x, b.y)
        if d < bestD then bestD = d; best = i end
    end
    return best
end

local function nearestVertex(points, coord)
    local best, bestD = nil, math.huge
    for i = 1, #points do
        local p = points[i]
        local dx, dy = p.x - coord.x, p.y - coord.y
        local d = dx * dx + dy * dy
        if d < bestD then bestD = d; best = i end
    end
    return best
end

----------------------------------------------------------------------
-- global undo/redo: snapshot the WHOLE zone list (+ active index)
----------------------------------------------------------------------
local function copyZone(z)
    local pts = {}
    for i, p in ipairs(z.points) do pts[i] = p end
    return { name = z.name, zoneType = z.zoneType, points = pts, height = z.height, anchor = z.anchor }
end

local function snapshot()
    local zs = {}
    for i, z in ipairs(Editor.zones) do zs[i] = copyZone(z) end
    return { zones = zs, idx = Editor.idx, seq = Editor.seq }
end

local function pushHistory()
    Editor.redoStack = {}
    Editor.undoStack[#Editor.undoStack + 1] = snapshot()
    if #Editor.undoStack > 80 then table.remove(Editor.undoStack, 1) end
end

local function restore(snap)
    local zs = {}
    for i, z in ipairs(snap.zones) do zs[i] = copyZone(z) end
    Editor.zones = zs
    Editor.idx = math.max(1, math.min(snap.idx, #zs))
    Editor.seq = snap.seq or Editor.seq
    Editor.grabbedIndex = nil
end

-- active zone, in the shape util.lua expects (zoneType/points/height/anchor/name)
function ZB_CurrentZone() return cur() end

----------------------------------------------------------------------
-- activation
----------------------------------------------------------------------
local function setActive(state)
    Editor.active = state
    if state then
        Editor.cleanView = false -- always start with the HUD visible
        if ZB_ShowHud then ZB_ShowHud(true) end
        refresh()
        notify(L('editor_on', Config.Keys.place.label, Config.Keys.menu.label))
    else
        Editor.menuOpen = false
        Editor.grabbedIndex = nil
        SetNuiFocus(false, false)
        if ZB_ShowHud then ZB_ShowHud(false) end
        notify(L('editor_off'))
    end
end

RegisterCommand(Config.ToggleCommand, function()
    setActive(not Editor.active)
end, false)
RegisterKeyMapping(Config.ToggleCommand, 'Toggle Vanir Zone Builder', 'keyboard', Config.ToggleKey)

-- one-time hint in the client console so players know the open key
CreateThread(function()
    Wait(1500)
    print(('[vnr_zonebuilder] Press %s to open the zone builder (rebindable in Settings > Key Bindings > FiveM).'):format(Config.ToggleKey))
end)

----------------------------------------------------------------------
-- new zone / type switching
----------------------------------------------------------------------
local function nextName()
    Editor.seq = Editor.seq + 1
    return 'zone_' .. Editor.seq
end

-- commit the current zone (it stays in the list, rendered) and start a fresh one
local function newZone(zoneType)
    local prev = cur()
    pushHistory()
    Editor.zones[#Editor.zones + 1] = {
        name = nextName(), zoneType = zoneType or prev.zoneType,
        points = {}, height = prev.height, anchor = prev.anchor,
    }
    Editor.idx = #Editor.zones
    Editor.grabbedIndex = nil
    notify(L('new_zone', #Editor.zones))
    refresh()
end
ZB_NewZone = newZone

local function setType(zoneType)
    local z = cur()
    if z.zoneType == zoneType then return end
    if #z.points == 0 then
        pushHistory()
        z.zoneType = zoneType
        notify(L('type_set', zoneType))
        refresh()
    else
        newZone(zoneType) -- non-empty: keep it and begin a new zone of the new type
    end
end

local TYPES = { 'poly', 'circle', 'box' }
local function doCycleType()
    local z = cur()
    local i = 1
    for k, t in ipairs(TYPES) do if t == z.zoneType then i = k end end
    setType(TYPES[(i % #TYPES) + 1])
end

----------------------------------------------------------------------
-- in-editor actions (all act on the ACTIVE zone)
----------------------------------------------------------------------
local function doPlace()
    if Editor.grabbedIndex then
        Editor.grabbedIndex = nil
        notify(L('point_dropped'))
        refresh()
        return
    end
    local c = snapCoord(Editor.previewCoord)
    if not c then return end
    local z = cur()
    pushHistory()
    if z.zoneType == 'poly' then
        if Editor.insertMode and #z.points >= 2 then
            local edge = nearestEdge(z.points, c) or #z.points
            table.insert(z.points, edge + 1, c)
        else
            z.points[#z.points + 1] = c
        end
    else -- circle / box: at most 2 control points
        if #z.points < 2 then
            z.points[#z.points + 1] = c
        else
            z.points[2] = c
        end
    end
    notify(L('point_added', #z.points))
    refresh()
end

local function doUndo()
    if #Editor.undoStack == 0 then notify(L('nothing_undo')) return end
    Editor.redoStack[#Editor.redoStack + 1] = snapshot()
    restore(table.remove(Editor.undoStack))
    notify(L('undone'))
    refresh()
end

local function doRedo()
    if #Editor.redoStack == 0 then notify(L('nothing_redo')) return end
    Editor.undoStack[#Editor.undoStack + 1] = snapshot()
    restore(table.remove(Editor.redoStack))
    notify(L('redone'))
    refresh()
end

local function doDelete()
    local z = cur()
    if z.zoneType ~= 'poly' then notify(L('del_poly_only')) return end
    if #z.points == 0 then notify(L('del_none')) return end
    pushHistory()
    local c = Editor.previewCoord
    local idx = (c and nearestVertex(z.points, c)) or #z.points
    table.remove(z.points, idx)
    Editor.grabbedIndex = nil
    notify(L('point_deleted', #z.points))
    refresh()
end

local function doGrab()
    local z = cur()
    if Editor.grabbedIndex then
        Editor.grabbedIndex = nil
        notify(L('point_dropped'))
    elseif #z.points == 0 then
        notify(L('nothing_grab'))
    else
        pushHistory()
        local c = Editor.previewCoord
        Editor.grabbedIndex = (c and nearestVertex(z.points, c)) or #z.points
        notify(L('point_grabbed', Editor.grabbedIndex, Config.Keys.grab.label))
    end
    refresh()
end

local function doToggleMode()
    Editor.mode = (Editor.mode == 'feet') and 'aim' or 'feet'
    notify(Editor.mode == 'feet' and L('mode_feet') or L('mode_aim'))
    refresh()
end

local function doToggleInsert()
    Editor.insertMode = not Editor.insertMode
    notify(Editor.insertMode and L('insert_on') or L('insert_off'))
    refresh()
end

local function doToggleAnchor()
    local z = cur()
    z.anchor = (z.anchor == 'center') and 'ground' or 'center'
    notify(L('anchor_set', z.anchor))
    refresh()
end

local function doToggleSnap()
    Editor.snap = not Editor.snap
    notify(Editor.snap and L('snap_on', Config.GridSize) or L('snap_off'))
    refresh()
end

local function doRaise()
    local z = cur()
    z.height = math.min(Config.MaxHeight, z.height + Config.HeightStep)
    notify(L('height_set', z.height))
    refresh()
end

local function doLower()
    local z = cur()
    z.height = math.max(Config.MinHeight, z.height - Config.HeightStep)
    notify(L('height_set', z.height))
    refresh()
end

local function doNewZone()
    newZone(nil) -- finish the current zone (stays visible), start a fresh one of the same type
end

local function doSelectNearest()
    local c = Editor.previewCoord
    if not c then return end
    local bestZone, bestD = nil, math.huge
    for zi, z in ipairs(Editor.zones) do
        for _, p in ipairs(z.points) do
            local dx, dy = p.x - c.x, p.y - c.y
            local d = dx * dx + dy * dy
            if d < bestD then bestD = d; bestZone = zi end
        end
    end
    if bestZone then
        Editor.idx = bestZone
        Editor.grabbedIndex = nil
        notify(L('selected_zone', bestZone))
        refresh()
    else
        notify(L('no_zone_near'))
    end
end

local function doToggleClean()
    Editor.cleanView = not Editor.cleanView
    notify(Editor.cleanView and L('clean_on', Config.Keys.clean.label) or L('clean_off'))
end

----------------------------------------------------------------------
-- key bindings (button-style FiveM key mappings; only act while editing)
----------------------------------------------------------------------
local function bindAction(def, onPress)
    RegisterCommand('+' .. def.cmd, function()
        if Editor.active and not Editor.menuOpen then onPress() end
    end, false)
    RegisterCommand('-' .. def.cmd, function() end, false)
    RegisterKeyMapping('+' .. def.cmd, 'Zone Builder (' .. def.label .. ')', 'keyboard', def.default)
end

bindAction(Config.Keys.place,  doPlace)
bindAction(Config.Keys.undo,   doUndo)
bindAction(Config.Keys.redo,   doRedo)
bindAction(Config.Keys.mode,   doToggleMode)
bindAction(Config.Keys.insert, doToggleInsert)
bindAction(Config.Keys.grab,   doGrab)
bindAction(Config.Keys.del,    doDelete)
bindAction(Config.Keys.type,   doCycleType)
bindAction(Config.Keys.anchor, doToggleAnchor)
bindAction(Config.Keys.snap,   doToggleSnap)
bindAction(Config.Keys.raise,  doRaise)
bindAction(Config.Keys.lower,  doLower)
bindAction(Config.Keys.new,    doNewZone)
bindAction(Config.Keys.select, doSelectNearest)
bindAction(Config.Keys.clean,  doToggleClean)

RegisterCommand('+' .. Config.Keys.menu.cmd, function()
    if Editor.active and not Editor.menuOpen and ZB_OpenMenu then ZB_OpenMenu() end
end, false)
RegisterCommand('-' .. Config.Keys.menu.cmd, function() end, false)
RegisterKeyMapping('+' .. Config.Keys.menu.cmd, 'Zone Builder (open menu)', 'keyboard', Config.Keys.menu.default)

----------------------------------------------------------------------
-- zone manager (called from the NUI menu)
----------------------------------------------------------------------
function ZB_EditZone(index)
    if Editor.zones[index] then
        Editor.idx = index
        Editor.grabbedIndex = nil
        refresh()
    end
end

function ZB_DeleteZone(index)
    if not Editor.zones[index] then return end
    pushHistory()
    table.remove(Editor.zones, index)
    if #Editor.zones == 0 then
        Editor.seq = 1
        Editor.zones[1] = defaultZone()
    end
    Editor.idx = math.max(1, math.min(Editor.idx, #Editor.zones))
    Editor.grabbedIndex = nil
    refresh()
end

function ZB_ClearCurrent()
    pushHistory()
    cur().points = {}
    Editor.grabbedIndex = nil
    refresh()
end

function ZB_SetType(t)
    if t == 'poly' or t == 'circle' or t == 'box' then setType(t) end
end

function ZB_SetName(name)
    cur().name = ZB.sanitizeName(name)
    refresh()
end

function ZB_SetHeight(h)
    h = tonumber(h) or cur().height
    cur().height = math.max(Config.MinHeight, math.min(Config.MaxHeight, h))
    refresh()
end

function ZB_SetAnchor(a)
    cur().anchor = (a == 'ground') and 'ground' or 'center'
    refresh()
end

function ZB_SetSnap(b)
    Editor.snap = b and true or false
    refresh()
end

function ZB_SetFormat(f)
    Editor.format = f or Editor.format
    refresh()
end

----------------------------------------------------------------------
-- main render loop
----------------------------------------------------------------------
CreateThread(function()
    local hudVisible = true
    while true do
        local sleep = 500
        if Editor.active then
            sleep = 0
            local paused = IsPauseMenuActive()
            local wantHud = (not paused) and (not Editor.cleanView)
            if wantHud ~= hudVisible then
                hudVisible = wantHud
                if not wantHud and Editor.menuOpen then ZB_CloseMenu() end
                SendNUIMessage({ action = 'hud', show = wantHud })
                if wantHud then ZB_UpdateHud() end
            end

            if paused then
                sleep = 150
            else
                local active = cur()
                if not Editor.menuOpen then
                    DisableControlAction(0, 36, true) -- INPUT_DUCK (X is our feet/aim toggle)
                    DisableControlAction(0, 26, true) -- INPUT_LOOK_BEHIND (C is our select-zone)
                    DisableControlAction(0, 79, true) -- INPUT_VEH_LOOK_BEHIND
                    local c = (Editor.mode == 'aim') and getAimCoord() or getFeetCoord()
                    Editor.previewCoord = c
                    if Editor.grabbedIndex and c and active.points[Editor.grabbedIndex] then
                        active.points[Editor.grabbedIndex] = snapCoord(c)
                    end
                    Editor.insertEdge = (not Editor.grabbedIndex and active.zoneType == 'poly'
                        and Editor.insertMode and c and #active.points >= 2)
                        and nearestEdge(active.points, c) or nil
                end

                -- render every zone; active = bright + edit highlights, others dimmed.
                -- clean view hides the vertex markers/labels (and the preview dot below).
                for i, z in ipairs(Editor.zones) do
                    local isActive = (i == Editor.idx)
                    Draw.render({
                        zoneType = z.zoneType, points = z.points,
                        height = z.height, anchor = z.anchor,
                        colors = isActive and Config.Colors or Config.ColorsDim,
                        insertEdge = isActive and Editor.insertEdge or nil,
                        grabIndex = isActive and Editor.grabbedIndex or nil,
                        hideMarkers = Editor.cleanView,
                    })
                end

                if not Editor.menuOpen and not Editor.cleanView
                    and Editor.previewCoord and not Editor.grabbedIndex then
                    Draw.preview(snapCoord(Editor.previewCoord), Config.Colors.preview)
                end
            end
        else
            hudVisible = true
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
