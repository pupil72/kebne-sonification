(
~tempo = TempoClock(64 / 60);
~root = 60;
{
	var totData = [ Ref(0), Ref(0), Ref(0) ]; // [procs, memusage, IBtx]
	var tempBatch = nil!3; // [procs, memusage, IBtx]
	var histories = nil!3; // [procs, memusage, IBtx]
	var minmax = nil!3; // [procs, memusage, IBtx]
	var batchData = [ Ref(0.1), Ref(0), Ref(0) ]; // [density, bigness, revdelay]
	var historiesIndex = 0!3, historiesSize = 8!3, window = 2;
	var delayOn = Ref(0);
	var batch_count = 0, cycle = 0, isDataFinished = false;
	var totDataCount = 0;
	var chordsBus = Bus.new(s);
	var dict = IdentityDictionary[
		//C-
		0 -> [-7, -5, 0, 3, 7, 12].scramble.keep(3),
		//Ab+
		-4 -> [-4, 0, 3, 8, 12].scramble.keep(3),
		//G-7
		-5 -> [-5, -2, 2, 5, 7, 10].scramble.keep(4),
		//F-7
		-7 -> [-7, -4, 0, 3, 5, 8, 12].scramble.keep(4),
	];

	var reverbPattern = Pbind(
		\instrument, \reverb,
		\dur, inf,
		\delayOn, Pfunc({ delayOn.value }),
		\iodelayAmp, Pif( ~applyPatternVariations[8], Pfunc({ batchData[2].value }), 0)
	).play;

	var buildPattern = {
		var chords_sound = Pbind(
			\instrument, \chords,
			\octave, 0,
			\root, ~root,
			\legato, 0.151,
			\amp, Pfunc({ ~amps[8].value }), // ~amps[7].value
		);
		makeChordsPattern.(batchData[0].value, batchData[1].value, chords_sound);
	};

	var applybigness = { |pattern, bigness|
		var rescaledBigness = bigness.linlin(0, 1, 0.5, 1);
		var delta = 0.5 - rescaledBigness;
		var increment = delta / (pattern.size - 1);
		pattern.size.do{|index|
			var evBigness = 0.5 + (index * increment);
			pattern[index].put(\bigness, evBigness);
		};
		pattern;
	};

	var makeChordsPattern = { |density, bigness, chords_hit|
		if(batchData[0].value < 0.1) {
			var singleHitPattern = [(\dur: 1)];
			Pn(Pchain(Pseq(singleHitPattern), chords_hit), 1);
		} {
			var base = [0, 8, 16, 24];
			var extra_positions = [2, 5, 11, 12, 14, 18, 20, 21, 23, 26, 29, 30, 31];
			var quantity = density.linlin(0.1, 1, 0, extra_positions.size).asInteger;
			var selected = extra_positions.scramble.keep(quantity);
			var chordsPositions = (base ++ selected).sort;

			var pattern = chordsPositions.collect { |pos, i|
				var lastIndex = chordsPositions.size - 1;
				var nextPos = if(i == lastIndex) {
					32
				}
				{
					chordsPositions[i + 1]
				};

				var dur = (nextPos - pos) * 0.125;
				var ev = (dur: dur);
				var bassIdx = ~bassPositions.indexOf(pos);
				ev[\note] = if(bassIdx.isNil) {
					dict.values.choose
				} {
					dict[~bassPattern[bassIdx][\note]]
				};

				ev;
			};

			if(~applyPatternVariations[8]){
				pattern = applybigness.(pattern, bigness);
			};
			Pn(Pchain(Pseq(pattern), chords_hit), inf)
		}
	};

	var calculateData = {
		tempBatch.do{|array, i|
			var avg = array.collect(_.value).sum / window;
			if (i == 2) //if memusage, get min. and max.
			{
				case
				{minmax[i][1] <= 1e-10} {batchData[i].value = 0.0}
				{(minmax[i][1] - minmax[i][0]) / minmax[i][1] <= 1e-10} {/*do nothing*/}
				{true} {batchData[i].value = (avg - minmax[i][0]) / (minmax[i][1] - minmax[i][0])}
			}
			{   //else get only max.
				case
				{minmax[i][1] <= 1e-10} {batchData[i].value = 0.0}
				{true} {batchData[i].value = avg / minmax[i][1]}
			}
		}
	};

	var maybeUpdateChords = {
		//"".postln;
		("/*chords batch_count" + batch_count ++ "*/").postln;

		totData.do{|ref, i|
			if (batch_count == 0) {
				tempBatch[i] =  Array.fill(window, { Ref(0.0) });
				histories[i] = Array.fill(historiesSize[i], ref.value);
				minmax[i] = Array.fill(2, ref.value);
			}
			{
				histories[i].put(historiesIndex[i], ref.value);
				minmax[i][0] = histories[i].minItem;
				minmax[i][1] = histories[i].maxItem;
			};

			historiesIndex[i] = (historiesIndex[i] + 1).mod(historiesSize[i]);
			tempBatch[i][batch_count.mod(window)].value = histories[i][batch_count.mod(historiesSize[i])].value;
		};

		if ((batch_count >= window) && (batch_count.mod(~amount * cycle) == 0)){
			calculateData.();

			if (batchData[0].value < 0.1) //play echo
			{
				delayOn.value = 1;
				batchData[2].value = 0; //bigness
				batchData[3].value = 0; //revdelay
			}
			{
				delayOn.value = 0;
			};

			AppClock.sched(0.1, {
				"CHORDS".postln;
				("Density: " ++ batchData[0].value
					++ " | Bigness: " ++ batchData[1].value
					++ " | Revdelay: " ++ batchData[2].value
				).postln;

				if(~amount != 0) { cycle = rrand(1,1) };

				~updateChords.();

			});
		};

		totData.do { |ref, i| ref.value = 0 };
		totDataCount = 0;
		batch_count = batch_count + 1;
	};

	~handleChordsMetric = {|msg|
		var number = msg[3].asString.findRegexpAt("\\d+", 4).asFloat;
		if ((number[0] >= 1701) && (number[0] <= 1708)) {
			totData[totDataCount].value = totData[totDataCount].value + msg[4].asFloat;
			totDataCount = (totDataCount + 1) % totData.size;
			if (isDataFinished == false){
				isDataFinished = true;
				Routine({
					2.wait;
					maybeUpdateChords.();
					isDataFinished = false;
				}).play;
			};
		};
	};

	~updateChords = {
		if (~chords_player.notNil) {
			~chords_player.stop;
		};
		if (~player_playing[8])
		{~chords_player = buildPattern.().play(~tempo, quant: 0)};
	};

	SynthDef(\chords, {
		arg freq = 261.62, amp = 1, bigness = 0.5;
		var sig, env;
		env = Env.perc(0.01, 0.15).kr(2);
		sig = Mix.fill(4, {	VarSaw.ar(freq *
			(1 + LFNoise1.kr(0.5).range(-0.01, 0.01)), width: bigness) });
		sig = Pan2.ar(sig, 0.3);
		Out.ar(chordsBus, sig * env * (amp/24));
	}).add;

	SynthDef(\reverb, {
		arg iodelayAmp = 0, delayOn = 0;
		var env, sig, sig2, iodelay, delayed;
		var delayTime = 64/60/8;
		sig = In.ar(chordsBus,2);

		delayed = LocalIn.ar(1);
		sig2 = sig + delayed;
		delayed = CombC.ar(sig2, 0.3, 0.2);
		LocalOut.ar(delayed);

		sig = Select.ar(delayOn, [sig, sig + delayed]);
		iodelay = DelayN.ar(sig, delayTime, delayTime);
		iodelay = FreeVerb.ar(iodelay, iodelayAmp, iodelayAmp, iodelayAmp);
		sig = sig + (iodelay * iodelayAmp);
		Out.ar(~main_bus, sig);
	}).add;

}.value;
)

/*
(
~tempo = TempoClock(64 / 60);
s.waitForBoot({
var reverb;
var chordsBus = Bus.new(s);

SynthDef(\chords, {
arg freq = 261.62, amp = 0.2, bigness = 0.5;
var sig, env, filter;
env = Env.perc(0.01, 0.15).kr(2);
sig = Mix.fill(4, {	VarSaw.ar(freq *
(1 + LFNoise1.kr(0.5).range(-0.01, 0.01)), width: bigness) }) / 4;
//filter = RLPF.ar(sig, 1200, 0.1);
//sig = XFade2.ar(sig, filter, SinOsc.kr(1.5).range(0,0.5)); //sort of flanger
//sig = XFade2.ar(sig, filter, 0.5).clip();
sig = Pan2.ar(sig);
Out.ar(chordsBus, sig * env * 0.2);
}).add;

SynthDef(\reverb, {
arg iodelayAmp = 0.8, delayOn = 0;
var env, sig, sig2, iodelay, delayed;
var delayTime = 64/60/8;
sig = In.ar(chordsBus,2);

delayed = LocalIn.ar(1);
sig2 = sig + delayed;
delayed = CombC.ar(sig2, 0.3, 0.2);
LocalOut.ar(delayed);

sig = Select.ar(delayOn, [sig, sig + delayed * env]);
iodelay = DelayN.ar(sig, delayTime, delayTime);
iodelay = FreeVerb.ar(iodelay, iodelayAmp, iodelayAmp, iodelayAmp);
sig = sig + (iodelay * iodelayAmp);
Out.ar(0, sig);
}).add;

s.sync;

//reverb = Synth(\reverb);

~reverbPattern = Pbind(
\instrument, \reverb,
\dur, inf,
).play;

~pattern = Pbind(
\instrument, \chords,
\octave, 0,
\root, 60,
\note, Pseq([
[-4, 0, 3, 7],
[-2, 2, 5],
[0, 3, 7],
[3, 7, 10],
], inf),
\dur, 1,
\legato, 0.151,
\ampmod, 0.4,
\lpfFreq, Pwhite(1500, 2000),
).play(~tempo);
});
)
*/

/*
(
var bassPattern = [
(dur: 1, note: -7), (dur: 1, note: -7), (dur: 1, note: -5),
(dur: 1, note: -4), (dur: 1, note: -4), (dur: 1, note: -5),
(dur: 1, note: -5), (dur: 1, note: -7), (dur: 1, note: -5)
];

var bassPositions = [1, 3, 4, 6, 7, 10, 12, 13, 14];
var chordsPositions = [0, 2, 3, 5, 6, 7, 11, 12];

var dict = IdentityDictionary[
-7 -> [-4, 0, 3, 7],
-5 -> [-1, 0],
-4 -> [2, 8, 9]
];

// ---------------------------------------------------------------

var pattern = chordsPositions.collect { |pos, i|
var lastIndex = chordsPositions.size - 1;
var nextPos = if(i == lastIndex) {
32
}
{
chordsPositions[i + 1]
};

var dur = (nextPos - pos) * 0.125;
var ev = (dur: dur);
var bassIdx = bassPositions.indexOf(pos);

ev[\note] = if(bassIdx.isNil) {
dict.values.choose
} {
dict[ bassPattern[bassIdx][\note] ]
};
};

pattern
)
*/















