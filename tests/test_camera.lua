local Camera = require('worldmap-zoom.camera')
local checks = 0
local function near(a,b)
    checks=checks+1
    assert(math.abs(a-b)<1e-8,('%s ~= %s'):format(a,b))
end
for _,world in ipairs{17,33,65,129,257} do
    for _,cols in ipairs{40,75,96} do
        for _,rows in ipairs{25,50,67} do
            local c=Camera.new(world,world,cols,rows,world//2,world//2)
            for _,zoom in ipairs{1,2,4} do
                c:set_zoom(zoom)
                for _,delta in ipairs{-10000,1,13,10000,-6} do
                    c:pan(delta,-delta)
                    local nx,ny,ox,oy=c:native_binding()
                    assert(nx>=0 and nx<world and ny>=0 and ny<world)
                    assert(ox>=0 and ox<=cols*(1-1/zoom))
                    assert(oy>=0 and oy<=rows*(1-1/zoom))
                    near(c:left(),nx-cols//2+ox)
                    near(c:top(),ny-rows//2+oy)
                    for _,point in ipairs{{0,0},{.5,.5},{world-1,world-1},{world/2,world/2}} do
                        local sx,sy=c:world_to_screen(point[1],point[2],17,23,16)
                        local x,y=c:screen_to_world(sx,sy,17,23,16)
                        near(x,point[1]);near(y,point[2])
                    end
                end
            end
            c:reset()
            local nx,ny,ox,oy=c:native_binding()
            near(nx,world//2);near(ny,world//2);near(ox,0);near(oy,0)
        end
    end
end
local c=Camera.new(129,129,75,50,64,64)
assert(not pcall(c.set_zoom,c,3))
assert(not pcall(c.pan,c,0/0,0))
assert(not pcall(c.pan,c,math.huge,0))
print(('PASS %d coordinate checks; invalid camera values rejected'):format(checks))
