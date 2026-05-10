(
{
	var totData = [ Ref(0), Ref(0), Ref(0), Ref(0) ]; // [procs, thermal, memusage, IBtx]
	var tempBatch = nil!4; // [procs, thermal, memusage, IBtx]
	var histories = nil!4; // [procs, thermal, memusage, IBtx]
	var minmax = nil!4; // [procs, thermal, memusage, IBtx]
	var batchData = [ Ref(0.1), Ref(0), Ref(0), Ref(0) ]; // [density, ?, bigness, revdelay]
	var historiesIndex = 0!4, historiesSize = 8!4, window = 2;
	var delayOn = Ref(0);
	var batch_count = 0, cycle = 0, isDataFinished = false;
	var totDataCount = 0;
	var bassBus = Bus.new(s);

	var reverbPattern = Pbind(
		\instrument, \reverb,
		\dur, inf,
		\delayOn, Pfunc({ delayOn.value }),
		\iodelayAmp, Pif( ~applyPatternVariations[7], Pfunc({ batchData[3].value }), 0),
	).play;

	var buildPattern = {
		var bass_sound = Pbind(
			\instrument, \bass,
			\octave, -2,
			\root, ~root,
			\amp, Pfunc({ ~amps[7].value }),
		);
		makeBassPattern.(batchData[0].value, batchData[2].value, bass_sound);
	};

	var applybigness = { |pattern, bigness|
		var increment = bigness / (pattern.size - 1);
		(1..pattern.size-1).do{|index|
			var evBigness = (index-1) * increment * 40;
			pattern[index].put(\bigness, evBigness);
		};
		pattern;
	};

	var makeBassPattern = { |density, bigness, bass_hit|
		if(batchData[0].value < 0.1) {
			var singleHitPattern = [(\dur: 1)];
			Pn(Pchain(Pseq(singleHitPattern), bass_hit), 1);
		} {
			var base = [0, 8, 16, 24];
			var extra_positions = [1, 3, 4, 6, 7, 10, 12, 13, 14,
				18, 19, 21, 22, 26, 27, 29, 30, 31];
			var quantity = density.linlin(0.1, 1, 0, extra_positions.size).asInteger;
			var selected = extra_positions.scramble.keep(quantity);
			var lastIndex;
			~bassPositions = (base ++ selected).sort;
			lastIndex = ~bassPositions.size - 1;

			~bassPattern = ~bassPositions.collect { |pos, i|
				var nextPos = if (i == lastIndex) { 32 } { ~bassPositions[i + 1] };
				var dur = (nextPos - pos) * 0.125;
				var ev = (dur: dur);
				ev[\note] = if(extra_positions.includes(pos)) {
					[0, 12, -7, -5, -4].wchoose([0.3, 0.1, 0.2, 0.2, 0.2])
				} {
					0
				};

				ev
			};

			if(~applyPatternVariations[7]){
				~bassPattern = applybigness.(~bassPattern, bigness);
			};
			Pn(Pchain(Pseq(~bassPattern), bass_hit), inf)
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

	var maybeUpdateBass = {
		"".postln;
		("/*bass batch_count" + batch_count ++ "*/").postln;

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
				"BASS".postln;
				("Density: " ++ batchData[0].value
					++ " | ???: " ++ batchData[1].value
					++ " | Bigness: " ++ batchData[2].value
					++ " | Revdelay: " ++ batchData[3].value
				).postln;

				if(~amount != 0) { cycle = rrand(1,1) };

				~updateBass.();

			});
		};

		totData.do { |ref, i| ref.value = 0 };
		totDataCount = 0;
		batch_count = batch_count + 1;
	};

	~handleBassMetric = {|msg|
		var number = msg[3].asString.findRegexpAt("\\d+", 4).asFloat;
		if (((number[0] == 849) || (number[0] == 850)) ||
			((number[0] == 949) || (number[0] == 950)) ||
			((number[0] == 1049) || (number[0] == 1050)) ||
			((number[0] == 1201) || (number[0] == 1202))) {
			totData[totDataCount].value = totData[totDataCount].value + msg[4].asFloat;
			totDataCount = (totDataCount + 1) % totData.size;
			if (isDataFinished == false){
				isDataFinished = true;
				Routine({
					2.wait;
					maybeUpdateBass.();
					isDataFinished = false;
				}).play;
			};
		};
	};

	~updateBass = {
		if (~bass_player.notNil) {
			~bass_player.stop;
		};
		if (~player_playing[7])
		{~bass_player = buildPattern.().play(~tempo, quant: 0)};
	};

	SynthDef(\bass, {
		arg freq = 65.4, amp = 1, bigness = 0;
		var env, sig, sig2, filter, dist;
		env = EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2);
		sig = SinOsc.ar(freq) * env;
		sig = RLPF.ar(sig, freq);
		sig = tanh(sig * 4);
		sig2 = Blip.ar(freq, bigness) * env;
		sig = sig + sig2;
		sig = Pan2.ar(sig, 0.2);
		Out.ar(bassBus, sig * (amp*0.2));
	}).add;

	SynthDef(\reverb, {
		arg iodelayAmp = 0, delayOn = 0;
		var env, sig, sig2, iodelay, delayed;
		var delayTime = 64/60/8;
		sig = In.ar(bassBus,2);

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