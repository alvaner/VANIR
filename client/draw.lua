-- Vanir Zone Builder - 3D rendering (polygon / circle / box)
Draw = {}

local function col(c) return c[1], c[2], c[3], c[4] end

function Draw.text3d(coords, text, scale)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.0, scale or 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(text)
    DrawText(sx, sy)
end

local function marker(coords, c)
    local r, g, b, a = col(c)
    DrawMarker(28, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0,
        Config.MarkerScale, Config.MarkerScale, Config.MarkerScale,
        r, g, b, a, false, false, 2, false, nil, nil, false)
end

-- Live cursor dot: deliberately smaller and lifted so it is never mistaken
-- for a placed control-point marker (which sits at the same spot in feet mode).
function Draw.preview(coords, c)
    local r, g, b, a = col(c)
    DrawMarker(28, coords.x, coords.y, coords.z + 0.04, 0, 0, 0, 0, 0, 0,
        Config.MarkerScale * 0.5, Config.MarkerScale * 0.5, Config.MarkerScale * 0.5,
        r, g, b, a, false, false, 2, false, nil, nil, false)
end

-- Draw a closed loop given a ring of { x, y, bz, tz } vertices:
-- vertical edges, bottom & top outline, translucent walls.
local function loopGeom(ring, colors, highlightEdge)
    local n = #ring
    if n == 0 then return end
    local lr, lg, lb, la = col(colors.line)
    local wr, wg, wb, wa = col(colors.wall)

    for i = 1, n do
        local v = ring[i]
        DrawLine(v.x, v.y, v.bz, v.x, v.y, v.tz, lr, lg, lb, la)
    end
    if n < 2 then return end

    for i = 1, n do
        local a = ring[i]
        local b = ring[(i % n) + 1]
        local er, eg, eb, ea = lr, lg, lb, la
        if highlightEdge == i and colors.insert then er, eg, eb, ea = col(colors.insert) end

        DrawLine(a.x, a.y, a.bz, b.x, b.y, b.bz, er, eg, eb, ea)
        DrawLine(a.x, a.y, a.tz, b.x, b.y, b.tz, er, eg, eb, ea)

        if n >= 3 then
            DrawPoly(a.x, a.y, a.bz, a.x, a.y, a.tz, b.x, b.y, b.tz, wr, wg, wb, wa)
            DrawPoly(b.x, b.y, b.tz, a.x, a.y, a.tz, a.x, a.y, a.bz, wr, wg, wb, wa)
            DrawPoly(a.x, a.y, a.bz, b.x, b.y, b.tz, b.x, b.y, b.bz, wr, wg, wb, wa)
            DrawPoly(b.x, b.y, b.bz, b.x, b.y, b.tz, a.x, a.y, a.bz, wr, wg, wb, wa)
        end
    end
end

-- Markers + numbered labels on the editable control points
local function controlPoints(pts, colors, grabIndex, height, anchor)
    for i = 1, #pts do
        local p = pts[i]
        marker(p, (grabIndex == i and colors.grab) and colors.grab or colors.marker)
        if Config.ShowLabels then
            local _, top = ZB.bottomTop(p.z, height, anchor)
            Draw.text3d(vector3(p.x, p.y, top + 0.15), tostring(i))
        end
    end
end

-- z = { zoneType, points, height, anchor, colors, insertEdge, grabIndex }
function Draw.render(z)
    local pts = z.points
    local n = #pts
    if n == 0 then return end
    local colors = z.colors

    if z.zoneType == 'circle' then
        local c, r = ZB.circleOf(pts)
        if c and r and r > 0.05 and n >= 2 then
            local bz, tz = ZB.bottomTop(c.z, z.height, z.anchor)
            local segs = Config.CircleSegments
            local ring = {}
            for i = 0, segs - 1 do
                local ang = (i / segs) * 2 * math.pi
                ring[#ring + 1] = { x = c.x + math.cos(ang) * r, y = c.y + math.sin(ang) * r, bz = bz, tz = tz }
            end
            loopGeom(ring, colors, nil)
        end
        if not z.hideMarkers then controlPoints(pts, colors, z.grabIndex, z.height, z.anchor) end

    elseif z.zoneType == 'box' then
        local b = ZB.boxOf(pts)
        if b then
            local bz, tz = ZB.bottomTop(b.cz, z.height, z.anchor)
            local ring = {}
            for _, cn in ipairs(b.corners) do
                ring[#ring + 1] = { x = cn.x, y = cn.y, bz = bz, tz = tz }
            end
            loopGeom(ring, colors, nil)
        end
        if not z.hideMarkers then controlPoints(pts, colors, z.grabIndex, z.height, z.anchor) end

    else
        local ring = {}
        for _, p in ipairs(pts) do
            local bz, tz = ZB.bottomTop(p.z, z.height, z.anchor)
            ring[#ring + 1] = { x = p.x, y = p.y, bz = bz, tz = tz }
        end
        loopGeom(ring, colors, z.insertEdge)
        if not z.hideMarkers then controlPoints(pts, colors, z.grabIndex, z.height, z.anchor) end
    end
end
