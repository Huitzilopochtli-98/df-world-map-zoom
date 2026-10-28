-- Pure pointer gesture state. Capture starts only over a verified map cell.
local Gesture = {}
Gesture.__index = Gesture

function Gesture.new(button, x, y, camera)
    assert(button == 'left' or button == 'middle')
    return setmetatable({button=button,x=x,y=y,cx=camera.cx,cy=camera.cy,
        zoom=camera.zoom,cols=camera.cols,rows=camera.rows,dragged=false},Gesture)
end

-- Returns 'pending', 'pan', 'click', 'done', or 'cancel'. Once the six-pixel
-- threshold is crossed, returning to the press position can never make a click.
function Gesture:update(x, y, down, valid, inside_map, camera)
    if self.finished then return 'done' end
    if not valid or camera.zoom ~= self.zoom or camera.cols ~= self.cols or
            camera.rows ~= self.rows then
        self.finished=true
        return 'cancel'
    end
    local dx,dy=x-self.x,y-self.y
    if dx*dx+dy*dy >= 36 then self.dragged=true end
    if self.dragged then
        camera.cx=self.cx-dx/(16*self.zoom)
        camera.cy=self.cy-dy/(16*self.zoom)
        camera:constrain()
    end
    if not down then
        self.finished=true
        if not self.dragged and self.button=='left' and inside_map then return 'click' end
        return 'done'
    end
    return self.dragged and 'pan' or 'pending'
end

return Gesture
