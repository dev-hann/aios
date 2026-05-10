import 'dart:async';

abstract class GateCompleter {
  Completer<bool>? _completer;

  Future<bool> waitForResolution({
    required Duration timeout,
    required String tag,
    required String label,
  }) async {
    final completer = _completer;
    if (completer == null) return false;
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      print('[$tag] Timeout waiting for: $label');
      return false;
    }
  }

  void resolve({required bool value}) {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void cancel() {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  void createCompleter() {
    _completer = Completer<bool>();
  }
}
