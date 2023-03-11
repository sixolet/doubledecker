DoubleDecker {
    classvar <params, <voices, <lfos, <group, <lfoGroup, <lfoBusses, <lastAction, <noiseSynth, <noiseBus, <pressures;

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
            SynthDef(\doubledeckerLfoSine, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, SinOsc.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;
            SynthDef(\doubledeckerLfoSaw, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, -1*LFSaw.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add; 
            SynthDef(\doubledeckerLfoRamp, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, LFSaw.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;
            SynthDef(\doubledeckerLfoSquare, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, LFPulse.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;
            SynthDef(\doubledeckerLfoRand, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, -1*LFNoise0.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;
            SynthDef(\doubledeckerLfoSmooth, { 
                |out, globalLfoFreq=4, pressure=0, presToGlobalLfoFreq=0|
                Out.kr(out, -1*LFNoise2.kr(globalLfoFreq*((pressure*presToGlobalLfoFreq) + 1)));
            }).add;                         
            (["X", "S", "P", "B"]!2).allTuples.do { |tup|
                SynthDef(("doubledecker"++tup[0]++tup[1]).asSymbol, {
                    | 
                    out, freq=220, velocity=0.4, pressure=0.4, gate=1, pan=0,// per-note stuff
                    // layer 1
                    pitchRatio1=1,
                    layerLfoFreq1=3, pw1=0.4, noise1=0,
                    hpfFreq1=60, hpfRes1=0.5, lpfFreq1=2000, lpfRes1=0.5,
                    fEnvI1=0, fEnvPeak1=1, fEnvA1=0.01, fEnvD1=1, fEnvR1=1, fEnvHiInvert1=1,
                    filtAmp1, sineAmp1, aEnvA1, aEnvD1, aEnvS1, aEnvR1,
                    velToFilt1, velToAmp1,
                    presToFilt1, presToAmp1,
                    layerLfoToPw1, 
                    filtKeyfollowLo1, filtKeyfollowHi1, ampKeyfollowLo1, ampKeyfollowHi1,
                    layerAmp1,
                    // layer 2
                    pitchRatio2=1,
                    layerLfoFreq2, pw2, noise2,
                    hpfFreq2, hpfRes2, lpfFreq2, lpfRes2,
                    fEnvI2, fEnvPeak2, fEnvA2, fEnvD2, fEnvR2, fEnvHiInvert2,
                    filtAmp2, sineAmp2, aEnvA2, aEnvD2, aEnvS2, aEnvR2,
                    velToFilt2, velToAmp2,
                    presToFilt2, presToAmp2,
                    layerLfoToPw2, 
                    filtKeyfollowLo2, filtKeyfollowHi2, ampKeyfollowLo2, ampKeyfollowHi2,
                    layerAmp2,
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
                        pw, noise, noiseUgen,
                        hpfFreq, hpfRes, lpfFreq, lpfRes,
                        fEnvI, fEnvPeak, fEnvA, fEnvD, fEnvR, fEnvHiInvert,
                        filtAmp, sineAmp, aEnvA, aEnvD, aEnvS, aEnvR,
                        velToFilt, velToAmp,
                        presToFilt, presToAmp,
                        layerLfoToPw, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollowLo, filtKeyfollowHi, ampKeyfollowLo, ampKeyfollowHi,
                        layerAmp |
                        var sound;
                        var layerLfo;
                        var filterEnv, ampEnv;
                        var lpfMod, hpfMod;
                        var modLpfFreq, modHpfFreq, modLayerLfoFreq, modAmp, modPw;
                        var filtFreqRatio = keyRatio**((keyRatio > 1).if(filtKeyfollowHi, -1*filtKeyfollowLo));
                        var ampRatio = (keyRatio**((keyRatio > 1).if(ampKeyfollowHi, -1*ampKeyfollowLo))).clip(0, 4);
                        filterEnv = EnvGen.kr(
                            Env.new(levels: [fEnvI, fEnvPeak, 0, fEnvI], times: [fEnvA, fEnvD, fEnvR], releaseNode: 2), 
                            gate,
                            doneAction: Done.none);
                        ampEnv = EnvGen.kr(Env.adsr(aEnvA, aEnvD, aEnvS, aEnvR), gate, doneAction: Done.none);

                        lpfMod = (
                            (globalLfoToFilterFreq*globalLfo) +
                            (pressure*presToGlobalLfoToFilterFreq*globalLfo) + 
                            (3*filterEnv) + 
                            (presToFilt*pressure) + 
                            (velToFilt*velocity) +
                            (0.6*globalBrilliance));
                        modLpfFreq = lpfFreq * filtFreqRatio * lpfMod.linexp(-7.6, 7.6, 1/200, 200);

                        hpfMod = (
                            (fEnvHiInvert*(
                                (globalLfoToFilterFreq*globalLfo) +
                                (pressure*presToGlobalLfoToFilterFreq*globalLfo) + 
                                (3*filterEnv))) -
                            (presToFilt*pressure) -
                            (velToFilt*velocity) - 
                            (0.6*globalBrilliance)
                        );
                        modHpfFreq = hpfFreq * filtFreqRatio * hpfMod.linexp(-7.6, 7.6, 1/200, 200);
                        // modLpfFreq = lpfFreq * (globalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/4, 4);
                        // modLpfFreq = modLpfFreq * filtFreqRatio;
                        // modLpfFreq = modLpfFreq * (pressure*presToGlobalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/4, 4);
                        // modLpfFreq = modLpfFreq * filterEnv.linexp(-1, 1, 1/16, 16);
                        // modLpfFreq = modLpfFreq * (presToFilt*pressure).linexp(-1, 1, 1/2, 2);
                        // modLpfFreq = modLpfFreq * (velToFilt*velocity).linexp(-1, 1, 1/2, 2);
                        // modLpfFreq = modLpfFreq * globalBrilliance.linexp(-1, 1, 5/8, 8/5);
                        modLpfFreq = modLpfFreq.clip(20, 17000);

                        // modHpfFreq = hpfFreq * (fEnvHiInvert*globalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/4, 4);
                        // modHpfFreq = modHpfFreq * filtFreqRatio;
                        // modHpfFreq = modHpfFreq * (fEnvHiInvert*pressure*presToGlobalLfoToFilterFreq*globalLfo).linexp(-1, 1, 1/4, 4);
                        // modHpfFreq = modHpfFreq * (fEnvHiInvert*filterEnv).linexp(-1, 1, 1/4, 4);
                        // modHpfFreq = modHpfFreq * (presToFilt*pressure).linexp(-1, 1, 2, 1/2);
                        // modHpfFreq = modHpfFreq * (velToFilt*velocity).linexp(-1, 1, 2, 1/2);
                        // modHpfFreq = modHpfFreq * globalBrilliance.linexp(-1, 1, 8/5, 5/8);
                        modHpfFreq = modHpfFreq.clip(20, 17000);

                        // Our main oscs
                        sound = switch(waveform.asSymbol,
                            \X, {0},
                            \S, {Saw.ar(freq)},
                            \P, {
                                    layerLfo = FSinOsc.kr(layerLfoFreq);
                                    modPw = pw / (1 + (layerLfoToPw*layerLfo.range(0, 1)));
                                    Pulse.ar(freq, width: modPw);
                                },
                            \B, { // When both waves are required, efficiency demands we use the LF versions.
                                    layerLfo = FSinOsc.kr(layerLfoFreq);
                                    modPw = pw / (1 + (layerLfoToPw*layerLfo.range(0, 1)));
                                    0.5*(LFPulse.ar(freq, width: modPw) + LFSaw.ar(freq));
                                },
                            {0});
                        
                        // Add some noise
                        sound = sound + (noise*noiseUgen);

                        // Filter stage
                        sound = RHPF.ar(sound, modHpfFreq, (hpfRes + (0.5*globalResonance)).linexp(0, 1, 1.2, 0.05));
                        sound = RLPF.ar(sound, modLpfFreq, (lpfRes + (0.5*globalResonance)).linexp(0, 1, 1.2, 0.05));

                        // Mix with sine.
                        sound = (filtAmp * sound) + (sineAmp * FSinOsc.ar(freq));

                        // Velocity to amp
                        ampEnv = LinSelectX.kr(velToAmp, [ampEnv, velocity*ampEnv]);
                        // Pressure to amp
                        ampEnv = LinSelectX.kr(presToAmp, [ampEnv, pressure*ampEnv]);
                        // Global LFO to amp
                        ampEnv = LinSelectX.kr(globalLfoToAmp, [ampEnv, globalLfo.range(0, 1)*ampEnv]);

                        // Amp envelope.
                        sound = layerAmp*ampEnv*ampRatio*sound;              
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
                        pw1, noise1, noiseUgen,
                        hpfFreq1, hpfRes1, lpfFreq1, lpfRes1,
                        fEnvI1, fEnvPeak1, fEnvA1, fEnvD1, fEnvR1, fEnvHiInvert1,
                        filtAmp1, sineAmp1, aEnvA1, aEnvD1, aEnvS1, aEnvR1,
                        velToFilt1, velToAmp1,
                        presToFilt1, presToAmp1,
                        layerLfoToPw1, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollowLo1, filtKeyfollowHi1, ampKeyfollowLo1, ampKeyfollowHi1,
                        layerAmp1);
                    layer2 = layer.value(
                        tup[1].asSymbol,
                        keyRatio,
                        (detuneRatio.reciprocal*pitchRatio2*modFreq)+driftAddition, velocity, pressure, gate,
                        globalLfo,
                        layerLfoFreq2,
                        pw2, noise2, noiseUgen,
                        hpfFreq2, hpfRes2, lpfFreq2, lpfRes2,
                        fEnvI2, fEnvPeak2, fEnvA2, fEnvD2, fEnvR2, fEnvHiInvert2,
                        filtAmp1, sineAmp1, aEnvA2, aEnvD2, aEnvS2, aEnvR2,
                        velToFilt2, velToAmp2,
                        presToFilt2, presToAmp2,
                        layerLfoToPw2, 
                        globalLfoToFilterFreq, presToGlobalLfoToFilterFreq,
                        globalLfoToAmp, presToGlobalLfoToAmp,
                        filtKeyfollowLo2, filtKeyfollowHi2, ampKeyfollowLo2, ampKeyfollowHi2,
                        layerAmp2);
                    mixed = LinSelectX.ar(mix, [layer1, layer2]);
                    DetectSilence.ar(mixed+Impulse.ar(0), doneAction: Done.freeSelf);
                    mixed = amp*mixed;
                    Out.ar(out, Pan2.ar(mixed, pan));
                }).add;
            };
    }

    *initClass {
        params = (
            globalLfoFreq: 4, presToGlobalLfoFreq: 0, 
            globalLfoShape: 0, globalLfoSync: 1, globalLfoIndividual: 1,

            waveform1: 1, pitchRatio1: 1,
            layerLfoFreq1: 3, pw1: 0.4, noise1: 0,
            hpfFreq1: 60, hpfRes1: 0.5, lpfFreq1: 600, lpfRes1: 0.5,
            fEnvI1: 0, fEnvPeak1: 1, fEnvA1: 0.01, fEnvD1: 1, fEnvR1:1, fEnvHiInvert1: 1,
            filtAmp1: 1, sineAmp1: 0, aEnvA1: 0.01, aEnvD1: 1, aEnvS1: 0.5, aEnvR1: 1,
            velToFilt1: 0.2, velToAmp1: 0.8, presToFilt1: 0.5, presToAmp1: 0.5,
            layerLfoToPw1: 0.1, 
            filtKeyfollowLo1: 0, filtKeyfollowHi1: 0, ampKeyfollowLo1: 0, ampKeyfollowHi1: 0,
            layerAmp1: 1,

            waveform2: 2, pitchRatio2: 1,
            layerLfoFreq2: 3, pw2: 0.4, noise2: 0,
            hpfFreq2: 600, hpfRes2: 0.5, lpfFreq2: 1200, lpfRes2: 0.5,
            fEnvI2: 0, fEnvPeak2: 1, fEnvA2: 0.01, fEnvD2: 1, fEnvR2:1, fEnvHiInvert2: 1,
            filtAmp2: 1, sineAmp2: 0, aEnvA2: 0.01, aEnvD2: 1, aEnvS2: 0.5, aEnvR2: 1,
            velToFilt2: 0.2, velToAmp2: 0.8, presToFilt2: 0.5, presToAmp2: 0.5,
            layerLfoToPw2: 0.1, 
            filtKeyfollowLo2: 0, filtKeyfollowHi2: 0, ampKeyfollowLo2: 0, ampKeyfollowHi2: 0,
            layerAmp2: 1,

            globalLfoToFreq: 0, presToGlobalLfoToFreq: 0, 
            globalLfoToFilterFreq: 0, presToGlobalLfoToFilterFreq: 0,
            globalLfoToAmp: 0, presToGlobalLfoToAmp: 0,
            mix: 0.5, globalBrilliance: 0, globalResonance: 0,
            detune: 0, drift: 0,
            pitchEnvAmount: 0, portomento: 0,
            amp: 0.25,      
        );
		voices = nil!8;
        pressures = 0!8;
        lfos = nil!8;
		lastAction = 0;
        StartUp.add {
            var lfoOptions = [
                \doubledeckerLfoSine, 
                \doubledeckerLfoSaw, 
                \doubledeckerLfoRamp, 
                \doubledeckerLfoSquare, 
                \doubledeckerLfoRand, 
                \doubledeckerLfoSmooth];
            OSCFunc.new({ |msg, time, addr, recvPort|
                var voice = msg[1].asInteger;
                var hz = msg[2].asFloat;
                var velocity = msg[3].asFloat;
                DoubleDecker.dynamicInit();
                Routine.new({
                    var lfoLoc = (params.globalLfoIndividual > 0).if(voice, 0);
                    if (noiseSynth == nil, {
                        noiseSynth = Synth.new(
                            \doubledeckerNoise, 
                            [\out, noiseBus],
                            target:lfoGroup);
                        Server.default.sync;
                    });
                    if(lfos[lfoLoc] == nil, {
                        lfos[lfoLoc] = Synth.new(
                            lfoOptions[params.globalLfoShape.asInteger], 
                            [
                                \out, lfoBusses[voice], 
                                \globalLfoFreq, params.globalLfoFreq,
                                \presToGlobalLfoFreq, params.presToGlobalLfoFreq,
                                \pressure, 0
                            ],
                            target:lfoGroup);
                        lfos[lfoLoc].onFree({
                            lfos[lfoLoc] = nil;
                        });
                    });
                    if(voices[voice] == nil, {
                        var l1 = [\X, \S, \P, \B][params.waveform1];
                        var l2 = [\X, \S, \P, \B][params.waveform2];
                        // "waveform 1 % l1 %\n".postf(params.waveform1, l1);
                        voices[voice] = Synth.new(
                            ("doubledecker" ++ l1 ++ l2), 
                            [
                                \freq, hz, 
                                \velocity, velocity, 
                                \globalLfoBus, lfoBusses[voice],
                                \noiseBus, noiseBus,
                            ]++params.asPairs,
                            target: group);
                        voices[voice].onFree({
                            var allOff;
                            voices[voice] = nil;
                            allOff = voices.every({|x, i| x == nil});                            
                            if(allOff && (noiseSynth != nil), {
                                noiseSynth.free;
                                noiseSynth = nil;
                            });
                            if(params.globalLfoSync > 0, {
                                if(params.globalLfoIndividual > 0, {
                                    lfos[voice].free;
                                }, {
                                    if(allOff, {
                                        lfos.do(_.free);
                                        pressures = 0!8;
                                    });
                                });
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
                if (params.globalLfoIndividual > 0, {
                    if(lfos[voice] != nil, {
                        lfos[voice].set(key, value);
                        //"% %\n".postf(key, value);                    
                    });
                }, {
                    if(key == \pressure, {
                        pressures[voice] = value;
                        if(lfos[0] != nil, {
                            lfos[0].set(key, pressures.maxItem)
                        });
                    });
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

            OSCFunc.new({ |msg, time, addr, recvPort|
                voices.do(_.free);
                lfos.do(_.free);
            }, "/doubledecker/all_off")
        }
    }
}