import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum AiProvider { openAi, gemini, anthropic }

extension AiProviderLabel on AiProvider {
  String get label => switch (this) {
    AiProvider.openAi => 'OpenAI',
    AiProvider.gemini => 'Gemini',
    AiProvider.anthropic => 'Anthropic',
  };
}

/// API keys are kept in platform secure storage and never written to Hive,
/// source files, logs, analytics, or a Grasp server.
class AiSecretStore {
  const AiSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(AiProvider provider) => 'grasp_byok_${provider.name}_v1';

  Future<bool> hasKey(AiProvider provider) async {
    final value = await _storage.read(key: _key(provider));
    return value?.trim().isNotEmpty == true;
  }

  Future<String?> read(AiProvider provider) =>
      _storage.read(key: _key(provider));

  Future<void> save(AiProvider provider, String apiKey) async {
    final value = apiKey.trim();
    if (value.isEmpty) {
      await delete(provider);
      return;
    }
    await _storage.write(key: _key(provider), value: value);
  }

  Future<void> delete(AiProvider provider) =>
      _storage.delete(key: _key(provider));
}

abstract class LocalAiEngine {
  Future<bool> get isAvailable;
  Future<String> generate(String prompt);
}

/// Optional enhancement boundary. Core review and scheduling never depend on
/// this interface, and callers must always provide a non-AI fallback.
abstract class AiEnhancementClient {
  Future<String> generate({required String prompt, required String model});
}

/// Direct OpenAI BYOK adapter using the Responses API. `store: false` avoids
/// creating server-side response state for these one-shot vocabulary helpers.
class OpenAiByokClient implements AiEnhancementClient {
  OpenAiByokClient({required AiSecretStore secrets, http.Client? httpClient})
    : _secrets = secrets,
      _http = httpClient ?? http.Client();

  final AiSecretStore _secrets;
  final http.Client _http;

  @override
  Future<String> generate({
    required String prompt,
    required String model,
  }) async {
    final apiKey = await _secrets.read(AiProvider.openAi);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('尚未設定 OpenAI API Key。');
    }
    final response = await _http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'input': prompt,
            'store': false,
            'max_output_tokens': 400,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('OpenAI request failed (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final output = json['output'];
    if (output is List) {
      for (final item in output.whereType<Map>()) {
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content.whereType<Map>()) {
          if (part['type'] == 'output_text') {
            final text = part['text']?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      }
    }
    throw const FormatException('OpenAI response did not contain output text.');
  }
}
