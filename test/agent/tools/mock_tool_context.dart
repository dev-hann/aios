import 'package:aios/domain/agent/tool_context.dart';

class MockToolContext implements ToolContext {
  MockToolContext();

  String? Function(String method, dynamic arguments)? onInvokeMethod;
  bool Function()? onIsAccessibilityEnabled;
  bool Function()? onIsNotificationListenerEnabled;

  final _methodCalls = <({String method, dynamic arguments})>[];

  List<({String method, dynamic arguments})> get methodCalls =>
      _methodCalls;

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

  @override
  Future<String?> invokeMethod(String method, [dynamic arguments]) async {
    _methodCalls.add((method: method, arguments: arguments));
    return onInvokeMethod?.call(method, arguments);
  }

  @override
  Future<bool> isAccessibilityEnabled() async {
    return onIsAccessibilityEnabled?.call() ?? false;
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    return onIsNotificationListenerEnabled?.call() ?? false;
  }
}
