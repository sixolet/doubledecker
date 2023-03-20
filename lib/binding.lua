local Binding = {
    bindings = {},
    receivers = {},
}

Binding.__index = Binding


function Binding:static_index(page, row, col, layer)
    -- print(page, row, col, layer)
    return (layer - 1) * 64 + (page - 1) * 16 + (row - 1) * 4 + (col - 1) + 1
end

function Binding:index()
    return self:static_index(self.page, self.row, self.col, self.layer)
end

-- Look for the binding in bindings.
-- If it is there, return it.
-- If not register it.
function Binding:at(page, row, col, layer, descriptor)
    local index = self:static_index(page, row, col, layer)
    local o = self.bindings[index]
    if not o then
        o = {
            page = page,
            row = row,
            col = col,
            layer = layer,
            descriptor = descriptor,
        }
        setmetatable(o, self)
        self.bindings[index] = o
    end
    return o
end

function Binding:draw(x, y, selected)
    if self.display_value then
        screen.level(1)
        screen.rect(x, y + 2, self.display_value * 32, -7)
        screen.fill()
    end
    if selected then
        screen.level(16)
    else
        screen.level(8)
    end
    screen.move(x, y)
    screen.text(self.descriptor)
end

function Binding:get(page, row, col, layer)
    local index = self:static_index(page, row, col, layer)
    local o = self.bindings[index]
    return o
end

function Binding:add_listener(f)
    table.insert(self.receivers, f)
end

function Binding:clear()
    self.bindings = {}
    self.receivers = {}
end

function Binding:communicate(normalized)
    self.display_value = normalized
    for _, f in ipairs(self.receivers) do
        f(self.page, self.row, self.col, self.layer, normalized)
    end
end

function Binding:set(normalized)
    if self.param then
        if self.param.t == 3 or self.param.t == 5 then
            self.param:set_raw(normalized)
        elseif self.param.t == 2 then
            self.param:set(
                util.clamp(
                    math.floor(self.param.count * normalized) + 1,
                    1,
                    self.param.count
                )
            )
        end
    end
end

return Binding
