import 'dart:convert';

Map<String, dynamic> tryParseToolJson(String args, String tag) {
  try {
    final decoded = json.decode(args);
    if (decoded is Map<String, dynamic>) return decoded;
    print('[$tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
    return {};
  } on Object catch (e) {
    print('[$tag] WARN: JSON parse error: $e');
    return {};
  }
}

int? parseIntDynamic(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
