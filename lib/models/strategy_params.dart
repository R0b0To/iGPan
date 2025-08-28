// This class holds the parameters required for the heavy strategy generation logic.
// An instance of this class will be passed to the isolate.
class StrategyGenerationParams {
  final int raceLaps;
  final String trackId;
  final double tyreEconomy;

  StrategyGenerationParams({
    required this.raceLaps,
    required this.trackId,
    required this.tyreEconomy,
  });
}
