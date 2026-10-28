-- Magnify the native high-level world map. Run: gui/worldmap-zoom
--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local Camera = require('worldmap-zoom.camera')
local context = require('worldmap-zoom.context')
local input = require('worldmap-zoom.input')
local Gesture = require('worldmap-zoom.gesture')
local ok_backend,backend = pcall(require,'plugins.worldmap-zoom-render')
if not ok_backend or type(backend.prepare)~='function' then
    qerror('The world map zoom renderer is missing or incompatible. Install the binary for Windows Steam DF 53.16 / DFHack 53.16-r3.')
end

ZoomScreen = defclass(ZoomScreen, gui.ZScreen)
ZoomScreen.ATTRS{
    focus_path='worldmap-zoom', defocusable=false, pass_mouse_clicks=false,
    pass_movement_keys=false, pass_pause=false, force_pause=false,initial_pause=true,
}

function ZoomScreen:init()
    self.interactive=false
    self.did_render_parent=false
    self.context = assert(context.get())
    local c, p = self.context, self.context.port
    self.camera = Camera.new(c.width,c.height,p.dim_x,p.dim_y,c.screen.region_cent_x,c.screen.region_cent_y)
    self:addviews{
        widgets.Window{
            view_id='controls', frame_title='World map zoom', frame={r=2,t=2,w=44,h=16},
            resizable=false,
            subviews={
                widgets.Label{frame={l=0,t=0}, text={{text=function() return ('%s  %dx | %s'):format(self.interactive and 'NATIVE SELECT' or 'INSPECTION',self.camera.zoom,c.name) end}}},
                widgets.TextButton{frame={l=0,t=2,w=10,h=1},label=' + Zoom ',on_activate=function() self:zoom(self.camera:next_zoom(1)) end},
                widgets.TextButton{frame={l=12,t=2,w=10,h=1},label=' - Zoom ',on_activate=function() self:zoom(self.camera:next_zoom(-1)) end},
                widgets.HotkeyLabel{frame={l=24,t=2},key='CUSTOM_Z',label='Cycle',on_activate=function() self:zoom_at_pointer(self.camera:next_zoom(1,true)) end},
                widgets.Label{frame={l=0,t=4},text='Drag L/M mouse or arrows/WASD to pan'},
                widgets.HotkeyLabel{frame={l=0,t=6,w=14},key='CUSTOM_R',label='Reset',on_activate=self:callback('reset')},
                widgets.HotkeyLabel{frame={l=24,t=6,w=14},key='LEAVESCREEN',label='Exit',on_activate=self:callback('dismiss')},
                widgets.HotkeyLabel{frame={l=0,t=8,w=40},key='CUSTOM_I',label=function() return 'Native selection: '..(self.interactive and 'on' or 'off') end,
                    on_activate=function() self.interactive=not self.interactive end},
                widgets.Label{frame={l=0,t=10},text={{text=function() return self.interactive and 'Short left click selects on release.' or 'Map clicks blocked; hover is mapped.' end}}},
                widgets.Label{frame={l=0,t=12},text='Wheel / Z: zoom at the map pointer'},
            },
        },
    }
    self:zoom(2)
end

function ZoomScreen:sync()
    local ok,applied=pcall(context.apply,self.context,self.camera,backend)
    if not ok or not applied then
        self:dismiss()
        if not ok then dfhack.printerr('World map zoom stopped: '..tostring(applied)) end
    end
end
function ZoomScreen:zoom(z) self.camera:set_zoom(z); self:sync() end
function ZoomScreen:reset() self.camera:reset(); self:sync() end

function ZoomScreen:map_pointer()
    if not self.did_render_parent or self:isMouseOver() then return end
    local g=df.global.gps
    if backend.ui_hit(g.mouse_x,g.mouse_y)~=false or
            not input.inside(self.context.port,g.precise_mouse_x,g.precise_mouse_y) then return end
    return g.precise_mouse_x,g.precise_mouse_y
end

function ZoomScreen:zoom_at_pointer(z)
    local x,y=self:map_pointer()
    if x then
        local p=self.context.port
        self.camera:set_zoom_at(z,x,y,p.top_left_corner_x,p.top_left_corner_y,16)
        self:sync()
    else self:zoom(z) end
end

function ZoomScreen:cancel_gesture()
    if self.gesture then self.gesture=nil;input.clear_buttons() end
end

function ZoomScreen:update_gesture(status)
    local gesture=self.gesture
    if not gesture then return end
    status=status or backend.status()
    local e,g=df.global.enabler,df.global.gps
    local x,y=g.precise_mouse_x,g.precise_mouse_y
    local down=e[gesture.button=='left' and 'mouse_lbut_down' or 'mouse_mbut_down']~=0
    local valid=self:hasFocus() and status.window_focused and status.focus_epoch==gesture.focus_epoch and
        e.mouse_focus and e.tracking_on~=0 and x>=0 and y>=0
    local before_x,before_y=self.camera.cx,self.camera.cy
    local action=gesture:update(x,y,down,valid,self:map_pointer()~=nil,self.camera)
    if self.camera.cx~=before_x or self.camera.cy~=before_y then self:sync() end
    if action=='click' or action=='done' or action=='cancel' then
        self.gesture=nil
        input.clear_buttons()
        if action=='click' and self.interactive and not self:isDismissed() then
            self:forward_click(gesture.x,gesture.y,true,gesture.focus_epoch)
        end
    end
end

function ZoomScreen:forward_click(x,y,in_map,focus_epoch)
    if in_map then x,y=input.source_point(self.camera,self.context.port,x,y)
    else self.ui_dirty=true end
    local native=self.context.screen
    local old_x,old_y=native.region_cent_x,native.region_cent_y
    -- Refresh native hover before the click. Native controls may consume their
    -- press in feed or logic. Never assign site/selection pointers ourselves.
    input.without_buttons(x,y,function()
        self._native.parent:logic()
        self._native.parent:render(dfhack.getTickCount())
    end)
    -- Hover refresh may cross a graphics update. Recheck before dispatching
    -- a deferred map click if a focus event arrived during that refresh.
    if focus_epoch then
        local status=backend.status()
        if not status.window_focused or status.focus_epoch~=focus_epoch then return end
    end
    input.click_at(x,y,function()
        self:sendInputToParent{_MOUSE_L=true,_MOUSE_L_DOWN=true}
        local live=context.get()
        if live and live.screen==native then native:logic() end
    end)
    local live,why=context.get()
    if not live or live.screen~=self.context.screen then
        self:dismiss()
        dfhack.println('World map zoom closed: '..(why or 'native screen changed'))
    elseif native.region_cent_x~=old_x or native.region_cent_y~=old_y then
        self.camera.cx=native.region_cent_x+(self.camera.cols%2)/2
        self.camera.cy=native.region_cent_y+(self.camera.rows%2)/2
        self:sync()
    end
end

function ZoomScreen:parent_mouse()
    if not self.did_render_parent or self:isMouseOver() then return -1,-1 end
    local g=df.global.gps
    local x,y=g.precise_mouse_x,g.precise_mouse_y
    local ui=backend.ui_hit(g.mouse_x,g.mouse_y)
    if ui==nil then return -1,-1 end
    if not ui and input.inside(self.context.port,x,y) then
        return input.source_point(self.camera,self.context.port,x,y)
    end
    return x,y
end

function ZoomScreen:onIdle()
    local ok,status=pcall(backend.status)
    if not ok or not status.ready then self:dismiss();return end
    if status.error~='' then self:dismiss();dfhack.printerr(status.error);return end
    local live = context.get()
    if not live or live.screen ~= self.context.screen then self:dismiss();return end
    self.context.port=live.port
    if live.port.dim_x~=self.camera.cols or live.port.dim_y~=self.camera.rows then self:cancel_gesture() end
    self:update_gesture(status)
    if self:isDismissed() then return end
    local x,y=self:parent_mouse()
    input.without_buttons(x,y,function() self._native.parent:logic() end)
end

function ZoomScreen:onResize(w,h)
    self:cancel_gesture()
    gui.Screen.onResize(self,w,h)
end

function ZoomScreen:render(dc)
    local live = context.get()
    if not live or live.screen ~= self.context.screen then self:dismiss();return end
    local p = live.port
    self.context.port=p
    if p.dim_x ~= self.camera.cols or p.dim_y ~= self.camera.rows then
        self:cancel_gesture()
        self.camera:resize(p.dim_x,p.dim_y);self:sync();self.ui_dirty=true
        if self:isDismissed() then return end
    end
    -- Capture controls with a neutral pointer so hover text never becomes a
    -- clickable UI region. Refresh when an actual UI action or resize occurs.
    local rebuild=not self.did_render_parent or self.ui_dirty or self.ui_cols~=df.global.gps.dimx or self.ui_rows~=df.global.gps.dimy
    if rebuild then
        input.without_buttons(-1,-1,function() self:renderParent() end)
        backend.snapshot_ui()
        self.did_render_parent=true;self.ui_dirty=false
        self.ui_cols,self.ui_rows=df.global.gps.dimx,df.global.gps.dimy
    end
    local x,y=self:parent_mouse()
    if not rebuild or x>=0 or y>=0 then
        input.without_buttons(x,y,function() self:renderParent() end)
    end
    gui.Screen.render(self,dc)
end

function ZoomScreen:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R then self:dismiss();return true end
    if self.gesture then self:update_gesture();return true end
    if gui.Screen.onInput(self,keys) then return true end
    if keys._MOUSE_L or keys._MOUSE_M then
        if not self.did_render_parent then return true end
        local g=df.global.gps
        local ui=backend.ui_hit(g.mouse_x,g.mouse_y)
        if ui==nil then return true end
        local x,y=g.precise_mouse_x,g.precise_mouse_y
        local in_map=input.inside(self.context.port,x,y)
        if not ui and in_map then
            local status=backend.status()
            if status.window_focused then
                self.gesture=Gesture.new(keys._MOUSE_L and 'left' or 'middle',x,y,self.camera)
                self.gesture.focus_epoch=status.focus_epoch
            end
        elseif keys._MOUSE_L then
            self:forward_click(x,y,false)
        end
        return true
    end
    local dx,dy=0,0
    if keys.CURSOR_LEFT or keys.CUSTOM_A then dx=-2 end
    if keys.CURSOR_RIGHT or keys.CUSTOM_D then dx=2 end
    if keys.CURSOR_UP or keys.CUSTOM_W then dy=-2 end
    if keys.CURSOR_DOWN or keys.CUSTOM_S then dy=2 end
    if dx~=0 or dy~=0 then self.camera:pan(dx,dy);self:sync()
    elseif keys.CONTEXT_SCROLL_UP or keys.STRING_A043 then self:zoom_at_pointer(self.camera:next_zoom(1))
    elseif keys.CONTEXT_SCROLL_DOWN or keys.STRING_A045 then self:zoom_at_pointer(self.camera:next_zoom(-1)) end
    return true
end

function ZoomScreen:onDismiss()
    self:cancel_gesture()
    pcall(backend.set_camera,false,0,1,0,0)
    df.global.gps.force_full_display_count=2
    view=nil
end

if dfhack_flags.module then return end
local args={...}
launch_generation=(launch_generation or 0)+1
local generation=launch_generation
if args[1]=='disable' then if view then view:dismiss() end;return end
if dfhack.getGitCommit()~='0bf381cc1615656acf756e6e67573fffca715125' or
        dfhack.getGitXmlCommit()~='d8ff8a6326db37c11dc4173fadcf30b56e51b42d' then
    qerror('This release supports DFHack 53.16-r3 with its original structure definitions. Rebuild and retest for your installed version.')
end
local c,why=context.get()
if not c then qerror(why) end
local function open_when_ready(attempt)
    if generation~=launch_generation then return end
    local live,why=context.get()
    if not live then dfhack.printerr(why);return end
    if backend.prepare() then
        view=view and view:raise() or ZoomScreen{}:show()
    elseif attempt<60 then
        dfhack.timeout(1,'frames',function() open_when_ready(attempt+1) end)
    else
        dfhack.printerr('World map zoom could not attach its renderer: '..backend.status().error)
    end
end
open_when_ready(0)
