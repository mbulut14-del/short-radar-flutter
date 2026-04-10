
import '../models/short_setup_result.dart';

class DetailDataService {
  static ShortSetupResult buildShortSetup({
    required double entry,
    required double stopLoss,
  }) {
    final riskPercent = ((stopLoss - entry) / entry).abs() * 100;

    final target1 = entry - (entry * (riskPercent / 100));
    final target2 = entry - (entry * (riskPercent * 2 / 100));

    final riskReward = 2.0;

    double leverage;
    if (riskPercent <= 2) {
      leverage = 10;
    } else if (riskPercent <= 4) {
      leverage = 5;
    } else {
      leverage = 3;
    }

    final loss5x = riskPercent * 5;
    final loss10x = riskPercent * 10;

    return ShortSetupResult(
      entry: entry,
      stopLoss: stopLoss,
      target1: target1,
      target2: target2,
      riskReward: riskReward,
      riskPercent: riskPercent,
      leverage: leverage,
      loss5x: loss5x,
      loss10x: loss10x,
    );
  }
}
