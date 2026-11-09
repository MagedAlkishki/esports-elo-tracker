import 'dart:math' as math;

/// A minimal Dart test harness: no `package:test` (this was built in a
/// sandbox with no network access to pub.dev, so an external testing
/// package wasn't available), just a registry of (name, body) pairs and
/// a runner that prints PASS/FAIL per test and a summary, exiting
/// non-zero on any failure -- enough to be a real, CI-usable test suite.
class TestHarness {
  static final List<(String, void Function())> _tests = [];
  static int _failedInCurrentTest = 0;
  static int _totalFailed = 0;

  static void test(String name, void Function() body) {
    _tests.add((name, body));
  }

  static int runAll() {
    var passed = 0;
    for (final (name, body) in _tests) {
      _failedInCurrentTest = 0;
      print('[RUN ] $name');
      try {
        body();
      } catch (e, stack) {
        _failedInCurrentTest++;
        print('    FAILED: uncaught $e');
        print(stack.toString().split('\n').take(3).map((l) => '      $l').join('\n'));
      }
      if (_failedInCurrentTest > 0) {
        print('[FAIL] $name');
        _totalFailed++;
      } else {
        print('[PASS] $name');
        passed++;
      }
    }
    print('\n${_tests.length} tests, $passed passed, $_totalFailed failed');
    return _totalFailed == 0 ? 0 : 1;
  }

  static void _fail(String message) {
    _failedInCurrentTest++;
    print('    FAILED: $message');
  }

  static void expectEqual<T>(T actual, T expected, [String? label]) {
    if (actual != expected) {
      _fail('${label ?? 'expected'}: expected $expected, got $actual');
    }
  }

  /// Dart's [List] does NOT override `==` to compare elements -- two
  /// different List instances with identical contents are `!=` to each
  /// other (the default is identity comparison, same as plain Object).
  /// expectEqual() on two lists therefore always "fails" even when they
  /// print the same thing, which is exactly as confusing as it sounds.
  /// This does the comparison Dart doesn't give you for free, without
  /// needing the `collection` package's ListEquality (unavailable here
  /// -- no network access to pub.dev in the sandbox this was built in).
  static void expectListEqual<T>(List<T> actual, List<T> expected, [String? label]) {
    final same = actual.length == expected.length &&
        [for (var i = 0; i < actual.length; i++) actual[i] == expected[i]]
            .every((eq) => eq);
    if (!same) {
      _fail('${label ?? 'expected'}: expected $expected, got $actual');
    }
  }

  static void expectClose(double actual, double expected, double tolerance, [String? label]) {
    if ((actual - expected).abs() > tolerance) {
      _fail('${label ?? 'expected'}: expected $expected (±$tolerance), got $actual');
    }
  }

  static void expectTrue(bool condition, [String? message]) {
    if (!condition) {
      _fail(message ?? 'expected true');
    }
  }

  static void expectThrows<T>(void Function() body, [String? label]) {
    try {
      body();
      _fail('${label ?? 'expected'}: expected $T to be thrown, nothing was');
    } on Object catch (e) {
      if (e is! T) {
        _fail('${label ?? 'expected'}: expected $T, got ${e.runtimeType}');
      }
    }
  }

  /// Exposed for tests that want to assert a value is NaN-free / finite,
  /// which is a real failure mode for floating-point rating math.
  static void expectFinite(double value, [String? label]) {
    if (!value.isFinite || value.isNaN) {
      _fail('${label ?? 'expected'}: expected a finite number, got $value');
    }
  }

  static void expectNotNull(Object? value, [String? label]) {
    if (value == null) {
      _fail(label ?? 'expected non-null');
    }
  }
}

// Re-exported so test files don't need a separate `dart:math` import just
// for the occasional use of it (none currently, kept for completeness).
double roundTo(double value, int decimals) {
  final factor = math.pow(10, decimals);
  return (value * factor).round() / factor;
}
