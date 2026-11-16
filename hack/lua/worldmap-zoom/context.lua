local M = {}

function M.get_screen()
    local s = dfhack.gui.getDFViewscreen(true)
    local id, name
    if df.viewscreen_choose_start_sitest:is_instance(s) then
        if s.animating_quick_start_timer>0 or s.setting_up_map_timer>0 then
            return nil, 'Wait for the native embark transition to finish.'
        end
        if s.zoomed_in then return nil, 'Return to the high-level embark map first.' end
        if s.page~=df.choose_start_site_view_mode.Biome then
            return nil, 'Return to the normal high-level embark map first.'
        end
        id, name = 1, 'embark'
    elseif df.viewscreen_worldst:is_instance(s) then
        if s.view_mode ~= df.world_view_mode_type.NORMAL then
            return nil, 'Return to the normal fortress world map first.'
        end
        id, name = 2, 'fortress world'
    else
        return nil, 'Open the high-level embark map or the fortress world map first.'
    end
    return {screen=s,id=id,name=name}
end

function M.get()
    local c, why = M.get_screen()
    if not c then return nil, why end
    local p = df.global.gps.main_map_port
    local w = df.global.world.world_data
    if not p or not p.flag.active or not w or p.dim_x < 1 or p.dim_y < 1 then
        return nil, 'The native world map is not ready.'
    end
    c.port, c.width, c.height = p, w.world_width, w.world_height
    return c
end

function M.apply(context, camera, backend)
    local live = M.get()
    if not live or live.screen ~= context.screen then return false end
    local nx, ny, ox, oy = camera:native_binding()
    -- This is the same high-level camera path as this release's edgescroll
    -- plugin. It does not change selection, embark dimensions, sites or orders.
    context.screen.region_cent_x, context.screen.region_cent_y = nx, ny
    backend.set_camera(true, context.id, camera.zoom, ox, oy)
    return true
end

return M
