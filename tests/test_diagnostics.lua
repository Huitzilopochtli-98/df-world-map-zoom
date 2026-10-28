-- Standalone binding mocks only. Does not establish in-game compatibility.
local script_path = ({...})[1] or 'tools/worldmap-diagnostics.lua'
local passed = 0
local function readonly(t)
    local data = {}
    for k, v in pairs(t) do data[k] = type(v) == 'table' and readonly(v) or v end
    return setmetatable({}, {
        __index = data,
        __newindex = function() error('attempted game state mutation') end,
    })
end
local function run(context, args, opts)
    opts = opts or {}
    local output, writes = {}, {}
    local vs = {_tag = context, region_cent_x = 12, region_cent_y = 30,
        mouse_scrolling_map = false, zoomed_in = false, zoom_cent_x = 192,
        zoom_cent_y = 480, choosing_embark = false, embark_dx = 4,
        embark_dy = 4, view_mode = 0, focus_ax = 4, focus_ay = 8}
    local globals = {gps = {screen_pixel_x = 1920, screen_pixel_y = 1080,
        tile_pixel_x = 8, tile_pixel_y = 12, dimx = 240, dimy = 90,
        main_map_port = {dim_x = 100, dim_y = 60, top_left_corner_x = 16,
            top_left_corner_y = 32, screen_x = 0, screen_y = 0,
            pixel_perc_x = 100, pixel_perc_y = 100}}}
    if opts.no_gps then globals.gps = nil end
    local dfmock = readonly{
        global = globals,
        viewscreen_choose_start_sitest = {is_instance = function(_, s) return s._tag == 'embark' end},
        viewscreen_worldst = {is_instance = function(_, s) return s._tag == 'fortress_world' end},
    }
    vs = readonly(vs)
    local hack = {
        getDFVersion = function() return 'test-df' end,
        getDFHackVersion = function() return 'test-dfhack' end,
        getConfigPath = function() return '/mock-config' end,
        getDFPath = function() return '/mock-df' end,
        getHackPath = function() return '/mock-separate-dfhack' end,
        isWorldLoaded = function() return context ~= 'title' end,
        isMapLoaded = function() return context == 'fortress_world' end,
        screen = {inGraphicsMode = function() return true end},
        gui = {getDFViewscreen = function() return vs end},
    }
    if opts.no_config then hack.getConfigPath = nil end
    if opts.missing_api then hack = {} end
    local fakeio = {open = function(path, mode)
        if mode == 'r' then
            if opts.collision and path:match('%-0%.txt$') then
                return {close = function() end}
            end
            return nil
        end
        assert(mode == 'w')
        return {write = function(_, text) writes[path] = text; return true end,
                close = function() return true end}
    end}
    local env = setmetatable({df = dfmock, dfhack = readonly(hack), io = fakeio,
        os = {time = function() return 12345 end},
        print = function(s) output[#output + 1] = tostring(s) end},
        {__index = _G, __newindex = function() error('unexpected global write') end})
    local chunk = assert(loadfile(script_path, 't', env))
    local ok, err = pcall(chunk, table.unpack(args or {}))
    return ok, err, table.concat(output, '\n'), writes
end
local function check(name, fn)
    fn(); passed = passed + 1; io.write('PASS ', name, '\n')
end
check('title without loaded map', function()
    local ok, _, out, writes = run('title', {'title'}, {no_gps=true})
    assert(ok and out:find('screen_context=other_or_unavailable', 1, true))
    assert(not out:find('map_port.dim_x', 1, true) and next(writes) == nil)
end)
check('embark context and false values', function()
    local ok, _, out, writes = run('embark', {'embark'})
    assert(ok and out:find('screen_context=embark', 1, true))
    assert(out:find('screen.zoomed_in=false', 1, true))
    assert(out:find('map_port.dim_x=100', 1, true) and next(writes) == nil)
end)
check('fortress context and zero enum', function()
    local ok, _, out = run('fortress_world', {'fortress'})
    assert(ok and out:find('screen.view_mode=0', 1, true))
    assert(not out:find('screen.zoomed_in', 1, true))
end)
check('optional APIs unavailable', function()
    local ok, _, out = run('title', {}, {missing_api=true})
    assert(ok and out:find('getDFVersion=<unavailable>', 1, true))
end)
check('reject unsafe labels and duplicate labels', function()
    assert(not run('title', {'../path'}))
    assert(not run('title', {'snapshot', 'second'}))
end)
check('save new report, preserve existing report', function()
    local ok, _, out, writes = run('embark', {'embark', '--save'}, {collision=true})
    assert(ok and writes['/mock-config/worldmap-diagnostics-embark-12345-1.txt'])
    assert(not writes['/mock-config/worldmap-diagnostics-embark-12345-0.txt'])
    assert(out:find('Report saved:', 1, true))
end)
check('missing config prints report then fails without writing', function()
    local ok, _, out, writes = run('title', {'--save'}, {no_config=true})
    assert(not ok and out:find('World Map Zoom diagnostics v1', 1, true))
    assert(next(writes) == nil)
end)
io.write(passed, ' mock checks passed. These mocks do not establish native compatibility.\n')
