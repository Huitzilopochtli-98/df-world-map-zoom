local Camera=require('worldmap-zoom.camera')
local Gesture=require('worldmap-zoom.gesture')
local checks=0
local function eq(a,b)checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function near(a,b,epsilon)checks=checks+1;assert(math.abs(a-b)<=(epsilon or 1e-8),tostring(a)..' ~= '..tostring(b))end

-- Independent anchor equation, with nonzero map origins and odd/even ports.
for _,dims in ipairs{{75,50},{63,44},{160,90}} do
    for _,frac in ipairs{.1,.25,.5,.7,.9} do
        local c=Camera.new(257,257,dims[1],dims[2],128,128)
        local px,py=17+16*dims[1]*frac,23+16*dims[2]*(1-frac)
        local before_x,before_y=c:screen_to_world(px,py,17,23,16)
        c:set_zoom_at(2,px,py,17,23,16);c:native_binding()
        local after_x,after_y=c:screen_to_world(px,py,17,23,16)
        near(before_x,after_x);near(before_y,after_y)
        -- Repeating a wheel-up event at the maximum zoom is a no-op.
        local cx,cy=c.cx,c.cy
        c:set_zoom_at(2,px,py,17,23,16);near(cx,c.cx);near(cy,c.cy)
        c:pan(1.3,-2.7)
        before_x,before_y=c:screen_to_world(px,py,17,23,16)
        c:set_zoom_at(1,px,py,17,23,16);c:native_binding()
        after_x,after_y=c:screen_to_world(px,py,17,23,16)
        -- DF's unscaled camera is an integral tile center.
        near(before_x,after_x,.5+1e-8);near(before_y,after_y,.5+1e-8)
    end
end
for _,world in ipairs{17,33,65,129,257} do
    for _,z in ipairs{1,2,4} do
        local c=Camera.new(world,world,75,50,0,world-1)
        c:set_zoom(z==1 and 2 or 1)
        c:set_zoom_at(z,0,800,0,0,16)
        local vw,vh=75/z,50/z
        if world<=vw then near(c.cx,world/2)else eq(c:left()>=0,true);eq(c:left()+vw<=world,true)end
        if world<=vh then near(c.cy,world/2)else eq(c:top()>=0,true);eq(c:top()+vh<=world,true)end
    end
end
local invalid=Camera.new(257,257,75,50,128,128)
eq(pcall(invalid.set_zoom_at,invalid,3,0,0,0,0,16),false)
eq(pcall(invalid.set_zoom_at,invalid,2,0/0,0,0,0,16),false)
eq(pcall(invalid.set_zoom_at,invalid,2,0,0,0,0,0),false)

for _,z in ipairs{1,2,4} do
    for _,button in ipairs{'left','middle'} do
        local c=Camera.new(257,257,75,50,128,128);c:set_zoom(z)
        local cx,cy=c.cx,c.cy
        local g=Gesture.new(button,200,300,c)
        eq(g:update(203,302,true,true,true,c),'pending');near(c.cx,cx);near(c.cy,cy)
        eq(g:update(232,284,true,true,true,c),'pan')
        near(c.cx,cx-2/z);near(c.cy,cy+1/z)
        -- Returning to the start does not resurrect a click.
        eq(g:update(200,300,false,true,true,c),'done');near(c.cx,cx);near(c.cy,cy)
        eq(g:update(200,300,false,true,true,c),'done')
        g=Gesture.new(button,200,300,c)
        eq(g:update(202,302,false,true,true,c),button=='left' and 'click' or 'done')
        g=Gesture.new(button,200,300,c)
        eq(g:update(200,300,false,true,false,c),'done')
        g=Gesture.new(button,200,300,c)
        eq(g:update(240,300,true,false,true,c),'cancel') -- lost focus/pointer
        eq(g:update(240,300,false,true,true,c),'done')
        g=Gesture.new(button,200,300,c);c:resize(76,50)
        eq(g:update(201,300,false,true,true,c),'cancel')
        g=Gesture.new(button,200,300,c);c:set_zoom(z==1 and 2 or 1)
        eq(g:update(201,300,false,true,true,c),'cancel')
    end
end
local c=Camera.new(257,257,75,50,128,128);c:set_zoom(2)
local g=Gesture.new('left',200,300,c)
eq(g:update(206,300,true,true,true,c),'pan') -- exact threshold
eq(g:update(8000,8000,false,true,false,c),'done')
near(c:left(),0);near(c:top(),0)

-- Anchor every transition in the three-level control, including zooming out
-- from 4x to 2x and cycling directly from 4x to the native 1x grid.
for _,dims in ipairs{{75,50},{63,44},{160,90}} do
    for _,from in ipairs{1,2,4} do
        for _,to in ipairs{1,2,4} do
            local a=Camera.new(257,257,dims[1],dims[2],128,128);a:set_zoom(from)
            local px,py=17+16*dims[1]*.37,23+16*dims[2]*.61
            local wx,wy=a:screen_to_world(px,py,17,23,16)
            a:set_zoom_at(to,px,py,17,23,16);a:native_binding()
            local ax,ay=a:screen_to_world(px,py,17,23,16)
            near(ax,wx,to==1 and .5+1e-8 or 1e-8)
            near(ay,wy,to==1 and .5+1e-8 or 1e-8)
        end
    end
end
local levels=Camera.new(257,257,75,50,128,128)
for _,expected in ipairs{2,4,1,2,4,1} do levels:set_zoom(levels:next_zoom(1,true));eq(levels.zoom,expected)end
levels:set_zoom(4);eq(levels:next_zoom(1),4);eq(levels:next_zoom(-1),2)
levels:set_zoom(1);eq(levels:next_zoom(-1),1)
print(('PASS %d pointer-anchor and drag/click lifecycle checks'):format(checks))
