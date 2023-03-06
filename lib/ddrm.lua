local DDRMSynthControl = {}

local DDRMSynthMenu = {}

function DDRMSynthMenu:new(id, name, param, byte, factor)
    local o = {
        id = id,
        name = name,
        param = param and ("doubledecker_" .. param) or nil,
        byte = byte,
        factor = factor,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function DDRMSynthControl:new(id, name, param, cc, byte, layerByte, layer, mftCh, mftCC)
    local o = {
        id = id,
        name = name,
        param = param and ("doubledecker_" .. param) or nil,
        cc = cc,
        byte = byte,
        layerByte = layerByte,
        layer = layer,
        mftCh = mftCh,
        mftCC = mftCC,
        gridX = gridX,
        gridY = gridY,
        gridLayer = gridLayer,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function DDRMSynthControl:newi(id, name, param, cc, byte, layerByte, layer, mftCh, mftCC)
    local o = {
        id = id,
        name = name,
        param = param and ("doubledecker_" .. param) or nil,
        cc = cc,
        byte = byte,
        layerByte = layerByte,
        layer = layer,
        mftCh = mftCh,
        mftCC = mftCC,
        gridX = gridX,
        gridY = gridY,
        gridLayer = gridLayer,
        inverted = true,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function DDRMSynthControl:paramRawToByteValue(v)
    if self.inverted then
        return util.clamp(math.floor(255 * (1-v)), 0, 255)
    end
    return util.clamp(math.floor(255 * v), 0, 255)
end

function DDRMSynthControl:byteValueToParamRaw(b)
    if self.inverted then
        return (255 - b)/255
    end
    return b / 255
end

function DDRMSynthMenu:getByteValue()
    return math.floor(params:get(self.param) / self.factor)
end

function DDRMSynthMenu:setByteValue(val)
    params:set(self.param, self.factor * val)
end

function DDRMSynthControl:getByteValue()
    if self.param then
        local p = params:lookup_param(self.param)
        if p.t == 3 or p.t == 5 then -- tTaper or tControl
            return self:paramRawToByteValue(p:get_raw())
        elseif p.t == 2 then -- tOption
            return math.floor(127 / p.count) * p:get()
        end
    end
    return -1
end

function DDRMSynthControl:setByteValue(val)
    if self.param then
        local p = params:lookup_param(self.param)
        if p.t == 3 or p.t == 5 then
            p:set_raw(self:byteValueToParamRaw(val))
        elseif p.t == 2 then
            local v = val / math.floor(127 / p.count)
            p:set(math.floor(v) + 1)
        end
    end
end

local DDRM = {}

-- you should be able to set multiple "controller devices" - grid, mft, midi, etc.
-- When they recieve control, write through to the appropriate params.
-- When we write to params, interpose something that sends updates to the controller devices.

local CONTROLS = {
    DDRMSynthControl:new("DDRM_SPEED_VCO_1", "Ch I: PWM Speed", "layer_lfo_freq_1", 40, 0, 0, 1, 1, 2),
    DDRMSynthControl:new("DDRM_PWM_VCO_1", "Ch I: PWM Amount", "pwm_1", 41, 1, 1, 1, 5, 2),
    DDRMSynthControl:new("DDRM_PW_VCO_1", "Ch I: PW", "pw_1", 42, 2, 2, 1, 1, 1),
    DDRMSynthControl:new("DDRM_SQR_VCO_1", "Ch I: Square", nil, 43, 73, 24, 1),
    DDRMSynthControl:new("DDRM_SAW_VCO_1", "Ch I: Sawtooth", nil, 44, 74, 25, 1),
    DDRMSynthControl:new("DDRM_NOISE_VCO_1", "Ch I: Noise", "noise_1", 45, 3, 3, 1, 1, 3),
    DDRMSynthControl:new("DDRM_HPF_VCF_1", "Ch I: HPF", "hp_freq_1", 46, 4, 4, 1, 1, 5),
    DDRMSynthControl:new("DDRM_RESh_VCF_1", "Ch I: RESh", "hp_res_1", 47, 5, 5, 1, 5, 5),
    DDRMSynthControl:new("DDRM_LPF_VCF_1", "Ch I: LPF", "lp_freq_1", 48, 6, 6, 1, 1, 6),
    DDRMSynthControl:new("DDRM_RESl_VCF_1", "Ch I: RESl", "lp_res_1", 49, 7, 7, 1, 5, 6),
    DDRMSynthControl:new("DDRM_IL_VCF_1", "Ch I: VCF IL", "filter_init_1", 50, 8, 8, 1, 1, 9),
    DDRMSynthControl:new("DDRM_AL_VCF_1", "Ch I: VCF AL", "filter_attack_level_1", 51, 9, 9, 1, 5, 9),
    DDRMSynthControl:new("DDRM_A_VCF_1", "Ch I: VCF A", "filter_attack_1", 52, 10, 10, 1, 1, 10),
    DDRMSynthControl:new("DDRM_D_VCF_1", "Ch I: VCF D", "filter_decay_1", 53, 11, 11, 1, 1, 11),
    DDRMSynthControl:new("DDRM_R_VCF_1", "Ch I: VCF R", "filter_release_1", 54, 12, 12, 1, 1, 12),
    DDRMSynthControl:new("DDRM_VCF_VCA_1", "Ch I: VCF Level", "filt_1", 55, 13, 13, 1, 5, 4),
    DDRMSynthControl:new("DDRM_SINE__VCA_1", "Ch I: Sine Level", "sine_1", 56, 14, 14, 1, 1, 4),
    DDRMSynthControl:new("DDRM_A_VCA_1", "Ch I: VCA A", "amp_attack_1", 57, 15, 15, 1, 1, 13),
    DDRMSynthControl:new("DDRM_D_VCA_1", "Ch I: VCA D", "amp_decay_1", 58, 16, 16, 1, 1, 14),
    DDRMSynthControl:new("DDRM_S_VCA_1", "Ch I: VCA S", "amp_sustain_1", 59, 17, 17, 1, 1, 15),
    DDRMSynthControl:new("DDRM_R_VCA_1", "Ch I: VCA R", "amp_release_1", 60, 18, 18, 1, 1, 16),
    DDRMSynthControl:new("DDRM_LEVEL_VCA_1", "Ch I: Channel Level", "layer_amp_1", 61, 19, 19, 1, 5, 3),
    DDRMSynthControl:new("DDRM_INIT_BR_TOUCH_1", "Ch I: Initial Brilliance", "velocity_to_filter_1", 62, 20, 20, 1, 1, 7),
    DDRMSynthControl:new("DDRM_INIT_LEV_TOUCH_1", "Ch I: Initial Level", "velocity_to_amp_1", 63, 21, 21, 1, 5, 7),
    DDRMSynthControl:new("DDRM_AT_BR_TOUCH_1", "Ch I: After Brilliance", "pressure_to_filter_1", 65, 22, 22, 1, 1, 8),
    DDRMSynthControl:new("DDRM_AT_LEV_TOUCH_1", "Ch I: After Level", "pressure_to_amp_1", 66, 23, 23, 1, 5, 8),
    DDRMSynthControl:new("DDRM_SPEED_VCO_2", "Ch II: PWM Speed", "layer_lfo_freq_2", 67, 30, 0, 2),
    DDRMSynthControl:new("DDRM_PWM_VCO_2", "Ch II: PWM Amount", "pwm_2", 68, 31, 1, 2),
    DDRMSynthControl:new("DDRM_PW_VCO_2", "Ch II: PW", "pw_2", 69, 32, 2, 2),
    DDRMSynthControl:new("DDRM_SQR_VCO_2", "Ch II: Square", nil, 71, 76, 24, 2),
    DDRMSynthControl:new("DDRM_SAW_VCO_2", "Ch II: Sawtooth", nil, 70, 75, 25, 2),
    DDRMSynthControl:new("DDRM_NOISE_VCO_2", "Ch II: Noise", "noise_2", 72, 33, 3, 2),
    DDRMSynthControl:new("DDRM_HPF_VCF_2", "Ch II: HPF", "hp_freq_2", 73, 34, 4, 2),
    DDRMSynthControl:new("DDRM_RESh_VCF_2", "Ch II: RESh", "hp_res_2", 119, 35, 5, 2),
    DDRMSynthControl:new("DDRM_LPF_VCF_2", "Ch II: LPF", "lp_freq_2", 75, 36, 6, 2),
    DDRMSynthControl:new("DDRM_RESl_VCF_2", "Ch II: RESl", "lp_res_2", 76, 37, 7, 2),
    DDRMSynthControl:new("DDRM_IL_VCF_2", "Ch II: VCF IL", "filter_init_2", 77, 38, 8, 2),
    DDRMSynthControl:new("DDRM_AL_VCF_2", "Ch II: VCF AL", "filter_attack_level_2", 78, 39, 9, 2),
    DDRMSynthControl:new("DDRM_A_VCF_2", "Ch II: VCF A", "filter_attack_2", 79, 24, 10, 2),
    DDRMSynthControl:new("DDRM_D_VCF_2", "Ch II: VCF D", "filter_decay_2", 80, 25, 11, 2),
    DDRMSynthControl:new("DDRM_R_VCF_2", "Ch II: VCF R", "filter_release_2", 81, 26, 12, 2),
    DDRMSynthControl:new("DDRM_VCF_VCA_2", "Ch II: VCF Level", "filt_2", 82, 27, 13, 2),
    DDRMSynthControl:new("DDRM_SINE__VCA_2", "Ch II: Sine Level", "sine_2", 83, 28, 14, 2),
    DDRMSynthControl:new("DDRM_A_VCA_2", "Ch II: VCA A", "amp_attack_2", 84, 29, 15, 2),
    DDRMSynthControl:new("DDRM_D_VCA_2", "Ch II: VCA D", "amp_decay_2", 85, 40, 16, 2),
    DDRMSynthControl:new("DDRM_S_VCA_2", "Ch II: VCA S", "amp_sustain_2", 86, 41, 17, 2),
    DDRMSynthControl:new("DDRM_R_VCA_2", "Ch II: VCA R", "amp_release_2", 87, 42, 18, 2),
    DDRMSynthControl:new("DDRM_LEVEL_VCA_2", "Ch II: Channel Level", "layer_amp_2", 88, 43, 19, 2),
    DDRMSynthControl:new("DDRM_INIT_BR_TOUCH_2", "Ch II: Initial Brilliance", "velocity_to_filter_2", 89, 44, 20, 2),
    DDRMSynthControl:new("DDRM_INIT_LEV_TOUCH_2", "Ch II: Initial Level", "velocity_to_amp_2", 90, 45, 21, 2),
    DDRMSynthControl:new("DDRM_AT_BR_TOUCH_2", "Ch II: After Brilliance", "pressure_to_filter_2", 91, 46, 22, 2),
    DDRMSynthControl:new("DDRM_AT_LEV_TOUCH_2", "Ch II: After Level", "pressure_to_amp_2", 92, 47, 23, 2),
    DDRMSynthControl:new("DDRM_COARSE_PITCH", "Ch : Pitch Coarse", nil, 93, 77, -1, 0, false),
    DDRMSynthControl:new("DDRM_FINE_PITCH", "Ch : Pitch Fine", nil, 94, 78, -1, 0, false),
    DDRMSynthControl:new("DDRM_DETUNE_CH2_PITCH", "Ch : Detune Ch II", "detune", 95, 79, -1, 0),
    DDRMSynthControl:new("DDRM_FEET_1_FEET", "Ch : Feet I", "pitch_ratio_1", 102, 48, -1, 0),
    DDRMSynthControl:new("DDRM_FEET_2_FEET", "Ch : Feet II", "pitch_ratio_2", 103, 49, -1, 0),
    DDRMSynthControl:new("DDRM_FUNCTION_SUB_OSC", "Ch : Sub Osc Function", "lfo_shape", 104, 50, -1, 0),
    DDRMSynthControl:newi("DDRM_SPEED_SUB_OSC", "Ch : Sub Osc Speed", "lfo_rate", 105, 51, -1, 0),
    DDRMSynthControl:newi("DDRM_VCO_SUB_OSC", "Ch : Sub Osc VCO Amount", "lfo_to_freq", 106, 52, -1, 0),
    DDRMSynthControl:newi("DDRM_VCF_SUB_OSC", "Ch : Sub Osc VCF Amount", "lfo_to_filter", 107, 53, -1, 0),
    DDRMSynthControl:newi("DDRM_VCA_SUB_OSC", "Ch : Sub Osc VCA Amount", "lfo_to_amp", 108, 54, -1, 0),
    DDRMSynthControl:new("DDRM_MIX", "Ch : Mix", "mix", 8, 55, -1, 0),
    DDRMSynthControl:newi("DDRM_BRILL", "Ch : Brilliance", "brilliance", 109, 56, -1, 0),
    DDRMSynthControl:newi("DDRM_RESSO", "Ch : Ressonance", "resonance", 110, 57, -1, 0),
    DDRMSynthControl:newi("DDRM_INITIAL_TOUCH", "Ch : Initial Pitch Bend", "pitch_env", 111, 58, -1, 0),
    DDRMSynthControl:newi("DDRM_SPEED_TOUCH", "Ch : Touch Response Sub Osc Speed", "lfo_pres_to_freq", 112, 59, -1, 0),
    DDRMSynthControl:newi("DDRM_VCO_TOUCH", "Ch : Touch Response Sub Osc VCO Amount", "lfo_pres_to_vibrato", 113, 60, -1, 0),
    DDRMSynthControl:newi("DDRM_VCF_TOUCH", "Ch : Touch Response Sub Osc VCF Amount", "lfo_pres_to_filt", 114, 61, -1, 0),
    DDRMSynthControl:newi("DDRM_BR_LOW_KBRD", "Ch : Brilliance Low", "filter_keyfollow_lo_1", 115, 62, -1, 0),
    DDRMSynthControl:newi("DDRM_BR_HIGH_KBRD", "Ch : Brilliance High", "filter_keyfollow_hi_1", 116, 63, -1, 0),
    DDRMSynthControl:newi("DDRM_LEV_LOW_KBRD", "Ch : Level Low", "amp_keyfollow_lo_1", 117, 64, -1, 0),
    DDRMSynthControl:newi("DDRM_LEV_HIGH_KBRD", "Ch : Level High", "amp_keyfollow_hi_1", 118, 65, -1, 0),
    DDRMSynthControl:new("DDRM_GLIDE_MODE_GLIDE", "Ch : Glide Mode", nil, 39, -1, -1, 0),
    DDRMSynthControl:new("DDRM_GLIDE_TIME_GLIDE", "Ch : Glide Time", "portomento", 5, 66, -1, 0),
    DDRMSynthControl:new("DDRM_SUSTAIN_MODE", "Ch : Sustain Mode", nil, 9, -1, -1, 0, false),
    DDRMSynthControl:new("DDRM_SUSTAIN_TIME", "Ch : Sustain Time", nil, 11, -1, -1, 0, false),
    DDRMSynthMenu:new("MENU_PWM_MIN", "PWM Min", "layer_lfo_min", 85, 0.1),
    DDRMSynthMenu:new("MENU_PWM_MAX", "PWM Max", "layer_lfo_max", 84, 1),
    DDRMSynthMenu:new("MENU_LFO_MIN", "LFO Min", "global_lfo_min", 87, 0.1),
    DDRMSynthMenu:new("MENU_LFO_MAX", "LFO Max", "global_lfo_max", 86, 1),
    DDRMSynthMenu:new("MENU_ATTACK_MAX", "Attack Max", "attack_max", 88, 1),
    DDRMSynthMenu:new("MENU_RELEASE_MAX", "Release Max", "release_max", 89, 1),
}

local BY_ID = {}

for _, control in ipairs(CONTROLS) do
    BY_ID[control.id] = control
end
-- Parameters that require special scaling
BY_ID["DDRM_SQR_VCO_1"].getByteValue = function(self)
    if params:get("doubledecker_shape_" .. self.layer) == 3 then
        return 127
    end
    return 0
end
BY_ID["DDRM_SQR_VCO_1"].setByteValue = function(self, val)
    if val > 63 then
        params:set("doubledecker_shape_" .. self.layer, 3)
    end
    return 0
end
BY_ID["DDRM_SQR_VCO_2"].getByteValue = BY_ID["DDRM_SQR_VCO_1"].getByteValue
BY_ID["DDRM_SQR_VCO_2"].setByteValue = BY_ID["DDRM_SQR_VCO_1"].setByteValue


BY_ID["DDRM_SAW_VCO_1"].getByteValue = function(self)
    if params:get("doubledecker_shape_" .. self.layer) == 2 then
        return 127
    end
    return 0
end
BY_ID["DDRM_SAW_VCO_1"].setByteValue = function(self, val)
    if val > 63 then
        params:set("doubledecker_shape_" .. self.layer, 2)
    end
    return 0
end
BY_ID["DDRM_SAW_VCO_2"].getByteValue = BY_ID["DDRM_SAW_VCO_1"].getByteValue
BY_ID["DDRM_SAW_VCO_2"].setByteValue = BY_ID["DDRM_SAW_VCO_1"].setByteValue


BY_ID["DDRM_FEET_1_FEET"].pseudoLayer = 1
BY_ID["DDRM_FEET_1_FEET"].getByteValue = function(self)
    local i = params:get("doubledecker_pitch_ratio_" .. self.pseudoLayer)
    if i <= 4 then
        return 0
    end
    if i == 5 then
        return 22
    end
    if i == 6 then
        return 43
    end
    if i == 7 then
        return 64
    end
    if i == 8 then
        return 85
    end
    if i >= 9 then
        return 127
    end
end

BY_ID["DDRM_FEET_2_FEET"].pseudoLayer = 2
BY_ID["DDRM_FEET_2_FEET"].getByteValue = BY_ID["DDRM_FEET_1_FEET"].getByteValue

BY_ID["DDRM_COARSE_PITCH"].getByteValue = function(self) return 64 end
BY_ID["DDRM_FINE_PITCH"].getByteValue = function(self) return 64 end

local BY_MFT = {}
for _, control in ipairs(CONTROLS) do
    if control.mftCh and control.mftCC then
        if not BY_MFT[control.mftCh] then
            BY_MFT[control.mftCh] = {}
        end
        BY_MFT[control.mftCh][control.mftCC] = control
    end
end


function DDRM.bytes()
    local ret = {}
    for i, control in ipairs(CONTROLS) do
        -- print(i, control.byte, control:getByteValue())
        if control.byte >= 0 then
            ret[control.byte + 1] = control:getByteValue()
        end
    end
    for i=1,98 do
        if ret[i] == nil then
            ret[i] = 0
        end
    end
    return ret
end

DDRM.by_id = BY_ID
DDRM.controls = CONTROLS
DDRM.by_mft = BY_MFT

return DDRM
