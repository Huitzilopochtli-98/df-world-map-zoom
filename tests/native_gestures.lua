-- Run with loadfile() in a DISPOSABLE game, with World Map Zoom open.
-- Synthesizes DFHack pointer/button input; does not embark or issue orders.
local mode,path=...
local test_zoom=4
local gui=require('gui')
local input=require('worldmap-zoom.input')
local b=require('plugins.worldmap-zoom-render')
local v=assert(reqscript('gui/worldmap-zoom').view,'Open World Map Zoom first')
local s,c,p=v.context.screen,v.camera,v.context.port
local g,e=df.global.gps,df.global.enabler
local checks=0
local function check(ok,msg)checks=checks+1;assert(ok,msg)end
local function near(a,b,tolerance)check(math.abs(a-b)<=(tolerance or 1e-8),tostring(a)..' ~= '..tostring(b))end
local function pointer(x,y)
    x,y=math.floor(x),math.floor(y)
    g.precise_mouse_x,g.precise_mouse_y=x,y
    g.mouse_x,g.mouse_y=math.floor(x/g.tile_pixel_x),math.floor(y/g.tile_pixel_y)
    e.tracking_on,e.mouse_focus=1,true
end
local function press(button,x,y)
    pointer(x,y)
    local left=button=='left'
    e[left and 'mouse_lbut_down' or 'mouse_mbut_down']=1
    gui.simulateInput(v._native,left and {_MOUSE_L=true,_MOUSE_L_DOWN=true} or {_MOUSE_M=true,_MOUSE_M_DOWN=true})
    check(v.gesture~=nil,'Map press must capture a gesture')
end
local function release(button,x,y)
    pointer(x,y);e[button=='left' and 'mouse_lbut_down' or 'mouse_mbut_down']=0
    v:onIdle()
end
local function untouched()
    check(dfhack.gui.getDFViewscreen(true)==s,'Native screen changed during a drag')
    if v.context.id==1 then
        check(not s.zoomed_in,'Drag opened detailed embark')
        check(s.embark_dx==4 and s.embark_dy==4,'Embark footprint changed')
    else
        check(s.view_mode==df.world_view_mode_type.NORMAL,'Drag opened an action mode')
        check(#s.army_controller==0,'Drag created an army controller')
    end
end
local function save(data)
    data.checks=checks;data.context=v.context.id;data.port={p.dim_x,p.dim_y}
    local ok,status=pcall(b.status)
    data.status=ok and status or {unloaded=true}
    if path then local f=assert(io.open(path,'w'));f:write(require('json').encode(data));f:close()end
    print('PASS '..mode..' '..checks..' native gesture checks')
end

if mode=='standard' then
    check(b.status().window_focused,'Use test_focus(true), wait a frame, then run this test')
    local anchor_errors={}
    for _,target in ipairs{2,4} do
    for _,frac in ipairs{.1,.35,.5,.6,.9} do
        v:reset();if target==4 then v:zoom(2) end
        local x,y=p.top_left_corner_x+16*p.dim_x*frac,p.top_left_corner_y+16*p.dim_y*.55
        pointer(x,y);x,y=g.precise_mouse_x,g.precise_mouse_y
        check(v:map_pointer()~=nil,'Anchor must lie on the map')
        local wx,wy=c:screen_to_world(x,y,p.top_left_corner_x,p.top_left_corner_y,16)
        local cx=wx+(p.dim_x/2-(x-p.top_left_corner_x)/16)/target
        local cy=wy+(p.dim_y/2-(y-p.top_left_corner_y)/16)/target
        cx=c.width<=p.dim_x/target and c.width/2 or math.max(p.dim_x/(2*target),math.min(c.width-p.dim_x/(2*target),cx))
        cy=c.height<=p.dim_y/target and c.height/2 or math.max(p.dim_y/(2*target),math.min(c.height-p.dim_y/(2*target),cy))
        gui.simulateInput(v._native,'CONTEXT_SCROLL_UP')
        near(c.cx,cx);near(c.cy,cy);check(c.zoom==target,'Wheel did not zoom in')
        local ax,ay=c:screen_to_world(x,y,p.top_left_corner_x,p.top_left_corner_y,16)
        anchor_errors[#anchor_errors+1]={zoom=target,x=ax-wx,y=ay-wy,clamped=math.abs(cx-(wx+(p.dim_x/2-(x-p.top_left_corner_x)/16)/target))>1e-8}
        local _,_,source_x,source_y=c:native_binding()
        local sx,sy=input.source_point(c,p,x,y)
        local nx,ny=c:native_binding()
        near(nx-p.dim_x//2+(sx-p.top_left_corner_x)/16,ax,1/32)
        near(ny-p.dim_y//2+(sy-p.top_left_corner_y)/16,ay,1/32)
        gui.simulateInput(v._native,'CONTEXT_SCROLL_DOWN')
        check(c.zoom==target/2,'Wheel did not zoom out')
        gui.simulateInput(v._native,'CUSTOM_Z');check(c.zoom==target,'Z did not zoom at pointer')
    end
    end
    gui.simulateInput(v._native,'CONTEXT_SCROLL_UP');check(c.zoom==4,'Wheel exceeded 4x')
    for _,expected in ipairs{1,2,4} do
        gui.simulateInput(v._native,'CUSTOM_Z');check(c.zoom==expected,'Z cycle skipped a zoom level')
    end
    for _,expected in ipairs{2,1,1} do
        gui.simulateInput(v._native,'CONTEXT_SCROLL_DOWN');check(c.zoom==expected,'Wheel-down step or lower limit failed')
    end
    for _,z in ipairs{1,2,4} do
        for _,button in ipairs{'left','middle'} do
            v:reset();v:zoom(z);v.interactive=true
            local x,y=p.top_left_corner_x+16*p.dim_x*.4,p.top_left_corner_y+16*p.dim_y*.55
            local cx,cy=c.cx,c.cy
            press(button,x,y)
            pointer(x+64,y-32);v:onIdle()
            local ex,ey=cx-4/z,cy+2/z
            local vw,vh=p.dim_x/z,p.dim_y/z
            ex=c.width<=vw and c.width/2 or math.max(vw/2,math.min(c.width-vw/2,ex))
            ey=c.height<=vh and c.height/2 or math.max(vh/2,math.min(c.height-vh/2,ey))
            near(c.cx,ex,z==1 and .5 or 1e-8);near(c.cy,ey,z==1 and .5 or 1e-8)
            check(v.gesture and v.gesture.dragged,'Drag threshold was not crossed')
            release(button,x+64,y-32);check(v.gesture==nil,'Release did not end capture');untouched()
            -- A completed drag returning to its start is still never a click.
            press(button,x,y);pointer(x+32,y);v:onIdle();release(button,x,y);untouched()
        end
    end
    v:reset();v:zoom(test_zoom);v.interactive=false
    local x,y=p.top_left_corner_x+16*p.dim_x*.4,p.top_left_corner_y+16*p.dim_y*.55
    press('left',x,y);release('left',x+2,y+2);untouched()
    v.interactive=true
    press('left',x,y);release('left',-1,-1);check(v.gesture==nil,'Outside release retained capture');untouched()
    press('left',x,y);v:onResize(g.dimx,g.dimy);check(v.gesture==nil,'Resize retained capture');untouched()
    save{anchor_errors=anchor_errors,selection_suppressed=true}
    input.clear_buttons();v.interactive=false;v:reset();v:zoom(test_zoom)
elseif mode=='focus' then
    _G.worldmap_zoom_focus_test=nil
    check(b.status().window_focused,'Focus the test input first')
    v:reset();v:zoom(test_zoom);v.interactive=true
    local x,y=p.top_left_corner_x+16*p.dim_x*.4,p.top_left_corner_y+16*p.dim_y*.55
    press('left',x,y)
    local epoch=b.status().focus_epoch
    local old_idle,old_render=v.onIdle,v.render
    local function hold()pointer(x,y);e.mouse_lbut_down=1 end
    v.onIdle=function(self)hold();old_idle(self)end
    v.render=function(self,dc)hold();old_render(self,dc)end
    -- Both events are queued before the next Lua update. The epoch must
    -- cancel even though final focus has already returned.
    b.test_focus(false);b.test_focus(true)
    dfhack.timeout(4,'frames',function()
        v.onIdle,v.render=old_idle,old_render;input.clear_buttons()
        local ok,err=pcall(function()
            check(b.status().focus_epoch>epoch,'SDL loss event was not observed')
            check(v.gesture==nil,'Focus loss/regain retained a pending click');untouched()
            save{epoch_before=epoch,epoch_after=b.status().focus_epoch,selection_suppressed=true}
        end)
        v.interactive=false
        _G.worldmap_zoom_focus_test={ok=ok,error=err}
    end)
elseif mode=='resize' then
    _G.worldmap_zoom_resize_test=nil
    check(b.status().window_focused,'Focus the test input first')
    v:reset();v:zoom(test_zoom);v.interactive=true
    local x,y=math.floor(p.top_left_corner_x+16*p.dim_x*.4),math.floor(p.top_left_corner_y+16*p.dim_y*.55)
    press('left',x,y)
    local old_idle,old_render=v.onIdle,v.render
    local function hold()pointer(x,y);e.mouse_lbut_down=1 end
    v.onIdle=function(self)hold();old_idle(self)end
    v.render=function(self,dc)hold();old_render(self,dc)end
    b.test_window(1000,700,false)
    local attempts=0
    local function finish()
        attempts=attempts+1
        local status=b.status()
        if (status.output_width~=1000 or status.output_height~=700) and attempts<180 then
            dfhack.timeout(1,'frames',finish);return
        end
        v.onIdle,v.render=old_idle,old_render;input.clear_buttons()
        local ok,err=pcall(function()
            check(status.output_width==1000 and status.output_height==700,'Native resize did not finish')
            check(v.gesture==nil,'Resize retained a pending click')
            near(v.camera.cols,df.global.gps.main_map_port.dim_x)
            near(v.camera.rows,df.global.gps.main_map_port.dim_y)
            untouched();save{output={status.output_width,status.output_height},selection_suppressed=true}
        end)
        v.interactive=false
        _G.worldmap_zoom_resize_test={ok=ok,error=err}
    end
    dfhack.timeout(4,'frames',finish)
elseif mode=='exit' or mode=='disable' or mode=='unload' then
    _G.worldmap_zoom_unload_test=nil
    v:reset();v:zoom(test_zoom);v.interactive=true
    local x,y=math.floor(p.top_left_corner_x+16*p.dim_x*.4),math.floor(p.top_left_corner_y+16*p.dim_y*.55)
    press('left',x,y)
    local function finish()
        check(reqscript('gui/worldmap-zoom').view==nil,'Pending capture survived '..mode)
        check(v.gesture==nil and e.mouse_lbut_down==0,'Held input survived '..mode)
        untouched();save{selection_suppressed=true}
    end
    -- simulateInput restores the caller's saved mouse fields after returning,
    -- which would undo the cleanup under test. Deliver this keyboard event to
    -- the GUI handler with the held fields intact, as native feed does.
    if mode=='exit' then v:onInput{LEAVESCREEN=true};finish()
    elseif mode=='disable' then dfhack.run_script('worldmap-zoom','disable');finish()
    else
        dfhack.run_command('unload worldmap-zoom-render')
        dfhack.timeout(4,'frames',function()
            local ok,err=pcall(finish)
            _G.worldmap_zoom_unload_test={ok=ok,error=err}
        end)
    end
elseif mode=='select' or mode=='select1' or mode=='select4' then
    local xw,yw=v.context.id==1 and 25.5 or 70.5,v.context.id==1 and 62.5 or 56.5
    v:reset();v:zoom(mode=='select1' and 1 or mode=='select4' and 4 or 2);v.interactive=true
    if mode=='select4' then c.cx,c.cy=xw,yw;v:sync() end
    local x,y=c:world_to_screen(xw,yw,p.top_left_corner_x,p.top_left_corner_y,16)
    pointer(x,y);check(v:map_pointer()~=nil,'Selection target is covered by UI')
    local before=v.context.id==2 and #s.army_controller or 0
    press('left',x,y);untouched() -- must defer native selection until release
    release('left',x,y)
    check(reqscript('gui/worldmap-zoom').view==nil,'Native selection did not close magnifier')
    if v.context.id==1 then
        check(s.zoomed_in and s.zoom_cent_x==408 and s.zoom_cent_y==1000,'Wrong native embark target')
        check(s.embark_dx==4 and s.embark_dy==4 and not dfhack.isMapLoaded(),'Embark was altered or triggered')
        save{native_position={s.zoom_cent_x,s.zoom_cent_y},embark_dimensions={s.embark_dx,s.embark_dy}}
    else
        check(s.focus_site and s.focus_site.id==285,'Wrong native fortress site')
        check(#s.army_controller==before,'Native selection created an order')
        save{site=s.focus_site.id,army_controllers=#s.army_controller}
    end
else error('Expected standard, focus, resize, exit, disable, unload, select, select1, or select4')end
