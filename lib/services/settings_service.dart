import 'package:shared_preferences/shared_preferences.dart';

import 'ai_provider.dart';

/// إعدادات الذكاء الاصطناعي. المفتاح يخزن على الجهاز فقط (وليس في الكود).
class AiSettings {
  final String provider;
  final String apiKey;

  /// فارغ يعني استخدام النموذج الافتراضي للمزود.
  final String model;

  const AiSettings({
    this.provider = 'gemini',
    this.apiKey = '',
    this.model = '',
  });

  bool get hasKey => apiKey.trim().isNotEmpty;

  String get effectiveModel => model.trim().isNotEmpty
      ? model.trim()
      : aiProviderById(provider).defaultModel;

  AiSettings copyWith({String? provider, String? apiKey, String? model}) =>
      AiSettings(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );
}

class SettingsService {
  static const String _provider = 'ai_provider';
  static const String _apiKey = 'ai_api_key';
  static const String _model = 'ai_model';

  Future<AiSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AiSettings(
      provider: p.getString(_provider) ?? 'gemini',
      apiKey: p.getString(_apiKey) ?? '',
      model: p.getString(_model) ?? '',
    );
  }

  Future<void> save(AiSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_provider, s.provider);
    await p.setString(_apiKey, s.apiKey.trim());
    await p.setString(_model, s.model.trim());
  }
}
