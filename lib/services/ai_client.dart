import 'ai_provider.dart';
import 'settings_service.dart';

/// يرسل الطلب للمزود المختار، ويجرب نماذج بديلة تلقائيا عند الضغط أو توقف النموذج.
class AiClient {
  final AiProvider provider;
  final String apiKey;
  final List<String> models;

  AiClient({required this.provider, required this.apiKey, required this.models})
    : assert(models.isNotEmpty);

  factory AiClient.fromSettings(AiSettings s) {
    final provider = aiProviderById(s.provider);
    final models = <String>[s.effectiveModel];
    for (final m in [provider.defaultModel, ...provider.fallbackModels]) {
      if (!models.contains(m)) models.add(m);
    }
    return AiClient(provider: provider, apiKey: s.apiKey, models: models);
  }

  /// يطلب جولة بصيغة JSON.
  Future<String> generateJson(String prompt) => _run(prompt, json: true);

  /// طلب نصي قصير (لاختبار الاتصال من الإعدادات) بنفس منطق النماذج البديلة.
  Future<String> generateText(String prompt) => _run(prompt, json: false);

  Future<String> _run(String prompt, {required bool json}) async {
    AiException? last;
    for (final model in models) {
      try {
        return await provider.generate(
          prompt: prompt,
          apiKey: apiKey,
          model: model,
          json: json,
        );
      } on AiException catch (e) {
        last = e;
        // الأخطاء غير المؤقتة (مفتاح خاطئ مثلا) لا تفيد معها النماذج البديلة
        if (!e.retryable && !e.modelProblem) rethrow;
      }
    }
    throw last ?? const AiException('تعذر الاتصال بالذكاء الاصطناعي.');
  }
}
