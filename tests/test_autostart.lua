-- Exercise map visits, deferred native readiness, dismissal, and timer cleanup.
local current = {_tag='title'}
local queue, next_id, launches, errors = {}, 0, 0, 0
local function class(tag)
    return {is_instance=function(_, screen) return screen and screen._tag == tag end}
end
local dfmock = {
    viewscreen_choose_start_sitest=class('embark'), viewscreen_worldst=class('fortress'),
    choose_start_site_view_mode={Biome=0}, world_view_mode_type={NORMAL=0},
    global={gps={main_map_port={flag={active=true},dim_x=80,dim_y=50}},
        world={world_data={world_width=129,world_height=129}}},
}
local hack = {
    gui={getDFViewscreen=function() return current end}, onStateChange={},
    timeout=function(delay, units, callback)
        assert(units == 'frames' and delay > 0)
        next_id=next_id+1;queue[next_id]=callback;return next_id
    end,
    timeout_active=function(id, callback) assert(callback == nil);queue[id]=nil end,
    run_script=function(name) assert(name=='gui/worldmap-zoom');launches=launches+1 end,
    printerr=function() errors=errors+1 end,
}
local env = setmetatable({df=dfmock,dfhack=hack,dfhack_flags={module=true},
    SC_VIEWSCREEN_CHANGED=1, SC_WORLD_LOADED=2, SC_WORLD_UNLOADED=3,
    SC_MAP_LOADED=4, SC_MAP_UNLOADED=5}, {__index=_G})
local context=assert(loadfile('hack/lua/worldmap-zoom/context.lua','t',env))()
env.require=function(name) assert(name=='worldmap-zoom.context');return context end
assert(loadfile('dfhack-config/scripts/worldmap-zoom-autostart.lua','t',env))()
local function frame()
    local id=next(queue);assert(id,'Expected a scheduled map check')
    local callback=queue[id];queue[id]=nil;callback()
end
local function event(code)
    local callback=hack.onStateChange['worldmap-zoom-autostart']
    if callback then callback(code or env.SC_VIEWSCREEN_CHANGED) end
end
local function count_timers()
    local count=0;for _ in pairs(queue) do count=count+1 end;return count
end

env.set_enabled(true);frame()
assert(env.isEnabled() and launches==0 and next(queue)==nil,'Idle screens must not poll')

local fortress={_tag='fortress',view_mode=0}
current=fortress;dfmock.global.gps.main_map_port.flag.active=false
event();frame();assert(launches==0 and count_timers()==1,'Wait for native map readiness')
dfmock.global.gps.main_map_port.flag.active=true
frame();assert(launches==1,'Open when the map becomes ready')
for _=1,10 do frame() end
assert(launches==1,'Open only once per visit')
event();frame();assert(launches==1,'Lua screen changes and Esc must not reopen the tool')
for _=1,5 do event() end
assert(count_timers()==1,'Coalesce repeated screen-change events')
frame();assert(launches==1)

current={_tag='fortress-game'};event();frame()
assert(next(queue)==nil,'Stop polling after leaving the map')
current=fortress;event();frame();assert(launches==2,'Reopen on the next map visit')
fortress.view_mode=1;frame();assert(launches==2)
fortress.view_mode=0;frame();assert(launches==3,'Detect submode changes without screen events')
dfmock.global.gps.main_map_port.flag.active=false;frame()
dfmock.global.gps.main_map_port.flag.active=true;frame()
assert(launches==3,'Temporary map-port changes must not undo Esc suppression')

local embark={_tag='embark',zoomed_in=false,page=0,
    animating_quick_start_timer=1,setting_up_map_timer=0}
current=embark;event();frame();assert(launches==3,'Wait for embark transition')
embark.animating_quick_start_timer=0;frame();assert(launches==4,'Open the embark world map')
embark.zoomed_in=true;frame();assert(launches==4,'Do not open in detailed embark view')
embark.zoomed_in=false;frame();assert(launches==5,'Reopen when returning to the high-level map')
embark.page=1;frame();assert(launches==5)
embark.page=0;frame();assert(launches==6)

queue={};current={_tag='title'};event(env.SC_WORLD_UNLOADED);frame()
assert(next(queue)==nil,'Recover correctly after world unload clears timers')
current=fortress;event(env.SC_WORLD_LOADED);event(env.SC_MAP_LOADED);frame()
assert(launches==7 and count_timers()==1)
env.set_enabled(false)
assert(not env.isEnabled() and count_timers()==0 and next(hack.onStateChange)==nil)
event();assert(launches==7,'Disabled autostart must leave the map alone')

hack.run_script=function() launches=launches+1;error('missing renderer') end
env.set_enabled(true);frame();frame()
assert(launches==8 and errors==1,'Report an incompatible renderer once per visit')
env.set_enabled(false)
print('PASS autostart map visits, readiness, Esc suppression, submodes, unload, disable, and launch failure')
