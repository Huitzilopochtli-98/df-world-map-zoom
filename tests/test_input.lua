local Camera=require('worldmap-zoom.camera')
local input=require('worldmap-zoom.input')
local checks=0
local function equal(a,b) checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) checks=checks+1;assert(math.abs(a-b)<=1/32+1e-8) end
for _,dims in ipairs{{75,50},{63,44},{160,90}} do
    local c=Camera.new(257,257,dims[1],dims[2],100,100)
    local p={top_left_corner_x=17,top_left_corner_y=23,dim_x=dims[1],dim_y=dims[2]}
    for _,z in ipairs{1,2,4} do
        c:set_zoom(z)
        for _,pan in ipairs{0,1,1.3,-4.75} do
            c:pan(pan,pan)
            local nx,ny=c:native_binding()
            for _,point in ipairs{{17,23},{18,24},{200,300},{17+dims[1]*16-1,23+dims[2]*16-1}} do
                local x,y=input.source_point(c,p,point[1],point[2])
                local wx,wy=c:screen_to_world(point[1],point[2],17,23,16)
                near(nx-dims[1]//2+(x-17)/16,wx)
                near(ny-dims[2]//2+(y-23)/16,wy)
            end
        end
    end
    equal(input.inside(p,17,23),true)
    equal(input.inside(p,16,23),false)
    equal(input.inside(p,17+dims[1]*16,23),false)
end

-- Run restoration tests against isolated fake input globals.
local mock={global={gps={mouse_x=1,mouse_y=2,precise_mouse_x=8,precise_mouse_y=24,tile_pixel_x=8,tile_pixel_y=12},
    enabler={tracking_on=1,mouse_lbut=1,mouse_rbut=0,mouse_mbut=0,mouse_lbut_down=1,mouse_rbut_down=0,mouse_mbut_down=0}}}
local ok,err=pcall(function()
    local path=assert(package.searchpath('worldmap-zoom.input',package.path))
    local isolated=assert(loadfile(path,'t',setmetatable({df=mock},{__index=_G})))()
    local g,e=mock.global.gps,mock.global.enabler
    assert(not pcall(isolated.without_buttons,80,120,function()
        equal(g.mouse_x,10);equal(g.mouse_y,10);equal(e.mouse_lbut,0);equal(e.mouse_lbut_down,0)
        error('expected')
    end))
    equal(g.mouse_x,1);equal(g.mouse_y,2);equal(g.precise_mouse_x,8);equal(g.precise_mouse_y,24)
    equal(e.mouse_lbut,1);equal(e.mouse_lbut_down,1);equal(e.tracking_on,1)
    isolated.clear_buttons();equal(e.mouse_lbut,0);equal(e.mouse_lbut_down,0)
    assert(not pcall(isolated.click_at,80,120,function()
        equal(e.mouse_lbut,1);equal(e.mouse_lbut_down,1);equal(g.mouse_x,10)
        error('expected click failure')
    end))
    equal(e.mouse_lbut,0);equal(e.mouse_lbut_down,0)
    equal(g.mouse_x,1);equal(g.mouse_y,2);equal(g.precise_mouse_x,8);equal(g.precise_mouse_y,24)
end)
if not ok then error(err) end
print(('PASS %d inverse input and restoration checks'):format(checks))
