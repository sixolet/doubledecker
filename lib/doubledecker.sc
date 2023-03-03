DoubleDecker {
    classvar <params, <voices, <lfos, <group, <lfoGroup, <lfoBusses, <lastAction, <noiseSynth, <noiseBus;

    *dynamicInit {
        if (group == nil, {
	        group = Group.new;
            lfoGroup = Group.before(group);
            lfoBusses = 8.collect(Bus.control(Server.default, 1));
            noiseBus = Bus.audio(Server.default, 1);
            DoubleDecker.addSynthdefs();
            "Double Decker Line".postln;
        });
    }

    *addSynthdefs {
            SynthDef(\doubledeckerNoise, { |out|
                Out.ar(out, WhiteNoise.ar);
            }).add;
            SynthDef(\doubledeckerLfo, { 
                |out, globalLfoFreq, pressure, presToGlobalLfoFreq|
                Out.kr(out, SinOsc.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;
            (["X", "S", "P"]!2).allTuples.do { |tup|
                SynthDef(("doubledecker"++tup[0]++tup[1]).asSymbol, {
                    | 
                    out, freq=220, velocity=0.4, pressure=0.4, gate=1, pan=0,// per-note stuff
                    // layer 1
                    pitchRatio1=1,
                    layerLfoFreq1=3, pw1=0.4, sawVsPulse1=0.5, noise1=0,
                    hpfFreq1=60, hpfRes1=0.5, lpfFreq1=2000, lpfRes1=0.5,
                    fEnvI1=0, fEnvPeak1=1, fEnvA1=0.01, fEnvD1=1, fEnvR1=1, fEnvHiInvert1=1,
                    filtVsSine1, aEnvA1, aEnvD1, aEnvS1, aEnvR1,
                    velToFilt1, velToAmp1,
                    presToFilt1, presToAmp1,
                    layerLfoToPw1, 
                    filtKeyfollow1, ampKeyfollow1,
                    // layer 2
                    pitchRatio2=1,
                    layerLfoFreq2, pw2, sawVsPulse2, noise2,
                    hpfFreq2, hpfRes2, lpfFreq2, lpfRes2,
                    fEnvI2, fEnvPeak2, fEnvA2, fEnvD2, fEnvR2, fEnvHiInvert2,
                    filtVsSine2, aEnvA2, aEnvD2, aEnvS2, aEnvR2,
                    velToFilt2, velToAmp2,
                    presToFilt2, presToAmp2,
                    layerLfoToPw2, 
                    filtKeyfollow2, ampKeyfollow2,
                    // Both layers
                    noiseBus, globalLfoBus, 
                    globalLfoToFreq, presToGlobalLfoToFreq,
                    globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                    globalLfoToAmp, presToGlobalLfoToAmp,
                    mix, globalBrilliance, globalResonance,
                    detune, drift,
                    pitchEnvAmount, portomento,
                    amp|
                    var keyRatio = freq/261.63;
                    var layer = { 
                        | waveform, keyRatio,
                        freq, velocity, pressure, gate,
                        globalLfo,
                        layerLfoFreq,
                        pw, sawVsPulse, noise, noiseUgen,
                        hpfFreq, hpfRes, lpfFreq, lpfRes,
                        fEnvI, fEnvPeak, fEnvA, fEnvD, fEnvR, fEnvHiInvert,
                        filtVsSine, aEnvA, aEnvD, aEnvS, aEnvR,
                        velToFilt, velToAmp,
                        presToFilt, presToAmp,
                        layerLfoToPw, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollow, ampKeyfollow |
                        var sound;
                        var layerLfo;
                        var filterEnv, ampEnv;
                        var modLpfFreq, modHpfFreq, modLayerLfoFreq, modAmp, modPw;
                        var filtFreqRatio = keyRatio**filtKeyfollow;
                        var ampRatio = (keyRatio**ampKeyfollow).clip(0, 4);
                        filterEnv = EnvGen.kr(
                            Env.new(levels: [fEnvI, fEnvPeak, 0, fEnvI], times: [fEnvA, fEnvD, fEnvR], releaseNode: 2), 
                            gate,
                            doneAction: Done.none);
                        ampEnv = EnvGen.kr(Env.adsr(aEnvA, aEnvD, aEnvS, aEnvR), gate, doneAction: Done.none);
                        // Full range of filter modulation is about +/- four octaves; less gentle.
                        modLpfFreq = lpfFreq * (globalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/16, 16);
                        modLpfFreq = modLpfFreq * filtFreqRatio;
                        modLpfFreq = modLpfFreq * (pressure*presToGlobalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/16, 16);
                        modLpfFreq = modLpfFreq * filterEnv.linexp(-1, 1, 1/16, 16);
                        modLpfFreq = modLpfFreq * (presToFilt*pressure).linexp(-1, 1, 1/16, 16);
                        modLpfFreq = modLpfFreq * (velToFilt*velocity).linexp(-1, 1, 1/16, 16);
                        modLpfFreq = modLpfFreq.clip(20, 17000);

                        modHpfFreq = hpfFreq * (fEnvHiInvert*globalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/16, 16);
                        modHpfFreq = modHpfFreq * filtFreqRatio;
                        modHpfFreq = modHpfFreq * (fEnvHiInvert*pressure*presToGlobalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/16, 16);
                        modHpfFreq = modHpfFreq * (fEnvHiInvert*filterEnv).linexp(-1, 1, 1/16, 16);
                        modHpfFreq = modHpfFreq * (fEnvHiInvert*presToFilt*pressure).linexp(-1, 1, 1/16, 16);
                        modHpfFreq = modHpfFreq * (fEnvHiInvert*velToFilt*velocity).linexp(-1, 1, 1/16, 16);
                        modHpfFreq = modHpfFreq.clip(20, 17000);

                        // Our main oscs
                        sound = switch(waveform.asSymbol,
                            \X, {0},
                            \S, {Saw.ar(freq)},
                            \P, {
                                    layerLfo = SinOsc.kr(layerLfoFreq);
                                    modPw = pw / (1 + (layerLfoToPw*layerLfo.range(0, 1)));
                                    Pulse.ar(freq, width: modPw);
                                },
                            {0});
                        
                        // Add some noise
                        sound = sound + (noise*noiseUgen);

                        // Filter stage
                        sound = RHPF.ar(sound, modHpfFreq, hpfRes.linexp(0, 1, 1.2, 0.05));
                        sound = RLPF.ar(sound, modLpfFreq, lpfRes.linexp(0, 1, 1.2, 0.05));

                        // Mix with sine.
                        sound = LinSelectX.ar(filtVsSine, [sound, SinOsc.ar(freq)]);

                        // Velocity to amp
                        ampEnv = LinSelectX.kr(velToAmp, [ampEnv, velocity*ampEnv]);
                        // Pressure to amp
                        ampEnv = LinSelectX.kr(presToAmp, [ampEnv, pressure*ampEnv]);
                        // Global LFO to amp
                        ampEnv = LinSelectX.kr(globalLfoToAmp, [ampEnv, globalLfo.range(0, 1)*ampEnv]);

                        // Amp envelope.
                        sound = ampEnv*ampRatio*sound;              
                        sound;
                    };
                    var globalLfo, modFreq, noiseUgen, layer1, layer2, mixed, detuneRatio, driftAddition;
                    globalLfo = In.kr(globalLfoBus, 1);
                    detuneRatio = detune.linexp(0, 1, 1, 2**(1/12));
                    driftAddition = 3*drift*LFNoise1.kr(0.01);
                    modFreq = freq.lag(portomento);
                    modFreq = modFreq * (1 + (pitchEnvAmount*EnvGen.kr(Env.perc(attackTime: 0, releaseTime: portomento))));
                    // Full range of frequency modulation is about +/- a full step; gentle.
                    modFreq = modFreq * (1 + (0.1*globalLfoToFreq*globalLfo));
                    modFreq = modFreq * (1 + (0.1*presToGlobalLfoToFreq*pressure*globalLfo));
                    noiseUgen = In.ar(noiseBus, 1);
                    layer1 = layer.value(
                        tup[0].asSymbol,
                        keyRatio,
                        (detuneRatio*pitchRatio1*modFreq)+driftAddition, velocity, pressure, gate,
                        globalLfo,
                        layerLfoFreq1,
                        pw1, sawVsPulse1, noise1, noiseUgen,
                        hpfFreq1, hpfRes1, lpfFreq1, lpfRes1,
                        fEnvI1, fEnvPeak1, fEnvA1, fEnvD1, fEnvR1, fEnvHiInvert1,
                        filtVsSine1, aEnvA1, aEnvD1, aEnvS1, aEnvR1,
                        velToFilt1, velToAmp1,
                        presToFilt1, presToAmp1,
                        layerLfoToPw1, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollow1, ampKeyfollow1);
                    layer2 = layer.value(
                        tup[1].asSymbol,
                        keyRatio,
                        (detuneRatio.reciprocal*pitchRatio2*modFreq)+driftAddition, velocity, pressure, gate,
                        globalLfo,
                        layerLfoFreq2,
                        pw2, sawVsPulse2, noise2, noiseUgen,
                        hpfFreq2, hpfRes2, lpfFreq2, lpfRes2,
                        fEnvI2, fEnvPeak2, fEnvA2, fEnvD2, fEnvR2, fEnvHiInvert2,
                        filtVsSine2, aEnvA2, aEnvD2, aEnvS2, aEnvR2,
                        velToFilt2, velToAmp2,
                        presToFilt2, presToAmp2,
                        layerLfoToPw2, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollow2, ampKeyfollow2);
                    mixed = LinSelectX.ar(mix, [layer1, layer2]);
                    DetectSilence.ar(mixed+Impulse.ar(0), doneAction: Done.freeSelf);
                    mixed = amp*mixed;
                    Out.ar(out, Pan2.ar(mixed, pan));
                }).add;
            };
    }

    *initClass {
        params = (
            globalLfoFreq: 4,

            waveform1: 1, pitchRatio1: 1,
            layerLfoFreq1: 3, pw1: 0.4, sawVsPulse1: 1, noise1: 0,
            hpfFreq1: 60, hpfRes1: 0.5, lpfFreq1: 600, lpfRes1: 0.5,
            fEnvI1: 0, fEnvPeak1: 1, fEnvA1: 0.01, fEnvD1: 1, fEnvR1:1, fEnvHiInvert1: 1,
            filtVsSine1: 0.2, aEnvA1: 0.01, aEnvD1: 1, aEnvS1: 0.5, aEnvR1: 1,
            velToFilt1: 0.2, velToAmp1: 0.8, presToFilt1: 0.5, presToAmp1: 0.5,
            layerLfoToPw1: 0.1, 
            filtKeyfollow1: 0, ampKeyfollow1: 0,

            waveform2: 2, pitchRatio2: 1,
            layerLfoFreq2: 3, pw2: 0.4, sawVsPulse2: 0, noise2: 0,
            hpfFreq2: 600, hpfRes2: 0.5, lpfFreq2: 1200, lpfRes2: 0.5,
            fEnvI2: 0, fEnvPeak2: 1, fEnvA2: 0.01, fEnvD2: 1, fEnvR2:1, fEnvHiInvert2: 1,
            filtVsSine2: 0.2, aEnvA2: 0.01, aEnvD2: 1, aEnvS2: 0.5, aEnvR2: 1,
            velToFilt2: 0.2, velToAmp2: 0.8, presToFilt2: 0.5, presToAmp2: 0.5,
            layerLfoToPw2: 0.1, 
            filtKeyfollow2: 0, ampKeyfollow2: 0,

            globalLfoToFreq: 0, presToGlobalLfoToFreq: 0, 
            globalLfoToFilterFreq: 0, presToGlobalLfoToFilterFreq: 0,
            globalLfoToAmp: 0, presToGlobalLfoToAmp: 0,
            mix: 0.5, globalBrilliance: 0, globalResonance: 0,
            detune: 0, drift: 0,
            pitchEnvAmount: 0, portomento: 0,
            amp: 0.25,      
        );
		voices = nil!8;
        lfos = nil!8;
		lastAction = 0;
        StartUp.add {
            OSCFunc.new({ |msg, time, addr, recvPort|
                var voice = msg[1].asInteger;
                var hz = msg[2].asFloat;
                var velocity = msg[3].asFloat;
                DoubleDecker.dynamicInit();
                Routine.new({
                    if (noiseSynth == nil, {
                        noiseSynth = Synth.new(
                            \doubledeckerNoise, 
                            [\out, noiseBus],
                            target:lfoGroup);
                        Server.default.sync;
                    });
                    if(lfos[voice] == nil, {
                        lfos[voice] = Synth.new(
                            \doubledeckerLfo, 
                            [
                                \out, lfoBusses[voice], 
                                \globalLfoFreq, params.globalLfoFreq,
                                \pressure, 0
                            ],
                            target:lfoGroup);
                    });
                    if(voices[voice] == nil, {
                        var l1 = [\X, \S, \P][params.waveform1];
                        var l2 = [\X, \S, \P][params.waveform2];
                        voices[voice] = Synth.new(
                            ("doubledecker" ++ l1 ++ l2), 
                            [
                                \freq, hz, 
                                \velocity, velocity, 
                                \globalLfo, lfoBusses[voice],
                                \noiseBus, noiseBus,
                            ]++params.asPairs,
                            target: group);
                        voices[voice].onFree({
                            voices[voice] = nil;
                            if(voices.every({|x, i| x == nil}) && (noiseSynth != nil), {
                                noiseSynth.free;
                                noiseSynth = nil;
                            });
                     });
                    }, {
                        voices[voice].set(\freq, hz, \velocity, velocity, \gate, 1)
                    });
                }).play;            
            }, "/doubledecker/note_on");
            OSCFunc.new({ |msg, time, addr, recvPort|
                var voice = msg[1].asInteger;
                var key = msg[2].asSymbol;
                var value = msg[3].asFloat;
                DoubleDecker.dynamicInit();
                if(voices[voice] != nil, {
                    voices[voice].set(key, value);
                    // "% %\n".postf(key, value);
                });
                if(lfos[voice] != nil, {
                    lfos[voice].set(key, value);
                });
            }, "/doubledecker/set_voice");

            OSCFunc.new({ |msg, time, addr, recvPort|
                var key = msg[1].asSymbol;
                var value = msg[2].asFloat;
                DoubleDecker.dynamicInit();
                params[key] = value;
                lfoGroup.set(key, value);
                group.set(key, value);
            }, "/doubledecker/set");

            OSCFunc.new({ |msg, time, addr, recvPort|
                DoubleDecker.dynamicInit();
            }, "/doubledecker/init");
        }
    }
}