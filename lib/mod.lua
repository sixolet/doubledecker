local music = require("musicutil")
local mod = require 'core/mods'
local voice = require 'lib/voice'
local bind = require 'doubledecker/lib/binding'

if note_players == nil then
    note_players = {}
end
local VOICE_CARDS = 6

local WAVEFORMS = { "none", 'saw', "pulse", "both (lf)" }

local LFO_SHAPES = { "sine", "saw", "ramp", "square", "rand", "smooth" }

local PITCH_RATIOS = { "1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4" }
local PITCH_RATIO_VALUE = { 1 / 4, 1 / 3, 1 / 2, 2 / 3, 1, 3 / 2, 2, 3, 4 }

local Player = {
    alloc = voice.new(VOICE_CARDS, voice.MODE_LRU),
    notes = {},
}

function Player:add_params()
    params:add_group("doubledecker_group", "doubledecker", 93)
    local function control_param(id, name, key, spec, binding)
        params:add_control(id, name, spec)
        local p = params:lookup_param(id)
        params:set_action(id, function(val)
            osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, val })
            if binding then
                binding:communicate(p:get_raw())
            end
        end)
        if binding then
            binding.param = p
        end
        return p
    end
    local function taper_param(id, name, key, min, max, default, k, units, binding)
        params:add_taper(id, name, min, max, default, k, units)
        local p = params:lookup_param(id)
        params:set_action(id, function(val)
            osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, val })
            if binding then
                binding:communicate(p:get_raw())
            end
        end)
        if binding then
            binding.param = p
        end
        return p
    end
    local function option_param(id, name, key, options, default, f, binding)
        if f == nil then
            f = function(v) return v - 1 end
        end
        params:add_option(id, name, options, default)
        local p = params:lookup_param(id)
        params:set_action(id, function(val)
            osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, f(val) })
            if binding then
                binding:communicate((val - 1) / (p.count - 1))
            end
        end)
        if binding then
            binding.param = p
        end
        return p
    end
    local function max_param(id, name, targets, min, max, step, default)
        params:add_control(id, name, controlspec.new(min, max, 'lin', step, default))
    end
    local function min_param(id, name, targets, min, max, step, default)
        params:add_control(id, name, controlspec.new(min, max, 'lin', step, default))
    end
    params:add_option("doubledecker_voices", "voices", {"mono", "unison", "3 pairs", "poly 4", "poly 6"}, 4)
    params:set_action("doubledecker_voices", function(v)
        osc.send({"localhost", 57120}, "/doubledecker/all_off", {})
        if v == 1 or v == 2 then
            self.alloc = voice.new(1, voice.MODE_LRU)
        elseif v == 3 then
            self.alloc = voice.new(3, voice.MODE_LRU)
        elseif v == 4 then
            self.alloc = voice.new(4, voice.MODE_LRU)
        elseif v == 5 then
            self.alloc = voice.new(6, voice.MODE_LRU)
        end
    end)
    control_param("doubledecker_mix", "mix", "mix",
        controlspec.new(0, 1, 'lin', 0, 0.5), bind:at(3, 1, 1, 1, "mix"))
    taper_param("doubledecker_amp", "amp", "amp",
        0, 1, 0.25, 2, nil, bind:at(3, 1, 1, 2, "amp"))
    control_param("doubledecker_pan", "pan", "pan",
        controlspec.new( -1, 1, 'lin', 0, 0)) -- TODO: add binding for pan
    control_param("doubledecker_detune", "detune", "detune",
        controlspec.new( -1, 1, 'lin', 0, 0), bind:at(3, 1, 3, 1, "detune"))
    control_param("doubledecker_drift", "drift", "drift",
        controlspec.new(0, 1, 'lin', 0, 0), bind:at(3, 1, 4, 2, "drift"))
    control_param("doubledecker_pitch_env", "pitch env amount", "pitchEnvAmount",
        controlspec.new( -0.75, 2, 'lin', 0, 0), bind:at(3, 1, 3, 2, "pEnv"))
    taper_param("doubledecker_portomento", "portomento", "portomento",
        0, 10, 0, 2, 's', bind:at(3, 1, 4, 1, "port"))
    control_param("doubledecker_brilliance", "brilliance", "globalBrilliance",
        controlspec.new( -1, 1, 'lin', 0, 0), bind:at(3, 3, 3, 1, "bril"))
    control_param("doubledecker_resonance", "resonance", "globalResonance",
        controlspec.new( -1, 1, 'lin', 0, 0), bind:at(3, 3, 4, 1, "res"))
    for l = 1, 2 do
        params:add_separator("doubledecker_layer_" .. l, "layer " .. l)
        option_param("doubledecker_pitch_ratio_" .. l, "pitch ratio", "pitchRatio" .. l,
            PITCH_RATIOS, 5, function(v) return PITCH_RATIO_VALUE[v] end, bind:at(l, 3, 4, 2, "feet"))
        taper_param("doubledecker_layer_lfo_freq_" .. l, "pwm freq", "layerLfoFreq" .. l,
            0.1, 100, 4, 2, "Hz", bind:at(l, 1, 2, 1, "pwS"))
        control_param("doubledecker_pwm_" .. l, "pwm", "layerLfoToPw" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.1), bind:at(l, 1, 2, 2, "pwAt"))
        control_param("doubledecker_pw_" .. l, "pulse width", "pw" .. l,
            controlspec.new(0.1, 0.5, 'lin', 0, 0.4), bind:at(l, 1, 1, 2, "pw"))
        option_param("doubledecker_shape_" .. l, "shape", "waveform" .. l,
            WAVEFORMS, l + 1, nil, bind:at(l, 1, 1, 1, "shape"))
        taper_param("doubledecker_noise_" .. l, "noise", "noise" .. l,
            0, 1, 0, 2, nil, bind:at(l, 1, 3, 1, "noise"))
        taper_param("doubledecker_hp_freq_" .. l, "hpf", "hpfFreq" .. l,
            20, 10000, 60, 6, 'Hz', bind:at(l, 2, 1, 1, "hpf"))
        control_param("doubledecker_hp_res_" .. l, "hp res", "hpfRes" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.2), bind:at(l, 2, 1, 2, "hpR"))
        taper_param("doubledecker_lp_freq_" .. l, "lpf", "lpfFreq" .. l,
            100, 20000, 600, 4, 'Hz', bind:at(l, 2, 2, 1, "lpf"))
        control_param("doubledecker_lp_res_" .. l, "lp res", "lpfRes" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.2), bind:at(l, 2, 2, 2, "lpR"))
        control_param("doubledecker_filter_init_" .. l, "filter I lvl", 'fEnvI' .. l,
            controlspec.new( -1, 1, 'lin', 0, 0), bind:at(l, 3, 1, 2, "IL"))
        control_param("doubledecker_filter_attack_level_" .. l, "filter A lvl", 'fEnvPeak' .. l,
            controlspec.new( -1, 1, 'lin', 0, 0.4), bind:at(l, 3, 1, 1, "AL"))
        taper_param("doubledecker_filter_attack_" .. l, "filter A", 'fEnvA' .. l,
            0, 30, 0, 6, 's', bind:at(l, 3, 2, 1, "A"))
        taper_param("doubledecker_filter_decay_" .. l, "filter D", 'fEnvD' .. l,
            0, 30, 1, 4, 's', bind:at(l, 3, 3, 1, "D"))
        taper_param("doubledecker_filter_release_" .. l, "filter R", 'fEnvR' .. l,
            0, 30, 1, 4, 's', bind:at(l, 3, 4, 1, "R"))
        control_param("doubledecker_filt_" .. l, "filt amp", 'filtAmp' .. l,
            controlspec.new(0, 1, 'lin', 0, 1), bind:at(l, 1, 3, 2, "fAmp"))
        control_param("doubledecker_sine_" .. l, "sine amp", 'sineAmp' .. l,
            controlspec.new(0, 1, 'lin', 0, 0), bind:at(l, 1, 4, 1, "sine"))
        taper_param("doubledecker_amp_attack_" .. l, "amp A", 'aEnvA' .. l,
            0, 30, 0.05, 6, 's', bind:at(l, 4, 1, 1, "A"))
        taper_param("doubledecker_amp_decay_" .. l, "amp D", 'aEnvD' .. l,
            0, 30, 1, 4, 's', bind:at(l, 4, 2, 1, "D"))
        control_param("doubledecker_amp_sustain_" .. l, "amp S", "aEnvS" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.5), bind:at(l, 4, 3, 1, "S"))
        taper_param("doubledecker_amp_release_" .. l, "amp R", 'aEnvR' .. l,
            0, 30, 1, 4, 's', bind:at(l, 4, 4, 1, "R"))
        control_param("doubledecker_velocity_to_filter_" .. l, "velocity->filter", "velToFilt" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.2), bind:at(l, 2, 3, 1, "iBril"))
        control_param("doubledecker_velocity_to_amp_" .. l, "velocity->amp", "velToAmp" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.8), bind:at(l, 2, 3, 2, "iAmp"))
        control_param("doubledecker_pressure_to_filter_" .. l, "pressure->filter", "presToFilt" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.5), bind:at(l, 2, 4, 1, "pBril"))
        control_param("doubledecker_pressure_to_amp_" .. l, "pressure->amp", "presToAmp" .. l,
            controlspec.new(0, 1, 'lin', 0, 0.5), bind:at(l, 2, 4, 2, "pAmp"))
        control_param("doubledecker_filter_keyfollow_lo_" .. l, "filter keyfollow lo", "filtKeyfollowLo" .. l,
            controlspec.new( -1, 1, 'lin', 0, 0))
        control_param("doubledecker_filter_keyfollow_hi_" .. l, "filter keyfollow hi", "filtKeyfollowHi" .. l,
            controlspec.new( -1, 1, 'lin', 0, 0))
        control_param("doubledecker_amp_keyfollow_lo_" .. l, "amp keyfollow lo", "ampKeyfollowLo" .. l,
            controlspec.new( -1, 1, 'lin', 0, 0))
        control_param("doubledecker_amp_keyfollow_hi_" .. l, "amp keyfollow hi", "ampKeyfollowHi" .. l,
            controlspec.new( -1, 1, 'lin', 0, 0))
        taper_param("doubledecker_layer_amp_" .. l, "layer amp", "layerAmp" .. l,
            0, 1, 1, 2, nil, bind:at(l, 1, 4, 2, "layer" .. l))
        option_param("doubledecker_invert_hpf_" .. l, "hpf response coef", "fEnvHiInvert" .. l,
            { "-1", "0", "1" }, 3, function(x) return x - 2 end)
    end
    params:add_separator("doubledecker_lfo", "lfo")
    option_param("doubledecker_lfo_shape", "shape", "globalLfoShape",
        LFO_SHAPES, 1, function(v) return v - 1 end, bind:at(3, 1, 2, 1, "shape"))
    taper_param("doubledecker_lfo_rate", "lfo freq", "globalLfoFreq",
        1 / 30, 20, 4, 2, 'Hz', bind:at(3, 2, 1, 1, "rate"))
    taper_param("doubledecker_lfo_to_freq", "vibrato", "globalLfoToFreq",
        0, 1, 0, 2, nil, bind:at(3, 2, 2, 1, "vibrato"))
    taper_param("doubledecker_lfo_to_filter", "filter lfo mod", "globalLfoToFilterFreq",
        0, 1, 0, 2, nil, bind:at(3, 2, 3, 1, "f mod"))
    taper_param("doubledecker_lfo_to_amp", "tremolo", "globalLfoToAmp",
        0, 1, 0, 2, nil, bind:at(3, 2, 4, 1, "tremolo"))
    taper_param("doubledecker_lfo_pres_to_freq", "press->lfo freq", "presToGlobalLfoFreq",
        0, 1, 0, 2, nil, bind:at(3, 2, 1, 2, "pres"))
    taper_param("doubledecker_lfo_pres_to_vibrato", "press->vibrato", "presToGlobalLfoToFreq",
        0, 1, 0, 2, nil, bind:at(3, 2, 2, 2, "pres"))
    taper_param("doubledecker_lfo_pres_to_filt", "press->filt lfo", "presToGlobalLfoToFilterFreq",
        0, 1, 0, 2, nil, bind:at(3, 2, 3, 2, "pres"))
    taper_param("doubledecker_lfo_pres_to_amp", "press->tremolo", "presToGlobalLfoToAmp",
        0, 1, 0, 2, nil, bind:at(3, 2, 4, 2, "pres"))
    option_param("doubledecker_lfo_sync", "sync", "globalLfoSync", {"off", "on"}, 2)
    option_param("doubledecker_lfo_scope", "scope", "globalLfoIndividual", {"global", "voice"})
    params:add_separator("doubledecker_deep", "deep patch options")
    min_param("doubledecker_layer_lfo_min", "pwm lfo min",
        { "doubledecker_layer_lfo_freq_1", "doubledecker_layer_lfo_freq_2" },
        0.1, 5, 0.1, 0.7)
    max_param("doubledecker_layer_lfo_max", "pwm lfo max",
        { "doubledecker_layer_lfo_freq_1", "doubledecker_layer_lfo_freq_2" },
        10, 100, 1, 70)
    min_param("doubledecker_global_lfo_min", "global lfo min", { "doubledecker_lfo_rate" },
        0.1, 5, 0.1, 0.7)
    max_param("doubledecker_global_lfo_max", "global lfo min", { "doubledecker_lfo_rate" },
        10, 45, 1, 25)
    max_param("doubledecker_attack_max", "attack max",
        { "doubledecker_amp_attack_1", "doubledecker_filter_attack_1", "doubledecker_amp_attack_2",
            "doubledecker_filter_attack_2" },
        1, 100, 1, 1)
    max_param("doubledecker_release_max", "release_max",
        {
            "doubledecker_amp_release_1",
            "doubledecker_amp_decay_1",
            "doubledecker_filter_release_1",
            "doubledecker_filter_decay_1",
            "doubledecker_amp_release_2",
            "doubledecker_amp_decay_2",
            "doubledecker_filter_release_2",
            "doubledecker_filter_decay_2",
        },
        15, 150, 1, 15)
    params:hide("doubledecker_group")
end

function Player:note_on(note, vel, properties)
    local slot = self.notes[note]
    if slot then
        --print("inc", note, slot.id)
        slot.count = slot.count + 1
        return
    end
    local slot = self.alloc:get()
    slot.count = 1
    --print("create", note, slot.id)
    local freq = music.note_num_to_freq(note % 128)
    local v = slot.id - 1
    slot.on_release = function()
        --print("release", note, slot.id)
        -- TODO: Find any voices this covered.
        osc.send({ "localhost", 57120 }, "/doubledecker/set_voice", { v, "gate", 0 })
        slot.count = nil
        self.notes[note] = nil
    end
    osc.send({ "localhost", 57120 }, "/doubledecker/note_on", { v, freq, vel });
    self.notes[note] = slot;
end

function Player:describe()
    return {
        name = "doubledecker",
        supports_bend = true,
        supports_slew = false,
        note_mod_targets = { "pressure" },
        modulate_description = "unsupported",
    }
end

function Player:modulate_note(note, key, value)
    if key == "pressure" then
        local slot = self.notes[note]
        if slot then
            osc.send(
                { "localhost", 57120 },
                "/doubledecker/set_voice",
                { slot.id - 1, "pressure", value })
        end
    end
end

function Player:pitch_bend(note, amount)
    local slot = self.notes[note]
    -- print("pb", note, amount)
    if slot then
        local freq = music.note_num_to_freq(note % 128 + amount)
        osc.send(
            { "localhost", 57120 },
            "/doubledecker/set_voice",
            { slot.id - 1, "freq", freq })
    end
end

function Player:active()
    params:show("doubledecker_group")
    _menu.rebuild_params()
end

function Player:inactive()
    params:hide("doubledecker_group")
    _menu.rebuild_params()
end

function Player:note_off(note)
    local slot = self.notes[note]
    if slot then
        slot.count = slot.count - 1
        if slot.count <= 0 then
            self.alloc:release(slot)
        end
    end
end

mod.hook.register("system_post_startup", "doubledecker post startup", function()
end)

mod.hook.register("script_pre_init", "doubledecker pre init", function()
    osc.send(
        { "localhost", 57120 },
        "/doubledecker/init",
        {});
    note_players["doubledecker"] = Player
end)

return Player
