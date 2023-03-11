local conf = require('doubledecker/lib/mftconf/lib/mftconf')

local MFT = {
    turn_action = function(page, row, col, layer, val) end,
    page_action = function(page) end,
    push_action = function(page, row, col, z) end,
}

function MFT:init(confname)
    for i = 1, #midi.vports do -- query all ports
        if midi.vports[i].name == "Midi Fighter Twister" then
            self.conn = midi.connect(i) -- connect the MFT
            if confname then
                conf.load_conf(self.conn, confname)
            end
            self.conn.event = function(data)
                self:process_midi(data)
            end
        end
    end
end

function MFT:set_rgb_level(page, row, col, val)
    if not self.conn then return end
    self.conn:cc(
        16 * (page - 1) + 4 * (row - 1) + (col - 1),
        17 + util.clamp(math.floor(val * 30), 0, 30),
        3)
end

function MFT:process_midi(data)
    local d = midi.to_msg(data)
    if d.type == "cc" then
        if not self.turn_action then return end
        --print(d.ch, d.cc, d.val)
        local page = math.floor(d.cc / 16) + 1
        local row = math.floor((d.cc % 16) / 4) + 1
        local col = d.cc % 4 + 1
        local layer
        if d.ch == 1 then layer = 1 end
        if d.ch == 5 then layer = 2 end
        if layer then
            self.turn_action(page, row, col, layer, d.val)
        elseif d.ch == 4 then
            if d.cc < 4 and d.val > 0 then
                self.page_action(d.cc + 1)
            end
        elseif d.ch == 2 then
            self.push_action(page, row, col, d.val > 0 and 1 or 0)
        else
            tab.print(d)
        end
    elseif d.type == "note_on" then
        tab.print(d)
    else
        tab.print(d)
    end
end

function MFT:page(n)
    if not self.conn then return end
    self.conn:note_on(n - 1, 127, 4)
end

function MFT:set_position(page, row, col, layer, value)
    if not self.conn then return end
    self.conn:cc(16 * (page - 1) + 4 * (row - 1) + (col - 1), value, layer == 1 and 1 or 5)
end

return MFT
