import 'dart:convert';
import 'dart:developer' as developer;

sealed class LoopCheckResult {
  const LoopCheckResult();
}

class LoopOk extends LoopCheckResult {
  const LoopOk();
}

class LoopWarning extends LoopCheckResult {
  final int count;
  final String toolName;
  const LoopWarning(this.count, this.toolName);
}

class LoopForceBreak extends LoopCheckResult {
  const LoopForceBreak();
}

class LoopDetector {
  static const _tag = 'AIOS-LoopDetector';

  final _loopOverrides = <String, Set<String>>{
    'screen_action': {'scroll', 'swipe', 'global'},
  };

  final List<({String tool, String argsCanonical})> _actionHistory = [];
  final List<String> _observationHistory = [];
  bool _warningGiven = false;

  void reset() {
    _actionHistory.clear();
    _observationHistory.clear();
    _warningGiven = false;
  }

  LoopCheckResult record(
    String toolName,
    String args,
    String observation,
  ) {
    final canonical = _canonicalizeArgs(args);
    _actionHistory.add((tool: toolName, argsCanonical: canonical));
    _observationHistory.add(observation);

    final recentActions = _actionHistory.length >= 3
        ? _actionHistory.sublist(_actionHistory.length - 3)
        : _actionHistory.toList();

    final consecutiveDuplicates = recentActions
        .where((a) =>
            a.tool == toolName && a.argsCanonical == canonical)
        .length;

    final isRepeatedAction = consecutiveDuplicates >= 3 &&
        !_isActionAllowedRepeated(toolName, canonical);

    final consecutiveIdenticalObs = _observationHistory.length >= 2 &&
        _observationHistory
                .sublist(_observationHistory.length - 2)
                .toSet()
                .length <
            2;

    if (isRepeatedAction || consecutiveIdenticalObs) {
      if (_warningGiven) {
        return const LoopForceBreak();
      }
      _warningGiven = true;
      return LoopWarning(consecutiveDuplicates, toolName);
    }

    return const LoopOk();
  }

  bool shouldNudge(int iteration, bool hasAnswer) {
    return iteration >= 3 && !hasAnswer && !_warningGiven;
  }

  String _canonicalizeArgs(String args) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is! Map<String, dynamic>) return args;
      final keys = decoded.keys.toList()..sort();
      return keys.map((k) => '$k=${decoded[k]}').join(',');
    } on Object catch (e) {
      developer.log(
        'canonicalizeArgs error: $e',
        name: _tag,
        level: 900,
      );
      return args;
    }
  }

  bool _isActionAllowedRepeated(String tool, String argsCanonical) {
    final overrides = _loopOverrides[tool];
    if (overrides == null) return false;
    return overrides.any((o) => argsCanonical.contains(o));
  }
}
