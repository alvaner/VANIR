Config = {}

-- Slash command that toggles the editor on/off (also bound to a key below)
Config.ToggleCommand = 'zonebuilder'

-- Default key to open/close the editor (rebindable in Settings > Key Bindings > FiveM)
Config.ToggleKey = 'F7'

-- In-editor keys, registered as FiveM key bindings (rebindable in
-- Settings > Key Bindings > FiveM).
--   cmd     = internal command name (keep unique)
--   label   = what the HUD shows
--   default = the default key (FiveM key-mapper name)
Config.Keys = {
    place  = { cmd = 'vzb_place',  label = 'Enter',     default = 'RETURN'   }, -- place / drop grabbed vertex
    undo   = { cmd = 'vzb_undo',   label = 'Backspace', default = 'BACK'     }, -- undo
    redo   = { cmd = 'vzb_redo',   label = 'Y',         default = 'Y'        }, -- redo
    mode   = { cmd = 'vzb_mode',   label = 'X',         default = 'X'        }, -- feet / aim placement
    insert = { cmd = 'vzb_insert', label = 'G',         default = 'G'        }, -- insert-at-edge (polygons)
    grab   = { cmd = 'vzb_grab',   label = 'H',         default = 'H'        }, -- grab / move vertex
    del    = { cmd = 'vzb_del',    label = 'Delete',    default = 'DELETE'   }, -- delete nearest vertex (poly)
    type   = { cmd = 'vzb_type',   label = 'B',         default = 'B'        }, -- cycle poly / circle / box
    anchor = { cmd = 'vzb_anchor', label = 'J',         default = 'J'        }, -- height anchor center / ground
    snap   = { cmd = 'vzb_snap',   label = 'K',         default = 'K'        }, -- toggle grid snap
    raise  = { cmd = 'vzb_raise',  label = 'PageUp',    default = 'PAGEUP'   }, -- raise height
    lower  = { cmd = 'vzb_lower',  label = 'PageDown',  default = 'PAGEDOWN' }, -- lower height
    menu   = { cmd = 'vzb_menu',   label = 'M',         default = 'M'        }, -- open the menu
    new    = { cmd = 'vzb_new',    label = 'N',         default = 'N'        }, -- finish this zone, start a new one
    select = { cmd = 'vzb_select', label = 'C',         default = 'C'        }, -- make the zone nearest the cursor active
    clean  = { cmd = 'vzb_clean',  label = 'O',         default = 'O'        }, -- clean view: hide HUD + dots, keep zones
}

-- Zone defaults
Config.DefaultType   = 'poly'    -- 'poly' | 'circle' | 'box'
Config.DefaultAnchor = 'center'  -- 'center' (thickness centred on points) | 'ground' (grows upward)

-- Height (vertical thickness)
Config.DefaultHeight = 4.0
Config.HeightStep    = 0.5
Config.MinHeight     = 0.5
Config.MaxHeight     = 250.0

-- Grid snap step in metres (when snap is on, placed points round to this grid)
Config.GridSize = 0.5

-- Placement: 'feet' (your position) or 'aim' (crosshair raycast)
Config.DefaultMode = 'feet'
Config.AimDistance = 1000.0

-- Smoothness of drawn/known circles (number of segments)
Config.CircleSegments = 48

-- Colours, RGBA 0-255
Config.Colors = {
    line    = { 65, 200, 255, 255 }, -- outline
    wall    = { 65, 200, 255, 45  }, -- translucent walls
    marker  = { 255, 255, 255, 220 }, -- vertices
    preview = { 120, 255, 120, 220 }, -- live preview point at the cursor
    insert  = { 255, 170, 60, 255 },  -- highlighted edge a new point will split
    grab    = { 255, 230, 60, 255 },  -- the vertex currently grabbed for moving
}

-- Colours for INACTIVE zones (all zones render at once; only one is editable)
Config.ColorsDim = {
    line    = { 140, 155, 170, 150 },
    wall    = { 140, 155, 170, 20  },
    marker  = { 180, 190, 200, 140 },
    preview = { 120, 255, 120, 220 },
    insert  = { 255, 170, 60, 255 },
    grab    = { 255, 230, 60, 255 },
}

Config.MarkerScale = 0.25
Config.ShowLabels = true

-- Default export format: 'oxlib' | 'polyzone' | 'native'
Config.DefaultFormat = 'oxlib'

-- Where exported files are written inside the resource (server-side)
Config.OutputDir = 'output'

-- Access control for saving files. false = anyone in the editor may export.
-- true = only players with the ace below (grant: add_ace group.admin vnr_zonebuilder.save allow)
Config.RequireAce = false
Config.SaveAce    = 'vnr_zonebuilder.save'
