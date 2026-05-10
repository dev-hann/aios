import 'dart:convert';

enum LlmProviderType { zai, zaiCoding, openai, anthropic, custom }

class LlmProviderConfig {
  const LlmProviderConfig({
    required this.type,
    required this.apiKey,
    required this.model,
    this.baseUrl,
  });

  factory LlmProviderConfig.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return LlmProviderConfig(
      type: LlmProviderType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => LlmProviderType.zai,
      ),
      apiKey: map['apiKey'] as String? ?? '',
      model: map['model'] as String? ?? '',
      baseUrl: map['baseUrl'] as String?,
    );
  }

  final LlmProviderType type;
  final String apiKey;
  final String model;
  final String? baseUrl;

  String get effectiveBaseUrl => switch (type) {
    LlmProviderType.zai => 'https://api.z.ai/api/paas/v4',
    LlmProviderType.zaiCoding => 'https://api.z.ai/api/coding/paas/v4',
    LlmProviderType.openai => 'https://api.openai.com/v1',
    LlmProviderType.anthropic => 'https://api.anthropic.com/v1',
    LlmProviderType.custom => baseUrl ?? '',
  };

  String get chatEndpoint => '$effectiveBaseUrl/chat/completions';
  String get modelsEndpoint => '$effectiveBaseUrl/models';

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  String toJson() => jsonEncode({
    'type': type.name,
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  });

  LlmProviderConfig copyWith({
    LlmProviderType? type,
    String? apiKey,
    String? model,
    String? baseUrl,
  }) {
    return LlmProviderConfig(
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}

class LlmModelInfo {
  const LlmModelInfo({
    required this.id,
    required this.displayName,
    this.capabilities = const {},
    this.maxContextTokens = 128000,
    this.maxOutputTokens = 4096,
  });

  factory LlmModelInfo.fromApi(String id) {
    return LlmModelInfo(
      id: id,
      displayName: _formatDisplayName(id),
      capabilities: _inferCapabilities(id),
    );
  }

  final String id;
  final String displayName;
  final Set<ModelCapability> capabilities;
  final int maxContextTokens;
  final int maxOutputTokens;

  static String _formatDisplayName(String id) {
    return id
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static Set<ModelCapability> _inferCapabilities(String id) {
    final caps = <ModelCapability>{ModelCapability.toolCalling};
    if (id.contains('v') || id.contains('vision')) {
      caps.add(ModelCapability.vision);
    }
    if (id.contains('5') || id.contains('4.7') || id.contains('4.6')) {
      caps.add(ModelCapability.thinking);
    }
    return caps;
  }
}

enum ModelCapability { toolCalling, vision, thinking }
