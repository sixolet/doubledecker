-- Doubledecker
--
-- Copies Deckard's Dream
-- Copies Yamaha CS-80
--
-- by @sixolet
--
-- This is a midi synth.
-- Plug in your midi controller.
--
-- e1 navigates pages.
-- k2 and k3 navigate params.
-- e2 and e3 modify them.
--
-- But that is tedious.
--
-- If you have a
-- Midi Fighter Twister
-- Plug that in now.
-- (will override its config)
--
-- Or use a grid.

local dd = require('doubledecker/lib/mod')
local nb = require('doubledecker/lib/nb/lib/nb')
local bind = require('doubledecker/lib/binding')

local g = grid.connect()

mft = require('doubledecker/lib/mft')

-- much of this code is copied/adapted from nbin

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
                mft:set_rgb_level(page, row, col, page == 2 and (0.5 + row / 8) or (1 - row / 8))
            end
        end
    end
end

local function set_page(n)
    mft:page(n)
    mft_shade_page(n)
    page = n
    screen_dirty = true
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
        row = util.wrap(row + 1, 1, 4)
    elseif z == 1 and n == 3 then
        col = util.wrap(col + 1, 1, 4)
    end
    screen_dirty = true
end

function g.key(x, y, z)
    if x == 1 and y == 8 and z == 1 then
        if params:get("doubledecker_grid_mode") == 1 then
            params:set("doubledecker_grid_mode", 2)
        else
            params:set("doubledecker_grid_mode", 1)
        end
        return
    end
    if params:get("doubledecker_grid_mode") == 1 then
        local note = params:get("doubledecker_grid_lowest")
        note = note + params:get("doubledecker_dx") * x
        note = note + params:get("doubledecker_dy") * (8 - y)
        if z == 1 then
            dd:note_on(note, 0.7)
        else
            dd:note_off(note)
        end
    elseif params:get("doubledecker_grid_mode") == 2 then
        local p, r, c
        if x <= 4 and y <= 4 then
            p = 1
            r = y
            c = x
        elseif x >= 4 and x <= 7 and y >= 5 then
            p = 3
            r = y - 4
            c = x - 3
        elseif x >= 7 and x <= 10 and y <= 4 then
            p = 2
            r = y
            c = x - 6
        elseif x == 12 or x == 13 then
            local b = bind:get(page, row, col, 1)
            b:set((9 - y) / 8)
            screen_dirty = true
        elseif x == 15 or x == 16 then
            local b = bind:get(page, row, col, 2)
            b:set((9 - y) / 8)
            screen_dirty = true
        end
        if p then
            row = r
            col = c
            set_page(p)
        end
    end
end

local bipolars = {
    doubledecker_detune = true,
    doubledecker_brilliance = true,
    doubledecker_resonance = true,
    doubledecker_filter_keyfollow_lo_1 = true,
    doubledecker_filter_keyfollow_hi_1 = true,
    doubledecker_amp_keyfollow_lo_1 = true,
    doubledecker_amp_keyfollow_hi_1 = true,
    doubledecker_filter_keyfollow_lo_2 = true,
    doubledecker_filter_keyfollow_hi_2 = true,
    doubledecker_amp_keyfollow_lo_2 = true,
    doubledecker_amp_keyfollow_hi_2 = true,
    doubledecker_filter_init_1 = true,
    doubledecker_filter_init_2 = true,
    doubledecker_filter_attack_level_1 = true,
    doubledecker_filter_attack_level_2 = true,
}

local function grid_redraw()
    g:all(0)
    if params:get("doubledecker_grid_mode") == 1 then
        for x = 1, 16, 1 do
            for y = 1, 8, 1 do
                local note = params:get("doubledecker_grid_lowest")
                note = note + params:get("doubledecker_dx") * x
                note = note + params:get("doubledecker_dy") * (8 - y)
                local hs = note % 12
                if hs == 0 then
                    g:led(x, y, 6)
                elseif hs == 2 or hs == 4 or hs == 5 or hs == 7 or hs == 9 or hs == 11 then
                    g:led(x, y, 3)
                end
            end
        end
    elseif params:get("doubledecker_grid_mode") == 2 then
        for i, p in ipairs { 1, 3, 2 } do
            for r = 1, 4 do
                for c = 1, 4 do
                    local b = bind:get(p, r, c, 1)
                    if b then
                        local x = (i - 1) * 3 + c
                        local y = r
                        if p == 3 then y = y + 4 end
                        g:led(x, y, math.floor(14 * (b.display_value or 0) + 1))
                        if p == page and r == row and c == col then
                            g:led(x, y, 15)
                        end
                    end
                end
            end
        end
        for layer = 1, 2 do
            local b = bind:get(page, row, col, layer)
            if b then
                if b.param and bipolars[b.param.id] then
                    local full_leds = math.floor(math.abs(b.display_value - 0.5) * 8)
                    local remainder = (math.abs(b.display_value - 0.5) * 8) % 1
                    if b.display_value > 0.5 then
                        for i = 1, full_leds do
                            for j = 0, 1 do
                                g:led(12 + 3 * (layer - 1) + j, 5 - i, 10)
                            end
                        end
                        if full_leds < 4 then
                            for j = 0, 1 do
                                g:led(12 + 3 * (layer - 1) + j, 4 - full_leds,
                                    math.floor(10 * remainder))
                            end
                        end
                    elseif b.display_value < 0.5 then
                        for i = 1, full_leds do
                            for j = 0, 1 do
                                g:led(12 + 3 * (layer - 1) + j, 4 + i, 10)
                            end
                        end
                        if full_leds < 4 then
                            for j = 0, 1 do
                                g:led(12 + 3 * (layer - 1) + j, 5 + full_leds,
                                    math.floor(10 * remainder))
                            end
                        end
                    end
                else
                    local full_leds = math.floor(b.display_value * 8)
                    for i = 1, full_leds do
                        for j = 0, 1 do
                            g:led(12 + 3 * (layer - 1) + j, 9 - i, 10)
                        end
                    end
                    if full_leds < 8 then
                        for j = 0, 1 do
                            g:led(12 + 3 * (layer - 1) + j, 8 - full_leds, math.floor(10 * ((b.display_value * 8) % 1)))
                        end
                    end
                end
            end
        end
    end
    g:refresh()
end


function init()
    dd:copy_psets()
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
    params:add_group("doubledecker_grid", "grid", 4)
    params:add_option("doubledecker_grid_mode", "grid mode", { "keyboard", "controller" })
    params:hide("doubledecker_grid_mode")
    params:add_number("doubledecker_dx", "grid key dx", 1, 7, 1)
    params:add_number("doubledecker_dy", "grid key dy", 1, 12, 5)
    params:add_number("doubledecker_grid_lowest", "lowest note", 0, 36, 24)
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
            grid_redraw()
            clock.sleep(1 / 15)
        end
    end)
end
