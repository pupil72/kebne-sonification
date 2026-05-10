(
Buffer.freeAll;
s.options.memSize = 2.pow(20);
s.recHeaderFormat = "caf";
s.recSampleFormat = "int16";
~tempo = TempoClock(64 / 60);
~root = 60;
s.waitForBoot({
	var broadcastToHandlers;

	//BUSES
	~main_bus = Bus.audio(s, 2);

	//INSTRUMENTS
	(thisProcess.nowExecutingPath.dirname ++ "/global_effects.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/gui.scd").load;

	(thisProcess.nowExecutingPath.dirname ++ "/00kick_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/01snare_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/02hats_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/03clap_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/04shaker_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/05subbass_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/06Fvoice_layer.scd").load;
	//bass MUST always go before chords because chords' roots depend on bass' notes!!
	(thisProcess.nowExecutingPath.dirname ++ "/07bass_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/08chords_layer.scd").load;
	(thisProcess.nowExecutingPath.dirname ++ "/09Mvoice_layer.scd").load;

	//s.record;
	s.sync;

	broadcastToHandlers = { |msg|
		~handleKickMetric.(msg);
		~handleSnareMetric.(msg);
		~handleHatsMetric.(msg);
		~handleClapMetric.(msg);
		~handleShakerMetric.(msg);
		~handleSubbassMetric.(msg);

		~handleFVoiceMetric.(msg);
		~handleBassMetric.(msg);
		~handleChordsMetric.(msg);
		~handleMVoiceMetric.(msg);
	};

	OSCdef(\data_procs, broadcastToHandlers, '/procs');
	OSCdef(\data_thermal, broadcastToHandlers, '/thermal');
	OSCdef(\data_memusage, broadcastToHandlers, '/memusage');
	OSCdef(\data_Ibtx, broadcastToHandlers, '/IB-tx');

	SynthDef.new(\main_out,{
		arg amp, in, out;
		var sig;
		sig = In.ar(in, 2);
		Out.ar(out, sig * amp);
	}).add;

	s.sync;

	//CREATE SYNTH
	~main_out = Synth.new(\main_out, [\in, ~main_bus, \out, 0, \amp, 1], addAction: \addToTail);

	s.sync;

	AppClock.sched(0.0, {
		~updateKick.();
		~updateSnare.();
		~updateHats.();
		~updateClap.();
		~updateShaker.();
		~updateSubbass.();

		~updateFVoice.();
		~updateBass.();
		~updateChords.();
		~updateMVoice.();
	});
});
)









