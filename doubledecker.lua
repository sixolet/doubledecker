local dd = require('doubledecker/lib/mod')
local nb = require('doubledecker/lib/nb/lib/nb')
local bind = require('doubledecker/lib/binding')

mft = require('doubledecker/lib/mft')

-- most of this code is copied/adapted from nbin

local midi_device = {} -- container for connected midi devices
local midi_device_names = { "none" }

local target = nil

local old_event = nil

local notes = {}
local bookeeping = {}
for i = 0, 16 do
    notes[i] = {}
end

local page = 1
local row = 1
local col = 1

local function find_region(note, chan)
    if note and bookeeping[note] then
        for r, ch in pairs(bookeeping[note]) do
            if ch == chan then
                return r
            end
        end
    end
    return 0
end

local function process_midi(data)
    local d = midi.to_msg(data)

    local region = find_region(d.note, d.ch)

    local mod_note
    if d.note then
        mod_note = region * 128 + d.note
    end

    if d.type == "note_on" then
        if not bookeeping[d.note] then
            bookeeping[d.note] = {}
        end
        -- find an unused region
        while bookeeping[d.note][region] ~= nil do
            region = region + 1
        end
        mod_note = region * 128 + d.note
        bookeeping[d.note][region] = d.ch
        -- print("on", mod_note, region, d.ch)
        dd:note_on(mod_note, d.vel / 127)
        notes[d.ch][d.note] = dd
    elseif d.type == "note_off" then
        if notes[d.ch][d.note] ~= nil then
            -- print("off", mod_note, region, d.ch)
            dd:note_off(mod_note)
            bookeeping[d.note][region] = nil
            notes[d.ch][d.note] = nil
        end
    elseif d.type == "pitchbend" then
        local bend_st = (util.round(d.val / 2)) / 8192 * 2 - 1 -- Convert to -1 to 1
        for n, _ in pairs(notes[d.ch]) do
            local r = find_region(n, d.ch)
            dd:pitch_bend(r * 128 + n, bend_st * params:get("bend range"))
        end
    elseif d.type == "channel_pressure" then
        local normalized = d.val / 127
        for n, _ in pairs(notes[d.ch]) do
            local r = find_region(n, d.ch)
            dd:modulate_note(r * 128 + n, "pressure", normalized)
        end
    elseif d.type == "key_pressure" then
        local normalized = d.val / 127
        if notes[d.ch][d.note] ~= nil then
            dd:modulate_note(mod_note, "pressure", normalized)
        end
    end
end

local function midi_target(x)
    if x > 1 then
        if target ~= nil then
            midi_device[target].event = old_event
        end
        target = x - 1
        old_event = midi_device[target].event
        midi_device[target].event = process_midi
    else
        if target ~= nil then
            midi_device[target].event = old_event
        end
        target = nil
    end
end

local screen_dirty = true

function redraw()
    screen.clear()
    for r = 1, 4 do
        for c = 1, 4 do
            for l = 1, 2 do
                local layer = bind:get(page, r, c, l)
                if layer then
                    local x = (c - 1) * 32
                    local y = (r - 1) * 16 + l * 7
                    layer:draw(x, y, r == row and c == col)
                end
            end
        end
    end
    screen.update()
end

local function mft_shade_page(n)
    if page == 1 or page == 2 then
        for row = 1, 4 do
            for col = 1, 4 do
                mft:set_rgb_level(page, row, col, page == 2 and (0.5 + row/8) or (1 - row/8))
            end
        end
    end
end

local function set_page(n)
    mft:page(n)
    mft_shade_page(n)
    page = n
end

function enc(n, d)
    if n == 1 then
        set_page(util.wrap(page + d, 1, 3))
    elseif n == 2 or n == 3 then
        local b = bind:get(page, row, col, n - 1)
        if b.param then
            b.param:delta(d)
        end
    end
    screen_dirty = true
end

function key(n, z)
    if z == 1 and n == 2 then
        row = util.wrap(row+1, 1, 4)
    elseif z == 1 and n == 3 then
        col = util.wrap(col+1, 1, 4)
    end
    screen_dirty = true
end


function init()
    nb:init()
    mft:init('/home/we/dust/code/doubledecker/lib/dd.mfs')
    mft_shade_page(1)
    mft_shade_page(2)
    mft:page(1)
    mft.turn_action = function(page, row, col, layer, val)
        local b = bind:get(page, row, col, layer)
        if b then
            b:set(val / 128)
        end
    end
    mft.page_action = function(p)
        page = p
        screen_dirty = true
        mft_shade_page(p)
    end
    osc.send(
        { "localhost", 57120 },
        "/doubledecker/init",
        {});
    for i = 1, #midi.vports do -- query all ports
        midi_device[i] = midi.connect(i) -- connect each device
        table.insert(midi_device_names, "port " .. i .. ": " .. util.trim_string_to_width(midi_device[i].name, 40)) -- register its name
    end
    params:add_option("midi source", "midi source", midi_device_names, 1, false)
    params:add_number("bend range", "bend range", 2, 48, 12)
    params:set_action("midi source", midi_target)
    nb:add_player_params()
    dd:active()
    bind:add_listener(function(page, row, col, layer, normalized)
        screen_dirty = true
    end)
    bind:add_listener(function(page, row, col, layer, normalized)
        mft:set_position(page, row, col, layer, math.floor(127 * normalized))
    end)
    params:read()
    clock.run(function()
        clock.sleep(1 / 15)
        params:bang()
        while true do
            if screen_dirty then
                redraw()
                screen_dirty = false
            end
            clock.sleep(1 / 15)
        end
    end)
end
