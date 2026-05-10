import 'dart:async';

abstract class GateCompleter {
  Completer<bool>? _completer;

  Future<bool> waitForResolution({
    required Duration timeout,
    required String tag,
    required String label,
  }) async {
    try {
      return await _completer!.future.timeout(timeout);
    } on TimeoutException {
      print('[$tag] Timeout waiting for: $label');
      return false;
    }
  }

  void resolve(bool value) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(value);
    }
  }

  void cancel() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(false);
    }
  }

  void createCompleter() {
    _completer = Completer<bool>();
  }
}
