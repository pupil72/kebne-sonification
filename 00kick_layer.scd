(
{
	var totData = [ Ref(0), Ref(0), Ref(0), Ref(0) ]; // [procs, thermal, memusage, IBtx]
	var tempBatch = nil!4; // [procs, thermal, memusage, IBtx]
	var histories = nil!4; // [procs, thermal, memusage, IBtx]
	var minmax = nil!4; // [procs, thermal, memusage, IBtx]
	var batchData = [ Ref(0.1), Ref(1), Ref(0), Ref(0) ]; // [density, ?, bigness, revdelay]
	var historiesIndex = 0!4, historiesSize = 8!4, window = 2;
	var startRobin;
	var delayOn = Ref(0);
	var batch_count = 0, cycle = 0, isDataFinished = false;
	var sounds_folder = PathName.new(thisProcess.nowExecutingPath.dirname.dirname ++ "/snds");
	var kick_path = sounds_folder.entries.detect { |entry| entry.fileName.contains("kick") }.fullPath;
	var kick_buf = Buffer.readChannel(s, kick_path, channels: 0);
	var totDataCount = 0;

	var buildPattern = {
		var kick_hit = Pbind(
			\instrument, \kick,
			\amp, Pfunc({ ~amps[0].value }),
			\delayOn, Pfunc({ delayOn.value }),
			\iodelayAmp, Pif(~applyPatternVariations[0], Pfunc({ batchData[3].value }), 0)
		);
		makeKickPattern.(batchData[0].value, batchData[2].value, kick_hit);
	};

	var applybigness = { |pattern, bigness|
		var increment = bigness / (pattern.size - 1);
		(1..pattern.size-1).do{|index|
			var evBigness = 1 + ((index-1) * increment);
			pattern[index].put(\bigness, evBigness);
		};
		pattern;
	};

	var makeKickPattern = { |density, bigness, kick_hit|
		if (batchData[0].value < 0.1) {
			var singleHitPattern = [(\dur: 1)];
			Pn(Pchain(Pseq(singleHitPattern), kick_hit), 1);
		} {
			var base = [0, 8, 16, 24];
			var extra_positions = [2, 4, 6, 7, 10, 12, 14, 15, 18, 20, 22, 23, 26, 28, 30, 31];
			var quantity = density.linlin(0.1, 1, 0, extra_positions.size).asInteger;
			var selected = extra_positions.scramble.keep(quantity);
			var positions = (base ++ selected).sort;
			var pattern = [];
			var offset = positions[0] * 0.125;
			pattern = pattern.add(( \dur: Rest(offset) )); //this add an extra event at the beginning which must be skipped later when applying regularity and bigness
			positions.doAdjacentPairs { |a, b|
				var ev = (\dur: (b - a) * 0.125);
				if ([2, 6, 7, 10, 14, 15, 18, 22, 23, 26, 30, 31].includes(a) and: {~applyPatternVariations[0]}) {
					ev[\amp] = 0.35;
				};
				pattern = pattern.add(ev);
			};

			pattern = pattern.add((\dur: (32 - positions.last) * 0.125));
			if(~applyPatternVariations[0]){
				pattern = applybigness.(pattern, bigness);
			};
			Pn(Pchain(Pseq(pattern), kick_hit), inf);
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

	var maybeUpdateKick = {
		("/*kick batch_count" + batch_count ++ "*/").postln;

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
				batchData[1].value = 1; //?
				batchData[2].value = 0; //bigness
				batchData[3].value = 0; //revdelay
			}
			{
				delayOn.value = 0;
			};

			AppClock.sched(0.1, {
				"KICK".postln;
				("Density: " ++ batchData[0].value
					++ " | ???: " ++ batchData[1].value
					++ " | Bigness: " ++ batchData[2].value
					++ " | Revdelay: " ++ batchData[3].value
				).postln;

				if(~amount == 0)
				{
					if((batch_count - 1).mod(~robinCycleLength) == 0)
					{~makeRobin.() } //only kick calls ~makeRobin!!!
				}
				{ cycle = rrand(1,1) };

				~updateKick.();
			});
		};

		totData.do { |ref, i| ref.value = 0.0 };
		totDataCount = 0;
		batch_count = batch_count + 1;
	};

	~handleKickMetric = { |msg|
		var number = msg[3].asString.findRegexpAt("\\d+", 4).asFloat;
		if ((number[0] >= 1501) && (number[0] <= 1510)) {
			totData[totDataCount].value = totData[totDataCount].value + msg[4].asFloat;
			totDataCount = (totDataCount + 1) % totData.size;
			if (isDataFinished == false){
				isDataFinished = true;
				Routine({
					2.wait;
					maybeUpdateKick.();
					isDataFinished = false;
				}).play;
			};
		};
	};

	~updateKick = {
		if (~kick_player.notNil) {
			~kick_player.stop;
		};
		if (~player_playing[0])
		{~kick_player = buildPattern.().play(~tempo, quant: 0)};
	};

	SynthDef(\kick, {
		arg amp = 1, delayOn = 0, bigness = 1, iodelayAmp = 0;
		var sig, sig2, iodelay, delayed, env, finalSig;
		var delayTime = 64/60/8;
		var iodelayValues = iodelayAmp.linlin(0,1,0,0.75);
		var rel = Select.kr(delayOn, [BufDur.kr(kick_buf), 2]);
		env = Env([0, 1.5, 0],[0.01, rel],[-5]).kr(2);
		sig = PlayBuf.ar(1, kick_buf, BufRateScale.kr(kick_buf) * bigness);

		delayed = LocalIn.ar(1);
		sig2 = sig + delayed;
		delayed = DelayC.ar(sig2, 0.3, 0.2);
		LocalOut.ar(delayed);

		sig = Select.ar(delayOn, [sig, sig + delayed]);
		iodelay = DelayN.ar(sig, delayTime, delayTime);
		iodelay = FreeVerb.ar(iodelay, iodelayValues, iodelayValues, iodelayValues);
		sig = sig + (iodelay * iodelayValues);
		sig = Pan2.ar(sig, -0.5);
		Out.ar(~main_bus, sig * env * amp);
	}).add;

}.value;
)

