local M={}
local mouse_fields={'mouse_lbut','mouse_rbut','mouse_mbut','mouse_lbut_down','mouse_rbut_down','mouse_mbut_down'}

function M.inside(port,x,y)
    return x>=port.top_left_corner_x and y>=port.top_left_corner_y and
        x<port.top_left_corner_x+port.dim_x*16 and y<port.top_left_corner_y+port.dim_y*16
end

function M.source_point(camera,port,x,y)
    local _,_,sx,sy=camera:native_binding()
    return port.top_left_corner_x+math.floor(sx*16+.5)+(x-port.top_left_corner_x)/camera.zoom,
        port.top_left_corner_y+math.floor(sy*16+.5)+(y-port.top_left_corner_y)/camera.zoom
end

function M.with_pointer(x,y,fn)
    local g=df.global.gps
    local mx,my,px,py=g.mouse_x,g.mouse_y,g.precise_mouse_x,g.precise_mouse_y
    g.precise_mouse_x,g.precise_mouse_y=math.floor(x),math.floor(y)
    g.mouse_x,g.mouse_y=math.floor(x/g.tile_pixel_x),math.floor(y/g.tile_pixel_y)
    local ok,err=pcall(fn)
    g.mouse_x,g.mouse_y,g.precise_mouse_x,g.precise_mouse_y=mx,my,px,py
    if not ok then error(err) end
end

function M.without_buttons(x,y,fn)
    local e=df.global.enabler
    local saved={tracking_on=e.tracking_on}
    for _,k in ipairs(mouse_fields) do saved[k]=e[k];e[k]=0 end
    e.tracking_on=(x>=0 and y>=0) and 1 or 0
    local ok,err=pcall(M.with_pointer,x,y,fn)
    for _,k in ipairs(mouse_fields) do e[k]=saved[k] end
    e.tracking_on=saved.tracking_on
    if not ok then error(err) end
end

function M.clear_buttons()
    for _,k in ipairs(mouse_fields) do df.global.enabler[k]=0 end
end

function M.click_at(x,y,fn)
    local ok,err=pcall(M.with_pointer,x,y,function()
        local e=df.global.enabler
        e.mouse_lbut,e.mouse_lbut_down=1,1
        fn()
    end)
    M.clear_buttons()
    if not ok then error(err) end
end

return M
