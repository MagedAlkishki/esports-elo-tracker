import 'dart:io';

import 'elo_calculator_test.dart';
import 'elo_tracker_test.dart';
import 'test_harness.dart';

void main() {
  registerEloCalculatorTests();
  registerEloTrackerTests();
  exit(TestHarness.runAll());
}
