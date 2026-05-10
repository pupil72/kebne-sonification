(
{
	var totData = [ Ref(0), Ref(0), Ref(0), Ref(0) ]; // [procs, memusage, IBtx]
	var tempBatch = nil!4; // [procs, memusage, IBtx]
	var histories = nil!4; // [procs, memusage, IBtx]
	var minmax = nil!4; // [procs, memusage, IBtx]
	var batchData = [ Ref(0.1), Ref(1), Ref(0), Ref(0) ]; // [density, ?, bigness, revdelay]
	var historiesIndex = 0!4, historiesSize = 8!4, window = 2;
	var delayOn = Ref(0);
	var batch_count = 0, cycle = 0, isDataFinished = false;
	var sounds_folder = PathName.new(thisProcess.nowExecutingPath.dirname.dirname ++ "/snds");
	var re_path = sounds_folder.entries.detect { |entry| entry.fileName.contains("reach_short") }.fullPath;
	var reach_path = sounds_folder.entries.detect { |entry| entry.fileName.contains("reach_long") }.fullPath;
	var re_buf = Buffer.readChannel(s, re_path, channels: 0);
	var reach_buf = Buffer.readChannel(s, reach_path, channels: 0);
	var totDataCount = 0;

	var buildPattern = {
		var reach_hit = Pbind(
			\amp, Pfunc({ ~amps[6].value }), //~amps[2].value
			\delayOn, Pfunc({ delayOn.value }),
			\iodelayAmp, Pif( ~applyPatternVariations[6], Pfunc({ batchData[3].value }), 0)
		);
		makeFVoicePattern.(batchData[0].value, batchData[2].value, reach_hit);
	};

	var applybigness = { |pattern, bigness|
		var increment = (bigness / (pattern.size - 1)) / 6;
		(1..pattern.size-1).do{|index|
			var evBigness = 1 + ((index-1) * increment);
			pattern[index].put(\bigness, evBigness);
		};
		pattern;
	};

	var makeFVoicePattern = { |density, bigness, reach_hit|
		if(batchData[0].value < 0.1) {
			var singleHitPattern = [ (\instrument: \reach, \dur: 1) ];
			Pn(Pchain(Pseq(singleHitPattern), reach_hit), 1);
		} {
			var base = [0, 8, 16, 24];
			var extra_positions = [1, 3, 5, 6, 9, 11, 13, 14, 17, 19, 21, 22, 25, 27, 29, 30];
			var quantity = density.linlin(0.1, 1, 0, extra_positions.size).asInteger;
			var selected = extra_positions.scramble.keep(quantity);
			var positions = (base ++ selected).sort;
			var pattern = [];
			var offset = positions[0] * 0.125;
			var tailDur;
			pattern = pattern.add(( \dur: Rest(offset) ));

			positions.doAdjacentPairs { |a, b|
				var dur = (b - a) * 0.125;
				var ev = (
					\dur: dur,
					\instrument: if(dur >= 0.625) { \reach } { \re }
				);
				pattern = pattern.add(ev);
			};

			tailDur = (32 - positions.last) * 0.125;
			pattern = pattern.add((
				\dur: tailDur,
				\instrument: if(tailDur >= 0.625) { \reach } { \re }
			));
			if(~applyPatternVariations[6]){
				pattern = applybigness.(pattern, bigness);
			};
			Pn(Pchain(Pseq(pattern), reach_hit), inf);
		};
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

	var maybeUpdateFVoice = {
		("/*f_voice batch_count" + batch_count ++ "*/").postln;

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

			if (batchData[0].value < 0.1)
			{
				delayOn.value = 1;
				batchData[1].value = 1; //?
				batchData[2].value = 0; //bigness
				batchData[3].value = 0; //revdelay
			}
			{
				delayOn.value = 0;
			};

			AppClock.sched(0.1, {
				"F_VOICE".postln;
				("Density: " ++ batchData[0].value
					++ " | ???: " ++ batchData[1].value
					++ " | Bigness: " ++ batchData[1].value
					++ " | Revdelay: " ++ batchData[2].value
				).postln;

				if(~amount != 0) { cycle = rrand(1,1) };

				~updateFVoice.();

			});
		};

		totData.do { |ref, i| ref.value = 0 };
		totDataCount = 0;
		batch_count = batch_count + 1;
	};

	~handleFVoiceMetric = { |msg|
		var number = msg[3].asString.findRegexpAt("\\d+", 4).asFloat;
		if (((number[0] >= 1401) && (number[0] <= 1407)) ||
			((number[0] >= 1409) && (number[0] <= 1430)) ||
			((number[0] >= 1432) && (number[0] <= 1434)) ||
			((number[0] >= 1436) && (number[0] <= 1440)) ||
			((number[0] >= 1511) && (number[0] <= 1522))) {
			totData[totDataCount].value = totData[totDataCount].value + msg[4].asFloat;
			totDataCount = (totDataCount + 1) % totData.size;
			if (isDataFinished == false){
				isDataFinished = true;
				Routine({
					2.wait;
					maybeUpdateFVoice.();
					isDataFinished = false;
				}).play;
			};
		};
	};

	~updateFVoice = {
		if (~fvoice_player.notNil) {
			~fvoice_player.stop;
		};
		if (~player_playing[6])
		{~fvoice_player = buildPattern.().play(~tempo, quant: 0)};
	};

	SynthDef(\re, {
		arg amp = 1, delayOn = 0, bigness = 1, iodelayAmp = 0;
		var sig, sig2, iodelay, delayed, env, finalSig;
		var delayTime = 64/60/8;
		var iodelayValues = iodelayAmp.linlin(0,1,0,0.75);
		env = Env([0, 2, 0],[0.1, BufDur.kr(re_buf)],[-5]).kr(2);
		sig = PlayBuf.ar(1, re_buf, BufRateScale.kr(re_buf) * bigness);
		iodelay = DelayN.ar(sig, delayTime, delayTime);
		iodelay = FreeVerb.ar(iodelay, iodelayValues, iodelayValues, iodelayValues);
		sig = sig + (iodelay * iodelayValues);
		sig = Pan2.ar(sig, -0.1);
		Out.ar(~main_bus, sig * (amp / 3));
	}).add;

	SynthDef(\reach, {
		arg amp = 1, delayOn = 0, bigness = 1, iodelayAmp = 0;
		var sig, sig2, iodelay, delayed, env, finalSig;
		var delayTime = 64/60/8;
		var iodelayValues = iodelayAmp.linlin(0,1,0,0.75);
		var rel = Select.kr(delayOn, [BufDur.kr(reach_buf), 2.5]);
		env = Env([0, 2, 0],[0.01, rel],[-5]).kr(2);
		sig = PlayBuf.ar(1, reach_buf, BufRateScale.kr(reach_buf) * bigness);

		delayed = LocalIn.ar(2);
		sig2 = sig + delayed;
		delayed = DelayC.ar(sig2, 0.3, 0.2);
		LocalOut.ar(delayed);

		iodelay = DelayN.ar(sig, delayTime, delayTime);
		iodelay = FreeVerb.ar(iodelay, iodelayValues, iodelayValues, iodelayValues);
		sig = Select.ar(delayOn, [sig, sig + delayed * env]);
		sig = sig + (iodelay * iodelayValues);
		sig = Pan2.ar(sig, 0.1);
		Out.ar(~main_bus, sig * env * (amp / 3));
	}).add;

}.value;
)
