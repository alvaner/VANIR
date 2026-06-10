-- Vanir Zone Builder - shared helpers (pure logic, no game natives)
ZB = {}

function ZB.round(n, d)
    local m = 10 ^ (d or 2)
    return math.floor(n * m + 0.5) / m
end

-- Turn a free-typed name into a safe Lua identifier / filename
function ZB.sanitizeName(name)
    name = tostring(name or '')
    name = name:gsub('%s+', '_'):gsub('[^%w_]', '')
    if name == '' then name = 'my_zone' end
    if name:match('^%d') then name = 'zone_' .. name end
    return name:lower()
end

function ZB.dist2d(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

-- bottom/top Z for a point, given total thickness and anchor mode
function ZB.bottomTop(z, height, anchor)
    if anchor == 'ground' then
        return z, z + height
    end
    local half = height / 2
    return z - half, z + half
end

----------------------------------------------------------------------
-- Derived geometry for circle / box zones (points = list of {x,y,z})
----------------------------------------------------------------------
-- circle: points[1] = centre, points[2] = a point on the rim
function ZB.circleOf(points)
    local c = points[1]
    local rim = points[2]
    local r = (c and rim) and ZB.dist2d(c, rim) or 0.0
    return c, r
end

-- box: points[1], points[2] = opposite corners (axis-aligned)
function ZB.boxOf(points)
    local a, b = points[1], points[2]
    if not (a and b) then return nil end
    local minX, maxX = math.min(a.x, b.x), math.max(a.x, b.x)
    local minY, maxY = math.min(a.y, b.y), math.max(a.y, b.y)
    local cz = (a.z + b.z) / 2
    return {
        cx = (minX + maxX) / 2, cy = (minY + maxY) / 2, cz = cz,
        width = maxX - minX,    -- size along X
        length = maxY - minY,   -- size along Y
        corners = {
            { x = minX, y = minY, z = cz },
            { x = maxX, y = minY, z = cz },
            { x = maxX, y = maxY, z = cz },
            { x = minX, y = maxY, z = cz },
        },
    }
end

-- Absolute min/max Z across a polygon's points
function ZB.zRange(points, height, anchor)
    local minZ, maxZ = math.huge, -math.huge
    for _, p in ipairs(points) do
        local b, t = ZB.bottomTop(p.z, height, anchor)
        if b < minZ then minZ = b end
        if t > maxZ then maxZ = t end
    end
    return ZB.round(minZ, 2), ZB.round(maxZ, 2)
end

----------------------------------------------------------------------
-- Metrics (area m², perimeter m) for the HUD
----------------------------------------------------------------------
function ZB.metrics(zone)
    local t = zone.zoneType
    if t == 'circle' then
        local _, r = ZB.circleOf(zone.points)
        return ZB.round(math.pi * r * r, 1), ZB.round(2 * math.pi * r, 1)
    elseif t == 'box' then
        local b = ZB.boxOf(zone.points)
        if not b then return 0, 0 end
        return ZB.round(b.width * b.length, 1), ZB.round(2 * (b.width + b.length), 1)
    else
        local p = zone.points
        local n = #p
        if n < 3 then return 0, 0 end
        local area, per = 0.0, 0.0
        for i = 1, n do
            local a = p[i]
            local b = p[(i % n) + 1]
            area = area + (a.x * b.y - b.x * a.y)
            per = per + ZB.dist2d(a, b)
        end
        return ZB.round(math.abs(area) / 2, 1), ZB.round(per, 1)
    end
end

-- Is the zone complete enough (and big enough) to export?
function ZB.isValid(zone)
    local p = zone.points
    if zone.zoneType == 'poly' then return #p >= 3 end
    if #p < 2 then return false end
    if zone.zoneType == 'circle' then
        return ZB.dist2d(p[1], p[2]) > 0.1
    else -- box
        local b = ZB.boxOf(p)
        return b ~= nil and b.width > 0.1 and b.length > 0.1
    end
end

----------------------------------------------------------------------
-- Export generators. zone = { name, zoneType, points, height, anchor }
----------------------------------------------------------------------
ZB.gen = {}

-- ox_lib --------------------------------------------------------------
function ZB.gen.oxlib(zone)
    local name = ZB.sanitizeName(zone.name)
    if zone.zoneType == 'circle' then
        -- ox_lib has no cylinder; emit a poly N-gon that matches the previewed
        -- height-bounded circle (a sphere would ignore height and go through the ground).
        local c, r = ZB.circleOf(zone.points)
        local lift = (zone.anchor == 'ground') and (zone.height / 2) or 0.0
        local segs = Config.CircleSegments
        local out = {
            ('-- %s - ox_lib poly circle, %d sides (Vanir Zone Builder)'):format(name, segs),
            ('local %s = lib.zones.poly({'):format(name),
            '    points = {',
        }
        for i = 0, segs - 1 do
            local ang = (i / segs) * 2 * math.pi
            out[#out + 1] = ('        vec3(%.2f, %.2f, %.2f),'):format(
                c.x + math.cos(ang) * r, c.y + math.sin(ang) * r, c.z + lift)
        end
        out[#out + 1] = '    },'
        out[#out + 1] = ('    thickness = %.1f,'):format(zone.height)
        out[#out + 1] = '    debug = false,'
        out[#out + 1] = '    onEnter = function(self) end,'
        out[#out + 1] = '    onExit = function(self) end,'
        out[#out + 1] = '})'
        return table.concat(out, '\n')
    elseif zone.zoneType == 'box' then
        local b = ZB.boxOf(zone.points)
        local bot, top = ZB.bottomTop(b.cz, zone.height, zone.anchor)
        local czc = (bot + top) / 2
        return table.concat({
            ('-- %s - ox_lib box (Vanir Zone Builder)'):format(name),
            ('local %s = lib.zones.box({'):format(name),
            ('    coords = vec3(%.2f, %.2f, %.2f),'):format(b.cx, b.cy, czc),
            ('    size = vec3(%.2f, %.2f, %.2f),'):format(b.width, b.length, zone.height),
            '    rotation = 0.0,',
            '    debug = false,',
            '    onEnter = function(self) end,',
            '    onExit = function(self) end,',
            '})',
        }, '\n')
    else
        -- ox_lib's lib.zones.poly flattens a non-planar polygon to ONE z plane,
        -- so emit a single representative plane + a thickness that spans the full
        -- vertical range. This keeps the exported zone matching the preview on
        -- sloped ground (per-vertex z would be silently collapsed by ox_lib).
        local minZ, maxZ = ZB.zRange(zone.points, zone.height, zone.anchor)
        local cz = (minZ + maxZ) / 2
        local thickness = math.max(maxZ - minZ, 0.1)
        local out = {
            ('-- %s - ox_lib poly (Vanir Zone Builder)'):format(name),
            ('local %s = lib.zones.poly({'):format(name),
            '    points = {',
        }
        for _, p in ipairs(zone.points) do
            out[#out + 1] = ('        vec3(%.2f, %.2f, %.2f),'):format(p.x, p.y, cz)
        end
        out[#out + 1] = '    },'
        out[#out + 1] = ('    thickness = %.1f,'):format(thickness)
        out[#out + 1] = '    debug = false,'
        out[#out + 1] = '    onEnter = function(self) end,'
        out[#out + 1] = '    onExit = function(self) end,'
        out[#out + 1] = '})'
        return table.concat(out, '\n')
    end
end

-- PolyZone ------------------------------------------------------------
function ZB.gen.polyzone(zone)
    local name = ZB.sanitizeName(zone.name)
    if zone.zoneType == 'circle' then
        local c, r = ZB.circleOf(zone.points)
        return table.concat({
            ('-- %s - PolyZone CircleZone (Vanir Zone Builder)'):format(name),
            '-- note: CircleZone is a 2D circle (useZ=false); height/anchor are not represented here.',
            ('local %s = CircleZone:Create(vector3(%.2f, %.2f, %.2f), %.2f, {'):format(name, c.x, c.y, c.z, r),
            ('    name = "%s",'):format(name),
            '    useZ = false,',
            '    debugPoly = false,',
            '})',
        }, '\n')
    elseif zone.zoneType == 'box' then
        local b = ZB.boxOf(zone.points)
        local minZ, maxZ = ZB.bottomTop(b.cz, zone.height, zone.anchor)
        return table.concat({
            ('-- %s - PolyZone BoxZone (Vanir Zone Builder)'):format(name),
            ('local %s = BoxZone:Create(vector3(%.2f, %.2f, %.2f), %.2f, %.2f, {'):format(name, b.cx, b.cy, b.cz, b.length, b.width),
            ('    name = "%s",'):format(name),
            '    heading = 0,',
            ('    minZ = %.2f,'):format(ZB.round(minZ, 2)),
            ('    maxZ = %.2f,'):format(ZB.round(maxZ, 2)),
            '    debugPoly = false,',
            '})',
        }, '\n')
    else
        local minZ, maxZ = ZB.zRange(zone.points, zone.height, zone.anchor)
        local out = {
            ('-- %s - PolyZone (Vanir Zone Builder)'):format(name),
            ('local %s = PolyZone:Create({'):format(name),
        }
        for _, p in ipairs(zone.points) do
            out[#out + 1] = ('    vector2(%.2f, %.2f),'):format(p.x, p.y)
        end
        out[#out + 1] = '}, {'
        out[#out + 1] = ('    name = "%s",'):format(name)
        out[#out + 1] = ('    minZ = %.2f,'):format(minZ)
        out[#out + 1] = ('    maxZ = %.2f,'):format(maxZ)
        out[#out + 1] = '    debugPoly = false,'
        out[#out + 1] = '})'
        return table.concat(out, '\n')
    end
end

-- Plain Lua table -----------------------------------------------------
function ZB.gen.native(zone)
    local name = ZB.sanitizeName(zone.name)
    local out = {
        ('-- %s - plain Lua table (Vanir Zone Builder)'):format(name),
        'Zones = Zones or {}',
    }
    if zone.zoneType == 'circle' then
        local c, r = ZB.circleOf(zone.points)
        out[#out + 1] = ('Zones["%s"] = {'):format(name)
        out[#out + 1] = '    type = "circle",'
        out[#out + 1] = ('    center = { x = %.2f, y = %.2f, z = %.2f },'):format(c.x, c.y, c.z)
        out[#out + 1] = ('    radius = %.2f,'):format(r)
        out[#out + 1] = ('    height = %.1f, anchor = "%s",'):format(zone.height, zone.anchor)
        out[#out + 1] = '}'
    elseif zone.zoneType == 'box' then
        local b = ZB.boxOf(zone.points)
        out[#out + 1] = ('Zones["%s"] = {'):format(name)
        out[#out + 1] = '    type = "box",'
        out[#out + 1] = ('    center = { x = %.2f, y = %.2f, z = %.2f },'):format(b.cx, b.cy, b.cz)
        out[#out + 1] = ('    width = %.2f, length = %.2f,'):format(b.width, b.length)
        out[#out + 1] = ('    height = %.1f, anchor = "%s",'):format(zone.height, zone.anchor)
        out[#out + 1] = '}'
    else
        out[#out + 1] = ('Zones["%s"] = {'):format(name)
        out[#out + 1] = '    type = "poly",'
        out[#out + 1] = ('    height = %.1f, anchor = "%s",'):format(zone.height, zone.anchor)
        out[#out + 1] = '    points = {'
        for _, p in ipairs(zone.points) do
            out[#out + 1] = ('        { x = %.2f, y = %.2f, z = %.2f },'):format(p.x, p.y, p.z)
        end
        out[#out + 1] = '    },'
        out[#out + 1] = '}'
    end
    return table.concat(out, '\n')
end

function ZB.generate(format, zone)
    local fn = ZB.gen[format] or ZB.gen.oxlib
    return fn(zone)
end

-- Concatenate several zones into one file (used by "Export all").
-- Sanitised names are made unique (foo, foo_2, foo_3) so two zones with the
-- same name don't shadow each other or overwrite a table key in the output.
function ZB.generateAll(format, zones)
    local parts, seen = {}, {}
    for _, z in ipairs(zones) do
        if ZB.isValid(z) then
            local base = ZB.sanitizeName(z.name)
            local name, n = base, 2
            while seen[name] do name = base .. '_' .. n; n = n + 1 end
            seen[name] = true
            local zc = { name = name, zoneType = z.zoneType, points = z.points, height = z.height, anchor = z.anchor }
            parts[#parts + 1] = ZB.generate(format, zc)
        end
    end
    return table.concat(parts, '\n\n')
end

-- JSON for a single zone
function ZB.gen.json(zone)
    local data = {
        name = ZB.sanitizeName(zone.name),
        type = zone.zoneType,
        height = zone.height,
        anchor = zone.anchor,
    }
    if zone.zoneType == 'circle' then
        local c, r = ZB.circleOf(zone.points)
        data.center = { x = ZB.round(c.x), y = ZB.round(c.y), z = ZB.round(c.z) }
        data.radius = ZB.round(r)
    elseif zone.zoneType == 'box' then
        local b = ZB.boxOf(zone.points)
        data.center = { x = ZB.round(b.cx), y = ZB.round(b.cy), z = ZB.round(b.cz) }
        data.width, data.length = ZB.round(b.width), ZB.round(b.length)
    else
        data.points = {}
        for _, p in ipairs(zone.points) do
            data.points[#data.points + 1] = { x = ZB.round(p.x), y = ZB.round(p.y), z = ZB.round(p.z) }
        end
    end
    return json.encode(data)
end
