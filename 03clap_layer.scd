(
{
	var totData = [ Ref(0), Ref(0), Ref(0) ]; // [procs, memusage, IBtx]
	var tempBatch = nil!3; // [procs, memusage, IBtx]
	var histories = nil!3; // [procs, memusage, IBtx]
	var minmax = nil!3; // [procs, memusage, IBtx]
	var batchData = [ Ref(0.1), Ref(0), Ref(0) ]; // [density, bigness, revdelay]
	var historiesIndex = 0!3, historiesSize = 8!3, window = 2;
	var delayOn = Ref(0);
	var batch_count = 0, cycle = 0, isDataFinished = false;
	var sounds_folder = PathName.new(thisProcess.nowExecutingPath.dirname.dirname ++ "/snds");
	var clap_path = sounds_folder.entries.detect { |entry| entry.fileName.contains("clap") }.fullPath;
	var clap_buf = Buffer.readChannel(s, clap_path, channels: 0);
	var totDataCount = 0;

	var buildPattern = {
		var clap_hit = Pbind(
			\instrument, \clap,
			\amp, Pfunc({ ~amps[3].value  }),
			\delayOn, Pfunc({ delayOn.value }),
			\iodelayAmp, Pif(~applyPatternVariations[3], Pfunc({ batchData[2].value }), 0)
		);
		makeClapPattern.(batchData[0].value, batchData[1].value, clap_hit);
	};

	var applybigness = { |pattern, bigness|
		var increment = bigness / (pattern.size - 1);
		(1..pattern.size-1).do{|index|
			var evBigness = 1 + ((index-1) * increment);
			pattern[index].put(\bigness, evBigness);
		};
		pattern;
	};

	var makeClapPattern = { |density, bigness, clap_hit|
		if(batchData[0].value < 0.1) {
			var singleHitPattern = [ (\dur: Rest(0.5)), (\dur: 1) ];
			Pn(Pchain(Pseq(singleHitPattern), clap_hit), 1);
		} {
			var base = [4, 12, 20, 28];
			var extra_positions = [2, 7, 8, 10, 15, 16, 18, 22, 25, 26, 30];
			var quantity = density.linlin(0.1, 1, 0, extra_positions.size).asInteger;
			var selected = extra_positions.scramble.keep(quantity);
			var positions = (base ++ selected).sort;
			var pattern = [];
			var offset = positions[0] * 0.125;
			pattern = pattern.add(( \dur: Rest(offset) ));

			positions.doAdjacentPairs { |a, b|
				var ev = ( \dur: (b - a) * 0.125 );
				pattern = pattern.add(ev);
			};

			pattern = pattern.add((\dur: (32 - positions.last) * 0.125));
			if(~applyPatternVariations[3]){
				pattern = applybigness.(pattern, bigness);
			};
			Pn(Pchain(Pseq(pattern), clap_hit), inf)
		}
	};

	var calculateData = {
		tempBatch.do{|array, i|
			var avg = array.collect(_.value).sum / window;

			if (i == 1) //if memusage, get min. and max.
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

	var maybeUpdateClap = {
		("/*clap batch_count" + batch_count ++ "*/").postln;

		totData.do{|ref, i|
			if (batch_count == 0) {
				tempBatch[i] =  Array.fill(window, { Ref(0) });
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
				batchData[1].value = 0;
				batchData[2].value = 0;
			}
			{
				delayOn.value = 0;
			};

			AppClock.sched(0.1, {
				"CLAP".postln;
				("Density: " ++ batchData[0].value
					++ " | Bigness: " ++ batchData[1].value
					++ " | Revdelay: " ++ batchData[2].value
				).postln;

				if(~amount != 0) { cycle = rrand(1,1) };

				~updateClap.();
			});
		};

		totData.do { |ref, i| ref.value = 0 };
		totDataCount = 0;
		batch_count = batch_count + 1;
	};

	~handleClapMetric = { |msg|
		var number = msg[3].asString.findRegexpAt("\\d+", 4).asFloat;
		if (number[0] == 1716) {
			totData[totDataCount].value = totData[totDataCount].value + msg[4].asFloat;
			totDataCount = (totDataCount + 1) % totData.size;
			if (isDataFinished == false){
				isDataFinished = true;
				Routine({
					2.wait;
					maybeUpdateClap.();
					isDataFinished = false;
				}).play;
			};
		};
	};

	~updateClap = {
		if (~clap_player.notNil) {
			~clap_player.stop;
		};
		if (~player_playing[3])
		{~clap_player = buildPattern.().play(~tempo, quant: 0)};
	};

	SynthDef(\clap, {
		arg amp = 1, delayOn = 0, bigness = 1, iodelayAmp = 0;
		var sig, sig2, iodelay, delayed, env, finalSig;
		var delayTime = 64/60/8;
		var iodelayValues = iodelayAmp.linlin(0,1,0,0.75);
		var rel = Select.kr(delayOn, [BufDur.kr(clap_buf), 1.5]);
		env = Env([0, 2, 0],[0.01, rel],[-5]).kr(2);
		sig = PlayBuf.ar(1, clap_buf, BufRateScale.kr(clap_buf) * bigness);

		delayed = LocalIn.ar(1);
		sig2 = sig + delayed;
		delayed = DelayC.ar(sig2, 0.3, 0.2);
		LocalOut.ar(delayed);

		sig = Select.ar(delayOn, [sig, sig + delayed]);
		iodelay = DelayN.ar(sig, delayTime, delayTime);
		iodelay = FreeVerb.ar(iodelay, iodelayValues, iodelayValues, iodelayValues);
		sig = sig + (iodelay * iodelayValues);
		sig = Pan2.ar(sig, -0.2);
		Out.ar(~main_bus, sig * env * amp * (1 + (bigness.reciprocal / 12)));
	}).add;

}.value;
)
