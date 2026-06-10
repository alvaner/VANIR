Locales = Locales or {}

Locales['en'] = {
    editor_on      = 'Zone Builder ~g~enabled~s~  -  ~y~%s~s~ place,  ~y~%s~s~ menu',
    editor_off     = 'Zone Builder ~r~disabled',
    mode_feet      = 'Place mode: ~b~FEET~s~ (your position)',
    mode_aim       = 'Place mode: ~b~AIM~s~ (crosshair)',
    insert_on      = 'Insert mode ~b~ON~s~ - new point splits the nearest edge',
    insert_off     = 'Insert mode ~r~OFF~s~',
    point_added    = 'Point ~g~%d~s~',
    point_undo     = 'Undo (~y~%d~s~ points)',
    undone         = 'Undo',
    nothing_undo   = 'Nothing to undo',
    nothing_redo   = 'Nothing to redo',
    redone         = 'Redo',
    new_zone       = 'New zone (~y~%d~s~ total)',
    selected_zone  = 'Editing zone ~b~%d~s~',
    no_zone_near   = 'No zone near the cursor',
    clean_on       = 'Clean view ~b~ON~s~ - press ~y~%s~s~ to bring the HUD back',
    clean_off      = 'Clean view ~r~OFF~s~',
    point_deleted  = 'Point removed (~y~%d~s~ left)',
    del_none       = 'No points to delete',
    point_grabbed  = 'Grabbed point ~y~%d~s~ - move it, then ~y~%s~s~ to drop',
    point_dropped  = 'Point dropped',
    nothing_grab   = 'No points to grab',
    del_poly_only  = 'Delete works on polygon vertices',
    cleared        = 'All points cleared',
    height_set     = 'Height: ~b~%.1f~s~ m',
    type_set       = 'Zone type: ~b~%s~s~',
    anchor_set     = 'Height anchor: ~b~%s~s~',
    snap_on        = 'Grid snap ~b~ON~s~ (~b~%.1f~s~ m)',
    snap_off       = 'Grid snap ~r~OFF~s~',
    saved_to_list  = 'Saved "~g~%s~s~" to list (~y~%d~s~ total) - fresh zone started',
    need_points    = '~r~Zone is incomplete or too small to export',
    saved          = 'Exported to ~g~%s~s~',
    saved_all      = 'Exported ~g~%d~s~ zones to ~g~%s~s~',
    save_failed    = '~r~Export failed - check server console',
    loaded         = 'Loaded "~b~%s~s~" for editing',
    deleted_zone   = 'Removed "~y~%s~s~" from the list',
}

-- Active locale
Locale = 'en'

function L(key, ...)
    local str = (Locales[Locale] and Locales[Locale][key]) or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
