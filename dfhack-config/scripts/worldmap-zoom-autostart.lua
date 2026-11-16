-- Open World Map Zoom once whenever a supported world map is entered.
--@ module = true
--@ enable = true
local context = require('worldmap-zoom.context')
local KEY = 'worldmap-zoom-autostart'

enabled = enabled or false
visit = visit or {}
generation = generation or 0

function isEnabled() return enabled end

local function check_map()
    local screen = dfhack.gui.getDFViewscreen(true)
    local is_map = df.viewscreen_choose_start_sitest:is_instance(screen) or
        df.viewscreen_worldst:is_instance(screen)
    if not is_map then visit = {}; return false end
    if visit.screen ~= screen then visit = {screen=screen} end
    if not context.get_screen() then
        -- A detailed embark view or site-action panel ends this map visit.
        visit.handled = false
    elseif not visit.handled and context.get() then
        -- Mark before opening: showing/dismissing the Lua screen also sends
        -- screen-change events. Esc must stay dismissed for the current visit.
        visit.handled = true
        local ok, err = pcall(dfhack.run_script, 'gui/worldmap-zoom')
        if not ok then dfhack.printerr('World map zoom autostart: '..tostring(err)) end
    end
    return true
end

local function reschedule()
    generation = generation + 1
    local current = generation
    if timer then dfhack.timeout_active(timer, nil); timer = nil end
    if not enabled then return end
    local function poll()
        if not enabled or current ~= generation then return end
        timer = nil
        if check_map() then
            -- Also detect native submode changes that reuse the same screen.
            timer = dfhack.timeout(5, 'frames', poll)
        end
    end
    timer = dfhack.timeout(1, 'frames', poll)
end

function set_enabled(value)
    enabled = value
    visit = {}
    dfhack.onStateChange[KEY] = value and function(code)
        if code == SC_WORLD_UNLOADED then visit = {} end
        if code == SC_VIEWSCREEN_CHANGED or code == SC_WORLD_LOADED or
                code == SC_WORLD_UNLOADED or code == SC_MAP_LOADED or
                code == SC_MAP_UNLOADED then
            reschedule()
        end
    end or nil
    reschedule()
end

if dfhack_flags.module then return end
local args = {...}
local value = dfhack_flags.enable_state
if value == nil then
    if args[1] == 'disable' then value = false
    elseif not args[1] or args[1] == 'enable' then value = true
    else qerror('Usage: worldmap-zoom-autostart [enable|disable]') end
end
set_enabled(value)
