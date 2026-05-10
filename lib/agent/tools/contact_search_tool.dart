import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';
import 'package:aios/domain/agent/tool_result.dart';

class ContactSearchTool extends ExtendedTool {
  static const _tag = 'AIOS-ContactSearch';

  @override
  String get name => 'contact_search';

  @override
  String get description =>
      'Search contacts by name/phone. Args: {query, limit}';

  @override
  String get parameters =>
      '{"query": "string", "limit": "integer (default 10)"}';

  @override
  String get toolPrompt =>
      'Search contacts by name, phone number, or email.\n\n'
      'Parameters: $parameters\n\n'
      'Rules:\n'
      '- "query" is required (name, phone number, or email)\n'
      '- Use "limit" to control max results (default 10)\n'
      '- Supports partial match (e.g. "Kim" finds "Kim Minsoo")\n'
      '- Respond with user language';

  @override
  Future<ToolResult> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final query = json['query']?.toString().trim() ?? '';
      if (query.isEmpty) return const ToolResult.err("'query' required");
      final limit = _parseInt(json['limit']) ?? 10;
      final result = await toolContext.invokeMethod('searchContacts', {
        'query': query,
        'limit': limit,
      });
      if (result == null) return const ToolResult.ok('No contacts found');
      return ToolResult.ok(result);
    } on Object catch (e) {
      return ToolResult.err('$e');
    }
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      final decoded = json.decode(args);
      if (decoded is Map<String, dynamic>) return decoded;
      print('[$_tag] WARN: Invalid JSON type: ${decoded.runtimeType}');
      return {};
    } on Object catch (e) {
      print('[$_tag] WARN: JSON parse error: $e');
      return {};
    }
  }
}
