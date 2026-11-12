import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/services/ai_client.dart';
import 'package:ottoman_empire_1800/services/ai_provider.dart';
import 'package:ottoman_empire_1800/services/settings_service.dart';

class _Fake implements AiProvider {
  _Fake(this.behavior);
  final Future<String> Function(String model) behavior;
  final List<String> triedModels = [];

  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get defaultModel => 'm1';
  @override
  List<String> get fallbackModels => const ['m2'];

  @override
  Future<String> generate({
    required String prompt,
    required String apiKey,
    required String model,
    bool json = false,
    int maxTokens = 2048,
  }) {
    triedModels.add(model);
    return behavior(model);
  }
}

void main() {
  group('قراءة ردود المزودات', () {
    test('Gemini: يجمع نص الأجزاء', () {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'مرحبا '},
                {'text': 'بالعالم'},
              ],
            },
          },
        ],
      });
      expect(parseGeminiText(body), equals('مرحبا بالعالم'));
    });

    test('Gemini: رد فارغ يرمي خطأ مفهوما', () {
      expect(
        () => parseGeminiText(jsonEncode({'candidates': []})),
        throwsA(isA<AiException>()),
      );
    });

    test('Groq: يقرأ رسالة الرد', () {
      final body = jsonEncode({
        'choices': [
          {
            'message': {'content': '  نص الرد  '},
          },
        ],
      });
      expect(parseChatCompletionText(body), equals('نص الرد'));
    });

    test('Groq: رد بلا محتوى يرمي خطأ مفهوما', () {
      expect(
        () => parseChatCompletionText(jsonEncode({'choices': []})),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('المزودات والإعدادات', () {
    test('اختيار مزود غير معروف يرجع للمزود الأول', () {
      expect(aiProviderById('unknown').id, equals(aiProviders.first.id));
    });

    test('لكل مزود نموذج افتراضي وبدائل', () {
      for (final p in aiProviders) {
        expect(p.defaultModel.trim(), isNotEmpty);
        expect(p.fallbackModels, isNotEmpty);
      }
    });

    test('قائمة النماذج تبدأ بنموذج المستخدم ثم الافتراضي ثم البدائل بلا تكرار', () {
      final client = AiClient.fromSettings(
        const AiSettings(provider: 'gemini', apiKey: 'k', model: 'my-model'),
      );
      expect(client.models.first, equals('my-model'));
      expect(client.models.toSet().length, equals(client.models.length));
      expect(client.models.length, greaterThanOrEqualTo(3));
      final plain = AiClient.fromSettings(const AiSettings(apiKey: 'k'));
      expect(plain.models.first, equals(aiProviderById('gemini').defaultModel));
    });
  });

  group('AiClient', () {
    test('يجرب النموذج البديل عند ضغط الخدمة', () async {
      final fake = _Fake((m) async {
        if (m == 'm1') throw const AiException('503', retryable: true);
        return 'تم';
      });
      final client = AiClient(provider: fake, apiKey: 'k', models: ['m1', 'm2']);
      expect(await client.generateJson('x'), equals('تم'));
      expect(fake.triedModels, equals(['m1', 'm2']));
    });

    test('يجرب النموذج البديل عند 404 للنموذج', () async {
      final fake = _Fake((m) async {
        if (m == 'm1') throw const AiException('404', modelProblem: true);
        return 'تم';
      });
      final client = AiClient(provider: fake, apiKey: 'k', models: ['m1', 'm2']);
      expect(await client.generateJson('x'), equals('تم'));
    });

    test('الخطأ غير المؤقت لا يجرب بدائل', () async {
      final fake = _Fake((m) async => throw const AiException('مفتاح خاطئ'));
      final client = AiClient(provider: fake, apiKey: 'k', models: ['m1', 'm2']);
      await expectLater(client.generateJson('x'), throwsA(isA<AiException>()));
      expect(fake.triedModels, equals(['m1']));
    });

    test('إذا فشلت كل النماذج يرمى آخر خطأ', () async {
      final fake = _Fake((m) async => throw AiException('فشل $m', retryable: true));
      final client = AiClient(provider: fake, apiKey: 'k', models: ['m1', 'm2']);
      await expectLater(client.generateJson('x'), throwsA(isA<AiException>()));
      expect(fake.triedModels.length, equals(2));
    });
  });
}
