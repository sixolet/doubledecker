local function forParamRaw(unprefix_param, inverted)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}
    function ret:getByte()
        local val = param:get_raw()
        if inverted then
            return util.clamp(math.floor(util.linlin(0, 1, 255, 0, val)), 0, 255)
        else
            return util.clamp(math.floor(util.linlin(0, 1, 0, 255, val)), 0, 255)
        end
    end

    function ret:setByte(b)
        if inverted then
            param:set_raw(util.linlin(0, 255, 1, 0, b))
        else
            param:set_raw(util.linlin(0, 255, 0, 1, b))
        end
    end

    return ret
end

local function forKeyfollow(unprefix_param, inverted)
    local param_name = "doubledecker_" .. unprefix_param
    local param1 = params:lookup_param(param_name .. "_1")
    local param2 = params:lookup_param(param_name .. "_2")
    local ret = {}
    function ret:getByte()
        local val = param1:get_raw()
        if inverted then
            return util.clamp(math.floor(util.linlin(0, 1, 255, 0, val)), 0, 255)
        else
            return util.clamp(math.floor(util.linlin(0, 1, 0, 255, val)), 0, 255)
        end
    end

    function ret:setByte(b)
        if inverted then
            param1:set_raw(util.linlin(0, 255, 1, 0, b))
            param2:set_raw(util.linlin(0, 255, 1, 0, b))
        else
            param1:set_raw(util.linlin(0, 255, 0, 1, b))
            param2:set_raw(util.linlin(0, 255, 1, 0, b))
        end
    end

    return ret
end

local function resolve_minmax(min, max)
    local min2 = min
    local max2 = max
    if type(min) == "string" then
        min2 = params:get("doubledecker_" .. min)
    end
    if type(max) == "string" then
        max2 = params:get("doubledecker_" .. max)
    end
    return min2, max2
end

local function forParamTransformed(unprefix_param, min, max, scaling, inverted)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}
    local xform = util.linlin
    if scaling == 'exp' then
        xform = util.explin
    end
    function ret:getByte()
        local val = param:get()
        local min2, max2 = resolve_minmax(min, max)
        if inverted then
            return util.clamp(math.floor(xform(min2, max2, 255, 0, val)), 0, 255)
        else
            return util.clamp(math.floor(xform(min2, max2, 0, 255, val)), 0, 255)
        end
    end

    function ret:setByte(b)
        local xform = util.linlin
        if scaling == 'exp' then
            xform = util.linexp
        end
        local min2, max2 = resolve_minmax(min, max)
        if inverted then
            param:set(xform(0, 255, max2, min2, b))
        else
            param:set(xform(0, 255, min2, max2, b))
        end
    end

    return ret
end

local function forParamIntScaled(unprefix_param, factor)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}
    if factor == nil then factor = 1 end
    function ret:getByte()
        local val = param:get()
        return math.floor(factor * val)
    end

    function ret:setByte(b)
        param:set(b / factor)
    end

    return ret
end

local function forFeet(unprefix_param)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}
    local ddToInternalMap = { 9, 8, 7, 6, 5, 3 }
    local internalToDDMap = { 6, 6, 6, 6, 5, 4, 3, 2, 1 }

    function ret:getByte()
        local internal = param:get()
        local dd = internalToDDMap[internal]
        return (dd - 1) * 42 + 21
    end

    function ret:setByte(b)
        local dd = util.clamp(math.floor(b / 42.5) + 1, 1, 6)
        param:set(ddToInternalMap[dd])
    end
    return ret
end


local function forLfoShape(unprefix_param)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}

    function ret:getByte()
        local internal = 6 - param:get()
        return (internal) * 42 + 21
    end

    function ret:setByte(b)
        local dd = util.clamp(math.floor(b / 42.5) + 1, 1, 6)
        param:set(7 - dd)
    end
    return ret
end

local function forShape(unprefix_param, shape)
    local param_name = "doubledecker_" .. unprefix_param
    local param = params:lookup_param(param_name)
    local ret = {}
    function ret:getByte()
        local val = param:get()
        if shape == "pulse" and val == 3 or val == 4 then
            return 64
        elseif shape == "saw" and val == 2 or val == 4 then
            return 64
        end
        return 128 + 64
    end

    function ret:setByte(b)
        local val = param:get()
        local turn_on = b < 128
        local target_val
        local change
        local is_on
        if shape == "pulse" then
            change = 2
            is_on = (val == 3 or val == 4)
        else
            change = 1
            is_on = (val == 2 or val == 4)
        end
        if is_on and turn_on then return end
        if not is_on and not turn_on then return end
        if is_on and not turn_on then
            param:set(val - change)
        end
        if not is_on and turn_on then
            param:set(val + change)
        end
    end

    return ret
end

local function constant(val)
    local ret = {}

    function ret:getByte()
        return val
    end

    function ret:setByte(b)
    end

    return ret
end

local byte_desciptors = {
    { index = 0,  name = "SLIDER_VCO_SPEED_A",      converter = forParamTransformed("layer_lfo_freq_1", "layer_lfo_min", "layer_lfo_max", 'exp') },
    { index = 1,  name = "SLIDER_VCO_PWM_A",        converter = forParamRaw("pwm_1") },
    { index = 2,  name = "SLIDER_VCO_PW_A",         converter = forParamRaw("pw_1") },
    { index = 3,  name = "SLIDER_VCO_NOISE_A",      converter = forParamRaw("noise_1") },
    { index = 4,  name = "SLIDER_VCF_HPF_A",        converter = forParamRaw("hp_freq_1") },
    { index = 5,  name = "SLIDER_VCF_RESH_A",       converter = forParamRaw("hp_res_1") },
    { index = 6,  name = "SLIDER_VCF_LPF_A",        converter = forParamRaw("lp_freq_1") },
    { index = 7,  name = "SLIDER_VCF_RESL_A",       converter = forParamRaw("lp_res_1") },
    { index = 8,  name = "SLIDER_VCF_IL_A",         converter = forParamTransformed("filter_init_1", -1, 0, 'lin', true) },
    { index = 9,  name = "SLIDER_VCF_AL_A",         converter = forParamTransformed("filter_attack_level_1", 0, 1, 'lin') },
    { index = 10, name = "SLIDER_VCF_ATTACK_A",     converter = forParamTransformed("filter_attack_1", 0.005, "attack_max", 'exp') },
    { index = 11, name = "SLIDER_VCF_DECAY_A",      converter = forParamTransformed("filter_decay_1", 0.01, "release_max", 'exp') },
    { index = 12, name = "SLIDER_VCF_RELEASE_A",    converter = forParamTransformed("filter_release_1", 0.01, "release_max", 'exp') },
    { index = 13, name = "SLIDER_VCA_VCFLEVEL_A",   converter = forParamRaw("filt_1") },
    { index = 14, name = "SLIDER_VCA_SINE_A",       converter = forParamRaw("sine_1") },
    { index = 15, name = "SLIDER_VCA_ATTACK_A",     converter = forParamTransformed("amp_attack_1", 0.005, "attack_max", 'exp') },
    { index = 16, name = "SLIDER_VCA_DECAY_A",      converter = forParamTransformed("amp_decay_1", 0.01, "release_max", 'exp') },
    { index = 17, name = "SLIDER_VCA_SUSTAIN_A",    converter = forParamRaw("amp_sustain_1") },
    { index = 18, name = "SLIDER_VCA_RELEASE_A",    converter = forParamTransformed("amp_release_1", 0.01, "release_max", "exp") },
    { index = 19, name = "SLIDER_VCA_LEVEL_A",      converter = forParamRaw("layer_amp_1") },
    { index = 20, name = "SLIDER_TR_INIT_BR_A",     converter = forParamRaw("velocity_to_filter_1") },
    { index = 21, name = "SLIDER_TR_INIT_LVL_A",    converter = forParamRaw("velocity_to_amp_1") },
    { index = 22, name = "SLIDER_TR_AFTR_BR_A",     converter = forParamRaw("pressure_to_filter_1") },
    { index = 23, name = "SLIDER_TR_AFTR_LVL_A",    converter = forParamRaw("pressure_to_amp_1") },
    { index = 24, name = "SLIDER_VCF_ATTACK_B",     converter = forParamTransformed("filter_attack_2", 0.005, "attack_max", "exp") },
    { index = 25, name = "SLIDER_VCF_DECAY_B",      converter = forParamTransformed("filter_decay_2", 0.01, "release_max", "exp") },
    { index = 26, name = "SLIDER_VCF_RELEASE_B",    converter = forParamTransformed("filter_release_2", 0.01, "release_max", "exp") },
    { index = 27, name = "SLIDER_VCA_VCFLEVEL_B",   converter = forParamRaw("filt_2") },
    { index = 28, name = "SLIDER_VCA_SINE_B",       converter = forParamRaw("sine_2") },
    { index = 29, name = "SLIDER_VCA_ATTACK_B",     converter = forParamTransformed("amp_attack_2", 0.005, "attack_max", "exp") },
    { index = 30, name = "SLIDER_VCO_SPEED_B",      converter = forParamTransformed("layer_lfo_freq_2", "layer_lfo_min", "layer_lfo_max", "exp") },
    { index = 31, name = "SLIDER_VCO_PWM_B",        converter = forParamRaw("pwm_2") },
    { index = 32, name = "SLIDER_VCO_PW_B",         converter = forParamRaw("pw_2") },
    { index = 33, name = "SLIDER_VCO_NOISE_B",      converter = forParamRaw("noise_2") },
    { index = 34, name = "SLIDER_VCF_HPF_B",        converter = forParamRaw("hp_freq_2") },
    { index = 35, name = "SLIDER_VCF_RESH_B",       converter = forParamRaw("hp_res_2") },
    { index = 36, name = "SLIDER_VCF_LPF_B",        converter = forParamRaw("lp_freq_2") },
    { index = 37, name = "SLIDER_VCF_RESL_B",       converter = forParamRaw("lp_res_2") },
    { index = 38, name = "SLIDER_VCF_IL_B",         converter = forParamTransformed("filter_init_2", -1, 0, 'lin', true) },
    { index = 39, name = "SLIDER_VCF_AL_B",         converter = forParamTransformed("filter_attack_level_2", 0, 1, 'lin') },
    { index = 40, name = "SLIDER_VCA_DECAY_B",      converter = forParamTransformed("amp_decay_2", 0.01, "release_max", "exp") },
    { index = 41, name = "SLIDER_VCA_SUSTAIN_B",    converter = forParamRaw("amp_sustain_2") },
    { index = 42, name = "SLIDER_VCA_RELEASE_B",    converter = forParamTransformed("amp_release_2", 0.01, "release_max", "exp") },
    { index = 43, name = "SLIDER_VCA_LEVEL_B",      converter = forParamRaw("layer_amp_2") },
    { index = 44, name = "SLIDER_TR_INIT_BR_B",     converter = forParamRaw("velocity_to_filter_2") },
    { index = 45, name = "SLIDER_TR_INIT_LVL_B",    converter = forParamRaw("velocity_to_amp_2") },
    { index = 46, name = "SLIDER_TR_AFTR_BR_B",     converter = forParamRaw("pressure_to_filter_2") },
    { index = 47, name = "SLIDER_TR_AFTR_LVL_B",    converter = forParamRaw("pressure_to_amp_2") },
    { index = 48, name = "SLIDER_FEET1",            converter = forFeet("pitch_ratio_1") },
    { index = 49, name = "SLIDER_FEET2",            converter = forFeet("pitch_ratio_2") },
    { index = 50, name = "SLIDER_SUBOSC_FUNC",      converter = forLfoShape("lfo_shape") },
    { index = 51, name = "SLIDER_SUBOSC_SPEED",     converter = forParamTransformed("lfo_rate", "global_lfo_min", "global_lfo_max", "exp", true) },
    { index = 52, name = "SLIDER_SUBOSC_VCO",       converter = forParamRaw("lfo_to_freq", true) },
    { index = 53, name = "SLIDER_SUBOSC_VCF",       converter = forParamRaw("lfo_to_filter", true) },
    { index = 54, name = "SLIDER_SUBOSC_VCA",       converter = forParamRaw("lfo_to_amp", true) },
    { index = 55, name = "SLIDER_MIX1",             converter = forParamRaw("mix", true) },
    { index = 56, name = "SLIDER_BRIL",             converter = forParamRaw("brilliance", true) },
    { index = 57, name = "SLIDER_RESO",             converter = forParamRaw("resonance", true) },
    { index = 58, name = "SLIDER_TR_PITCHBAND",     converter = forParamTransformed("pitch_env", -0.5, 0, 'lin') },
    { index = 59, name = "SLIDER_TR_SPEED",         converter = forParamRaw("lfo_pres_to_freq", true) },
    { index = 60, name = "SLIDER_TR_VCO",           converter = forParamRaw("lfo_pres_to_vibrato", true) },
    { index = 61, name = "SLIDER_TR_VCF",           converter = forParamRaw("lfo_pres_to_filt", true) },
    { index = 62, name = "SLIDER_KBRD_BRIL_LOW",    converter = forKeyfollow("filter_keyfollow_lo", true) },
    { index = 63, name = "SLIDER_KBRD_BRIL_HIGH",   converter = forKeyfollow("filter_keyfollow_hi", true) },
    { index = 64, name = "SLIDER_KBRD_LVL_LOW",     converter = forKeyfollow("amp_keyfollow_lo", true) },
    { index = 65, name = "SLIDER_KBRD_LVL_HIGH",    converter = forKeyfollow("amp_keyfollow_hi", true) },
    { index = 66, name = "SLIDER_PORT_GLIS",        converter = forParamRaw("portomento", true) },
    { index = 67, name = "unused1",                 converter = constant(254) },
    { index = 68, name = "unused2",                 converter = constant(254) },
    { index = 69, name = "unused3",                 converter = constant(254) },
    { index = 70, name = "unused4",                 converter = constant(254) },
    { index = 71, name = "unused5",                 converter = constant(254) },
    { index = 72, name = "SWITCH_GLISSANDO",        converter = constant(254) },
    { index = 73, name = "SWITCH_SQUARE_A",         converter = forShape("shape_1", "pulse") },
    { index = 74, name = "SWITCH_SAW_A",            converter = forShape("shape_1", "saw") },
    { index = 75, name = "SWITCH_SAW_B",            converter = forShape("shape_2", "saw") },
    { index = 76, name = "SWITCH_SQUARE_B",         converter = forShape("shape_2", "pulse") },
    { index = 77, name = "SLIDER_COARSE",           converter = constant(128) }, -- why are these stored with patches?
    { index = 78, name = "SLIDER_FINE",             converter = constant(128) },
    { index = 79, name = "SLIDER_DETUNE",           converter = forParamRaw("detune") },
    { index = 80, name = "SWITCH_PORTAMENTO",       converter = constant(255) },
    { index = 81, name = "MENU_VOICE_MODE",         converter = constant(1) }, -- revisit!
    { index = 82, name = "MENU_VOICE_DETUNE",       converter = forParamRaw("drift") },
    { index = 83, name = "MENU_PB_RANGE",           converter = constant(3) }, -- Should be global
    { index = 84, name = "MENU_TIME_PWM_MAX",       converter = forParamIntScaled("layer_lfo_max") },
    { index = 85, name = "MENU_TIME_PWM_MIN",       converter = forParamIntScaled("layer_lfo_min", 10) },
    { index = 86, name = "MENU_TIME_LFO_MAX",       converter = forParamIntScaled("global_lfo_max") },
    { index = 87, name = "MENU_TIME_LFO_MIN",       converter = forParamIntScaled("global_lfo_min", 10) },
    { index = 88, name = "MENU_TIME_ATTACK",        converter = forParamIntScaled("attack_max") },
    { index = 89, name = "MENU_TIME_RELEASE",       converter = forParamIntScaled("release_max") },
    { index = 90, name = "MENU_VOICE_MONO",         converter = constant(1) },
    { index = 91, name = "MENU_VOICE_EGRETRIG",     converter = constant(0) },
    { index = 92, name = "MENU_VOICE_NOTEPRIORITY", converter = constant(0) },
    { index = 93, name = "SWITCH_SUSTAIN",          converter = constant(1) },
    { index = 94, name = "MENU_PRESET_VOLUME",      converter = forParamTransformed("amp", 0.25, 1, 'exp', true) },
    { index = 95, name = "MENU_TIME_LFO_DEPTH",     converter = constant(0) },
    { index = 96, name = "MENU_MW_DESTINATION",     converter = constant(0) },
    { index = 97, name = "MENU_MW_POLARITY",        converter = constant(0) },
}

local Preset = {
    bank = "",
    n_psets = 0,
}

function Preset:current_as_bytes()
    local ret = {}
    for _, descriptor in ipairs(byte_desciptors) do
        -- tab.print(descriptor)
        ret[descriptor.index] = descriptor.converter:getByte()
    end
    return ret
end

function Preset:read_file(filename)
    local fh, err = io.open(filename, "rb")
    local contents = fh:read("*all")
    self.bank = contents
    self.n_psets = string.len(self.bank)/98
end

function Preset:load_preset(n)
    local bytes = {string.byte(self.bank, 98*n + 1, 98*(n+1))}
    for i=98,1,-1 do
        byte_desciptors[i].converter:setByte(bytes[i])
    end
end

return Preset
