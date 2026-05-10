import 'package:aios/domain/agent/tool_context.dart';

class MockToolContext implements ToolContext {
  MockToolContext();

  String? Function(String method, dynamic arguments)? onInvokeMethod;
  bool Function()? onIsAccessibilityEnabled;
  bool Function()? onIsNotificationListenerEnabled;

  final _methodCalls = <({String method, dynamic arguments})>[];

  List<({String method, dynamic arguments})> get methodCalls => _methodCalls;

  void setInvokeResult(String? result) {
    onInvokeMethod = (_, __) => result;
  }

  void setInvokeResults(List<String?> results) {
    var index = 0;
    onInvokeMethod = (_, __) {
      if (index < results.length) return results[index++];
      return null;
    };
  }

  void setMethodResult(String method, String? result) {
    final previous = onInvokeMethod;
    onInvokeMethod = (m, args) {
      if (m == method) return result;
      return previous?.call(m, args);
    };
  }

  ({String method, dynamic arguments})? findCall(String method) {
    for (final call in _methodCalls) {
      if (call.method == method) return call;
    }
    return null;
  }

  @override
  Future<String?> invokeMethod(String method, [dynamic arguments]) async {
    _methodCalls.add((method: method, arguments: arguments));
    return onInvokeMethod?.call(method, arguments);
  }

  @override
  Future<bool> isAccessibilityEnabled() async {
    return onIsAccessibilityEnabled?.call() ?? true;
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    return onIsNotificationListenerEnabled?.call() ?? true;
  }

  @override
  Future<void> openAccessibilitySettings() async {}
}
