-- Continuous edge coordinates, in world tiles. No DF or renderer dependencies.
local Camera = {}
Camera.__index = Camera
local function clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
local function finite(v) return type(v) == 'number' and v == v and math.abs(v) < math.huge end

function Camera.new(width, height, cols, rows, native_x, native_y)
    assert(width > 0 and height > 0 and cols > 0 and rows > 0)
    local self = setmetatable({width=width,height=height,cols=cols,rows=rows,zoom=1}, Camera)
    self.cx = native_x + (cols % 2) / 2
    self.cy = native_y + (rows % 2) / 2
    self.initial_x, self.initial_y = self.cx, self.cy
    return self
end

function Camera:constrain()
    local vw, vh = self.cols / self.zoom, self.rows / self.zoom
    self.cx = self.width <= vw and self.width / 2 or clamp(self.cx, vw / 2, self.width - vw / 2)
    self.cy = self.height <= vh and self.height / 2 or clamp(self.cy, vh / 2, self.height - vh / 2)
end

function Camera:set_zoom(z)
    assert(z == 1 or z == 2 or z == 4, 'Only 1x, 2x, and 4x are supported')
    self.zoom = z
    self:constrain()
end

function Camera:set_zoom_at(z, x, y, ox, oy, tile_size)
    assert(z == 1 or z == 2 or z == 4, 'Only 1x, 2x, and 4x are supported')
    assert(finite(x) and finite(y) and finite(ox) and finite(oy) and
        finite(tile_size) and tile_size > 0)
    if self.zoom == z then return end
    local wx, wy = self:screen_to_world(x, y, ox, oy, tile_size)
    self.zoom = z
    self.cx = wx + (self.cols / 2 - (x - ox) / tile_size) / z
    self.cy = wy + (self.rows / 2 - (y - oy) / tile_size) / z
    self:constrain()
end

function Camera:pan(dx, dy)
    assert(finite(dx) and finite(dy))
    self.cx, self.cy = self.cx + dx, self.cy + dy
    self:constrain()
end

function Camera:next_zoom(direction, cycle)
    assert(direction == 1 or direction == -1)
    local z = self.zoom * (direction == 1 and 2 or .5)
    if cycle and z > 4 then return 1 end
    return clamp(z, 1, 4)
end

function Camera:reset()
    self.zoom, self.cx, self.cy = 1, self.initial_x, self.initial_y
end

function Camera:resize(cols, rows)
    assert(cols > 0 and rows > 0)
    self.cols, self.rows = cols, rows
    self:constrain()
end

function Camera:left() return self.cx - self.cols / (2 * self.zoom) end
function Camera:top() return self.cy - self.rows / (2 * self.zoom) end
function Camera:screen_to_world(x, y, ox, oy, tile_size)
    return self:left() + (x - ox) / (tile_size * self.zoom),
           self:top() + (y - oy) / (tile_size * self.zoom)
end
function Camera:world_to_screen(x, y, ox, oy, tile_size)
    return ox + (x - self:left()) * tile_size * self.zoom,
           oy + (y - self:top()) * tile_size * self.zoom
end

function Camera:native_binding()
    local nx = clamp(math.floor(self.cx - (self.cols % 2) / 2 + .5), 0, self.width - 1)
    local ny = clamp(math.floor(self.cy - (self.rows % 2) / 2 + .5), 0, self.height - 1)
    local left, top = nx - math.floor(self.cols / 2), ny - math.floor(self.rows / 2)
    if self.zoom == 1 then
        -- The unmodified native camera uses integral tile centers.
        self.cx, self.cy = left + self.cols / 2, top + self.rows / 2
        return nx, ny, 0, 0
    end
    return nx, ny,
        clamp(self:left() - left, 0, self.cols * (1 - 1 / self.zoom)),
        clamp(self:top() - top, 0, self.rows * (1 - 1 / self.zoom))
end

return Camera
