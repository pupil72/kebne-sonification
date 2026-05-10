(
var robinIndex = 0;
var orchestraSize = 10;
~amps = Array.fill(orchestraSize, { Ref(0.3) });
~applyPatternVariations = false!orchestraSize;
~robinCycleLength = 2;

// Round-robin mechanism
~makeRobin = {
	var scrambled, firstGroup, secondGroup;
	if (robinIndex == orchestraSize) {
		~amps.do { |ref| ref.value = 0.15 };
		~applyPatternVariations = true!orchestraSize;
	}
	{
		scrambled = (Array.series(10, 0, 1)).scramble;
		firstGroup = scrambled.keep(4);
		secondGroup = scrambled.keep(-6);
		firstGroup.do {|i|
			~amps[i].value = 0;
		};
		secondGroup.do {|i|
			~amps[i].value = 0.05;
		};
		~applyPatternVariations = false!orchestraSize;
		~amps[robinIndex.mod(orchestraSize)].value = 0.7;
		~applyPatternVariations[robinIndex.mod(orchestraSize)] = true;
	};

	robinIndex = (robinIndex + 1) % (orchestraSize + 1);
};
)