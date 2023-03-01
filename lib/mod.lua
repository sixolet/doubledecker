local music = require("musicutil")
local mod = require 'core/mods'
local voice = require 'lib/voice'

if note_players == nil then
    note_players = {}
end
local VOICE_CARDS = 6

local WAVEFORMS = { "none", 'saw', "pulse" }

local PITCH_RATIOS = { "1/4", "1/3", "1/2", "2/3", "1", "3/2", "2", "3", "4" }
local PITCH_RATIO_VALUE = { 1 / 4, 1 / 3, 1 / 2, 2 / 3, 1, 3 / 2, 2, 3, 4 }

mod.hook.register("script_pre_init", "doubledecker pre init", function()
    local player = {
        alloc = voice.new(VOICE_CARDS, voice.MODE_LRU),
        notes = {},
    }

    function player:add_params()
        params:add_group("doubledecker_group", "doubledecker", 66)
        local function control_param(id, name, key, spec)
            params:add_control(id, name, spec)
            params:set_action(id, function(val)
                osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, val })
            end)
        end
        local function taper_param(id, name, key, min, max, default, k, units)
            params:add_taper(id, name, min, max, default, k, units)
            params:set_action(id, function(val)
                osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, val })
            end)
        end
        local function option_param(id, name, key, options, default, f)
            if f == nil then
                f = function(v) return v - 1 end
            end
            params:add_option(id, name, options, default)
            params:set_action(id, function(val)
                osc.send({ "localhost", 57120 }, "/doubledecker/set", { key, f(val) })
            end)
        end
        control_param("doubledecker_mix", "mix", "mix",
            controlspec.new(0, 1, 'lin', 0, 0.5))
        taper_param("doubledecker_amp", "amp", "amp",
            0, 1, 0.25, 2)
        control_param("doubledecker_pan", "pan", "pan",
            controlspec.new( -1, 1, 'lin', 0, 0))
        control_param("doubledecker_detune", "detune", "detune",
            controlspec.new(0, 1, 'lin', 0, 0))
        control_param("doubledecker_drift", "drift", "drift",
            controlspec.new(0, 1, 'lin', 0, 0))
        control_param("doubledecker_pitch_env", "pitch env amount", "pitchEnvAmount",
            controlspec.new( -0.75, 2, 'lin', 0, 0))
        taper_param("doubledecker_portomento", "portomento", "portomento",
            0, 10, 0, 2, 's')
        for l = 1, 2 do
            params:add_separator("doubledecker_layer_" .. l, "layer " .. l)
            option_param("doubledecker_pitch_ratio_" .. l, "pitch ratio", "pitchRatio" .. l,
                PITCH_RATIOS, 5, function(v) return PITCH_RATIO_VALUE[v] end)
            taper_param("doubledecker_layer_lfo_freq_" .. l, "pwm freq", "layerLfoFreq" .. l,
                0.05, 20, 4, 2, "Hz")
            control_param("doubledecker_pwm_" .. l, "pwm", "layerLfoToPw" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.1))
            control_param("doubledecker_pw_" .. l, "pulse width", "pw" .. l,
                controlspec.new(0.1, 0.5, 'lin', 0, 0.4))
            option_param("doubledecker_shape_" .. l, "shape", "waveform" .. l,
                WAVEFORMS, l + 1)
            taper_param("doubledecker_noise_" .. l, "noise", "noise" .. l,
                0, 1, 0, 2)
            taper_param("doubledecker_hp_freq_" .. l, "hpf", "hpfFreq" .. l,
                20, 20000, 60, 2, 'Hz')
            control_param("doubledecker_hp_res_" .. l, "hp res", "hpfRes" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.2))
            taper_param("doubledecker_lp_freq_" .. l, "lpf", "lpfFreq" .. l,
                20, 20000, 600, 2, 'Hz')
            control_param("doubledecker_lp_res_" .. l, "lp res", "lpfRes" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.2))
            control_param("doubledecker_filter_init_" .. l, "filter I lvl", 'fEnvI' .. l,
                controlspec.new( -1, 1, 'lin', 0, 0))
            control_param("doubledecker_filter_attack_level" .. l, "filter A lvl", 'fEnvPeak' .. l,
                controlspec.new( -1, 1, 'lin', 0, 0.4))
            taper_param("doubledecker_filter_attack_" .. l, "filter A", 'fEnvA' .. l,
                0, 30, 0, 2, 's')
            taper_param("doubledecker_filter_decay_" .. l, "filter D", 'fEnvD' .. l,
                0, 30, 1, 2, 's')
            taper_param("doubledecker_filter_release_" .. l, "filter R", 'fEnvR' .. l,
                0, 30, 1, 2, 's')
            control_param("doubledecker_sine_" .. l, "filter vs sine", 'filtVsSine' .. l,
                controlspec.new(0, 1, 'lin', 0, 0.1))
            taper_param("doubledecker_amp_attack_" .. l, "amp A", 'aEnvA' .. l,
                0, 30, 0.05, 2, 's')
            taper_param("doubledecker_amp_decay_" .. l, "amp D", 'aEnvD' .. l,
                0, 30, 1, 2, 's')
            control_param("doubledecker_amp_sustain_" .. l, "amp S", "aEnvS" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.5))
            taper_param("doubledecker_amp_release_" .. l, "amp R", 'aEnvR' .. l,
                0, 30, 1, 2, 's')
            control_param("doubledecker_velocity_to_filter_" .. l, "velocity->filter", "velToFilt" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.2))
            control_param("doubledecker_velocity_to_amp_" .. l, "velocity->amp", "velToAmp" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.8))
            control_param("doubledecker_pressure_to_filter_" .. l, "pressure->filter", "presToFilt" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.5))
            control_param("doubledecker_pressure_to_amp_" .. l, "pressure->amp", "presToAmp" .. l,
                controlspec.new(0, 1, 'lin', 0, 0.5))
        end
        params:add_separator("doubledecker_lfo", "lfo")
        taper_param("doubledecker_lfo_rate", "lfo freq", "globalLfoFreq",
            1 / 30, 20, 4, 2, 'Hz')
        taper_param("doubledecker_lfo_to_freq", "vibrato", "globalLfoToFreq",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_to_filter", "filter lfo mod", "globalLfoToFilterFreq",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_to_amp", "amp lfo mod", "globalLfoToAmp",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_pres_to_freq", "press->lfo freq", "presToGlobalLfoFreq",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_pres_to_vibrato", "press->vibrato", "presToGlobalLfoToFreq",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_pres_to_filt", "press->filt lfo", "presToGlobalLfoToFilterFreq",
            0, 1, 0, 2)
        taper_param("doubledecker_lfo_pres_to_amp", "press->amp lfo", "presToGlobalLfoToAmp",
            0, 1, 0, 2)
        params:hide("doubledecker_group")
    end

    function player:note_on(note, vel, properties)
        local slot = self.notes[note]
        if slot then
            --print("inc", note, slot.id)
            slot.count = slot.count + 1
            return
        end
        local slot = self.alloc:get()
        slot.count = 1
        --print("create", note, slot.id)
        local freq = music.note_num_to_freq(note)
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

    function player:describe()
        return {
            name = "doubledecker",
            supports_bend = true,
            supports_slew = false,
            note_mod_targets = { "pressure" },
            modulate_description = "unsupported",
        }
    end

    function player:modulate_note(note, key, value)
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

    function player:pitch_bend(note, amount)
        local slot = self.notes[note]
        if slot then
            local freq = music.note_num_to_freq(note + amount)
            osc.send(
                { "localhost", 57120 },
                "/doubledecker/set_voice",
                { slot.id - 1, "freq", freq })
        end
    end

    function player:active()
        params:show("doubledecker_group")
        _menu.rebuild_params()
    end

    function player:inactive()
        params:hide("doubledecker_group")
        _menu.rebuild_params()
    end

    function player:note_off(note)
        local slot = self.notes[note]
        if slot then
            slot.count = slot.count - 1
            if slot.count <= 0 then
                self.alloc:release(slot)
            end
        end
    end

    note_players["doubledecker"] = player
end)
