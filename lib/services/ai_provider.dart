import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// خطأ بلغة مفهومة للمستخدم عند فشل الاتصال بمزود الذكاء الاصطناعي.
class AiException implements Exception {
  final String message;

  /// خطأ مؤقت (ضغط أو مهلة أو انقطاع) تفيد إعادة المحاولة فيه.
  final bool retryable;

  /// النموذج نفسه غير متاح، فتفيد تجربة نموذج بديل.
  final bool modelProblem;

  const AiException(this.message, {this.retryable = false, this.modelProblem = false});

  @override
  String toString() => message;
}

abstract class AiProvider {
  /// المعرف المحفوظ في الإعدادات.
  String get id;

  /// الاسم المعروض.
  String get name;

  /// النموذج الافتراضي. يمكن تغييره من الإعدادات لأن المزودين يوقفون نماذج قديمة.
  String get defaultModel;

  /// نماذج بديلة تجرب تلقائيا عند ضغط الخدمة أو عند توقف النموذج الأول.
  List<String> get fallbackModels;

  /// [json] يطلب من المزود رد JSON فقط. [maxTokens] أقصى طول للرد.
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
    bool json = false,
    int maxTokens = 2048,
  });
}

/// المزودات المتاحة. المفتاح يكتبه المستخدم في الإعدادات ويبقى على جهازه فقط.
final List<AiProvider> aiProviders = [GeminiProvider(), GroqProvider()];

AiProvider aiProviderById(String id) =>
    aiProviders.firstWhere((p) => p.id == id, orElse: () => aiProviders.first);

AiException _httpError(int status) {
  if (status == 400) {
    return const AiException(
      'الطلب مرفوض. تحقق من المفتاح ومن اسم النموذج في الإعدادات.',
    );
  }
  if (status == 401 || status == 403) {
    return const AiException('المفتاح غير صالح أو لا يملك صلاحية.');
  }
  if (status == 404) {
    return const AiException(
      'النموذج غير موجود. غيّر اسم النموذج من الإعدادات.',
      modelProblem: true,
    );
  }
  if (status == 429) {
    return const AiException(
      'تجاوزت حد الاستخدام. انتظر قليلا ثم حاول.',
      retryable: true,
    );
  }
  if (status >= 500) {
    return AiException(
      'خدمة المزود غير متاحة حاليا (رمز $status).',
      retryable: true,
    );
  }
  return AiException('فشل الطلب (رمز $status).');
}

Future<http.Response> _post(
  Uri url,
  Map<String, String> headers,
  Map<String, dynamic> body,
  Duration timeout,
) async {
  try {
    return await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(timeout);
  } on TimeoutException {
    throw const AiException('انتهت مهلة الاتصال. حاول مرة أخرى.', retryable: true);
  } on SocketException {
    throw const AiException('لا يوجد اتصال بالإنترنت.', retryable: true);
  } on http.ClientException {
    throw const AiException(
      'تعذر الاتصال بالخدمة. تحقق من الإنترنت.',
      retryable: true,
    );
  }
}

Duration _timeoutFor(bool json) =>
    json ? const Duration(seconds: 150) : const Duration(seconds: 40);

/// يستخرج نص الرد من استجابة Gemini.
String parseGeminiText(String body) {
  final data = jsonDecode(body);
  if (data is Map) {
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      final content = first is Map ? first['content'] : null;
      final parts = content is Map ? content['parts'] : null;
      if (parts is List) {
        final text = parts
            .map((p) => p is Map ? (p['text'] ?? '') : '')
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
    }
  }
  throw const AiException('لم يرجع النموذج نصا. قد يكون المحتوى محجوبا.');
}

/// يستخرج نص الرد من استجابة بصيغة OpenAI (تستخدمها Groq).
String parseChatCompletionText(String body) {
  final data = jsonDecode(body);
  if (data is Map) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
    }
  }
  throw const AiException('لم يرجع النموذج نصا.');
}

class GeminiProvider implements AiProvider {
  @override
  String get id => 'gemini';
  @override
  String get name => 'Gemini';
  @override
  String get defaultModel => 'gemini-3.5-flash-lite';
  @override
  List<String> get fallbackModels => const ['gemini-flash-latest', 'gemini-flash-lite-latest'];

  @override
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
    bool json = false,
    int maxTokens = 2048,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('لا يوجد مفتاح. أضفه من الإعدادات.');
    }
    // المفتاح في الترويسة وليس في الرابط حتى لا يظهر في السجلات.
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final res = await _post(
      url,
      {'Content-Type': 'application/json', 'x-goog-api-key': apiKey.trim()},
      {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': json ? 16000 : maxTokens,
          if (json) 'responseMimeType': 'application/json',
          if (json) 'temperature': 0.9,
        },
      },
      _timeoutFor(json),
    );
    if (res.statusCode != 200) throw _httpError(res.statusCode);
    return parseGeminiText(utf8.decode(res.bodyBytes));
  }
}

class GroqProvider implements AiProvider {
  @override
  String get id => 'groq';
  @override
  String get name => 'Groq';
  @override
  String get defaultModel => 'openai/gpt-oss-120b';
  @override
  List<String> get fallbackModels => const ['llama-3.3-70b-versatile'];

  @override
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
    bool json = false,
    int maxTokens = 2048,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('لا يوجد مفتاح. أضفه من الإعدادات.');
    }
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final res = await _post(
      url,
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      {
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': json ? 8000 : maxTokens,
        if (json) 'response_format': {'type': 'json_object'},
      },
      _timeoutFor(json),
    );
    if (res.statusCode != 200) throw _httpError(res.statusCode);
    return parseChatCompletionText(utf8.decode(res.bodyBytes));
  }
}
