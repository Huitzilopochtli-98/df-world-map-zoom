-- Collect a bounded, read-only snapshot for World Map Zoom planning.
-- Usage: worldmap-diagnostics [label] [--save]
-- Default: print only. --save writes a NEW text report in getConfigPath().
-- No game state assignments, callbacks, renderer calls, or network operations.

local args = {...}
local label, save, label_given = 'snapshot', false, false
for _, arg in ipairs(args) do
    if arg == '--save' then
        save = true
    elseif arg:match('^[%w_-]+$') and #arg <= 40 and not label_given then
        label = arg
        label_given = true
    else
        error('Usage: worldmap-diagnostics [simple-label] [--save]')
    end
end
if not dfhack or not df then error('Run this script inside DFHack.') end

local lines = {'World Map Zoom diagnostics v1', 'label=' .. label}
local function get(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
end
local function emit(key, value)
    local kind = type(value)
    if kind ~= 'string' and kind ~= 'number' and kind ~= 'boolean' then
        value = '<unavailable>'
    end
    lines[#lines + 1] = key .. '=' .. tostring(value):gsub('[\r\n]', ' ')
end
local function call(name)
    return get(function()
        if type(dfhack[name]) == 'function' then return dfhack[name]() end
    end)
end
for _, name in ipairs{
    'getDFVersion', 'getDFHackVersion', 'getDFHackRelease',
    'getDFHackBuildID', 'getCompiledDFVersion', 'getOSType',
    'getGitCommit', 'getGitXmlCommit', 'getGitXmlExpectedCommit',
    'gitXmlMatch', 'getDFPath', 'getHackPath', 'getConfigPath',
    'isWorldLoaded', 'isMapLoaded',
} do emit(name, call(name)) end
emit('graphics_mode', get(function() return dfhack.screen.inGraphicsMode() end))

local screen = get(function() return dfhack.gui.getDFViewscreen(true) end)
local function is_type(name)
    return get(function() return df[name]:is_instance(screen) end) == true
end
local screen_kind = 'other_or_unavailable'
if is_type('viewscreen_choose_start_sitest') then screen_kind = 'embark' end
if is_type('viewscreen_worldst') then screen_kind = 'fortress_world' end
emit('screen_context', screen_kind)
if screen_kind ~= 'other_or_unavailable' then
    for _, name in ipairs{'region_cent_x', 'region_cent_y', 'mouse_scrolling_map'} do
        emit('screen.' .. name, get(function() return screen[name] end))
    end
    local names = screen_kind == 'embark'
        and {'zoomed_in', 'zoom_cent_x', 'zoom_cent_y', 'choosing_embark', 'embark_dx', 'embark_dy'}
        or {'view_mode', 'focus_ax', 'focus_ay'}
    for _, name in ipairs(names) do
        emit('screen.' .. name, get(function() return screen[name] end))
    end
end

local gps = get(function() return df.global.gps end)
for _, name in ipairs{'screen_pixel_x', 'screen_pixel_y', 'tile_pixel_x', 'tile_pixel_y', 'dimx', 'dimy'} do
    emit('gps.' .. name, get(function() return gps[name] end))
end
-- Inspect only scalar viewport fields on recognized screens. Do not traverse
-- texture arrays, renderer objects, world history, units, sites, or unions.
if screen_kind ~= 'other_or_unavailable' then
    local port = get(function() return gps.main_map_port end)
    emit('map_port_present', port ~= nil)
    if port then
        for _, name in ipairs{'dim_x', 'dim_y', 'screen_x', 'screen_y',
                              'top_left_corner_x', 'top_left_corner_y',
                              'pixel_perc_x', 'pixel_perc_y'} do
            emit('map_port.' .. name, get(function() return port[name] end))
        end
    end
end

local report = table.concat(lines, '\n') .. '\n'
print(report)
if save then
    local config = call('getConfigPath')
    if type(config) ~= 'string' or config == '' then
        error('Report printed, but the config path is unavailable; no file written.')
    end
    local stem = config .. '/worldmap-diagnostics-' .. label .. '-' .. os.time()
    local filename
    for n = 0, 999 do
        local candidate = stem .. '-' .. n .. '.txt'
        local existing = io.open(candidate, 'r')
        if existing then existing:close() else filename = candidate; break end
    end
    if not filename then error('Report printed, but no free report filename was found.') end
    local f, err = io.open(filename, 'w')
    if not f then error('Report printed, but could not save: ' .. tostring(err)) end
    local ok, why = f:write(report)
    f:close()
    if not ok then error('Could not finish writing report: ' .. tostring(why)) end
    print('Report saved: ' .. filename)
end
