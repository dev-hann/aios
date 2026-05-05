import 'dart:convert';

import 'package:aios/domain/agent/extended_tool.dart';
import 'package:aios/domain/agent/tool_context.dart';

class ContactSearchTool implements ExtendedTool {
  @override
  String get name => 'contact_search';

  @override
  String get description =>
      'Search contacts by name/phone. Args: {query, limit}';

  @override
  String get parameters =>
      '{"query": "string", "limit": "integer (default 10)"}';

  @override
  Future<String> execute(String args, ToolContext toolContext) async {
    try {
      final json = _tryParseJson(args);
      final query = json['query']?.toString().trim() ?? '';
      if (query.isEmpty) return "Error: 'query' parameter required";
      final limit = json['limit'] as int? ?? 10;
      return await toolContext.invokeMethod(
            'searchContacts',
            {'query': query, 'limit': limit},
          ) ??
          'No contacts found';
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  Map<String, dynamic> _tryParseJson(String args) {
    try {
      return json.decode(args) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }
}
