(
var container;
var instruments_names = ["kick", "snare", "hats", "clap", "shaker", "subbass", "FVoice", "bass", "chords", "MVoice"];
var instruments_texts = ["kick", "snare", "hats", "clap", "shaker", "subbass", "FVoice", "bass", "chords", "MVoice"];
var buttons, texts, isOn = false;
~player_playing = true!instruments_names.size;
~amount = 0;
Window.closeAll;

container = Window.new("Controls", Rect(200, Window.screenBounds.height - 600, 474, 260), resizable: false).background_(Color.new255(115, 173, 193)).alwaysOnTop_(true).front;

Button(container, Rect(15, 20, 100, 40))
.states_([
	["stop all", Color.black],
	["play all", Color.red]
])
.action_({ |j|
	var newVal = j.value;
	buttons.do({ |btn, index|
		if (index < 10) {
			btn.value_(newVal);
			btn.doAction;
		}
	});
});

StaticText(container, Rect(130, 15, 360, 30))
.string_("round-r.")
.stringColor_(Color.red)
.font_(Font("Helvetica", 12, true));

StaticText(container, Rect(210, 15, 380, 30))
.string_("full")
.font_(Font("Helvetica", 12, true));

Slider(container, Rect(130, 41, 100, 20))
.value_(~amount)
.action_({ |s|
	var step = s.value.linlin(0, 1, 0, 1).round(1).asInteger;
	var snapped = step.linlin(0, 1, 0, 1);
	~amount = snapped;
	if (s.value != snapped) {
		s.value = snapped;
	};
	~amps.do{ |ref| ref.value = 0.15 };
});

buttons = 10.collect({ |index|
	var col = index % 4;
	var row = (index / 4).floor;
	Button(container, Rect(15 + (col * 115), 75 + (row * 60), 100, 40))
	.states_([
		["stop" + instruments_names[index], Color.black],
		["play" + instruments_names[index], Color.red]
	])
	.action_({ |j|
		if(j.value == 1) {
			~amps[index] = 0;
		} {
			~amps[index] = 0.3;
		}
	});
})
)












