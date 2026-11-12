import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/engine/round_parser.dart';
import 'package:ottoman_empire_1800/models/round_plan.dart';

import 'support/fake_ai.dart';

Future<Map<String, dynamic>> _validJson() async =>
    jsonDecode(await FakeAi().call('')) as Map<String, dynamic>;

void main() {
  group('قراءة رد الذكاء الاصطناعي', () {
    test('يقرأ جولة صالحة بترتيب الفئات الثابت', () async {
      final json = await _validJson();
      // نقلب الترتيب ليتأكد أن المحلل يعيد ترتيبها
      json['decisions'] = (json['decisions'] as List).reversed.toList();
      final plan = RoundParser.parse(jsonEncode(json));
      expect(plan.decisions.length, equals(3));
      expect(plan.decisions[0].category, equals(DecisionCategory.internal));
      expect(plan.decisions[1].category, equals(DecisionCategory.economy));
      expect(plan.decisions[2].category, equals(DecisionCategory.foreign));
      expect(plan.decisions.first.options.length, equals(3));
    });

    test('يتجاوز أسوار الكود والنص حول JSON', () async {
      final text = '```json\n${jsonEncode(await _validJson())}\n```';
      expect(RoundParser.parse(text).decisions.length, equals(3));
      final noisy = 'تفضل: ${jsonEncode(await _validJson())} انتهى';
      expect(RoundParser.parse(noisy).decisions.length, equals(3));
    });

    test('يقبل الأرقام المكتوبة كنص بما فيها الهندية والفواصل', () {
      expect(RoundParser.toNum('2,500,000'), equals(2500000));
      expect(RoundParser.toNum('٣٠٠٠'), equals(3000));
      expect(RoundParser.toNum('+5'), equals(5));
      expect(RoundParser.toNum('abc'), isNull);
      expect(RoundParser.toNum(null), isNull);
    });

    test('ينقل الأرقام النصية إلى الخيارات', () async {
      final json = await _validJson();
      final first = ((json['decisions'] as List).first as Map)['options'] as List;
      (first.first as Map)['cost'] = '1,200,000';
      final plan = RoundParser.parse(jsonEncode(json));
      final option = plan.decisions
          .firstWhere((d) => d.category == DecisionCategory.internal)
          .options
          .first;
      expect(option.cost, equals(1200000));
    });

    test('نص ليس JSON يرمي خطأ مفهوما', () {
      expect(() => RoundParser.parse('لا يوجد شيء'), throwsA(isA<PlanFormatException>()));
      expect(() => RoundParser.parse('{ غير صالح }'), throwsA(isA<PlanFormatException>()));
    });

    test('فئة ناقصة ترمي خطأ يذكر الفئة', () async {
      final json = await _validJson();
      (json['decisions'] as List).removeLast();
      expect(
        () => RoundParser.parse(jsonEncode(json)),
        throwsA(isA<PlanFormatException>()),
      );
    });

    test('أقل من ثلاثة خيارات يرمي خطأ', () async {
      final json = await _validJson();
      (((json['decisions'] as List).first as Map)['options'] as List).removeLast();
      expect(
        () => RoundParser.parse(jsonEncode(json)),
        throwsA(isA<PlanFormatException>()),
      );
    });

    test('أكثر من ثلاثة خيارات تؤخذ الثلاثة الأولى', () async {
      final json = await _validJson();
      final opts = ((json['decisions'] as List).first as Map)['options'] as List;
      opts.add(Map<String, dynamic>.from(opts.first as Map));
      final plan = RoundParser.parse(jsonEncode(json));
      expect(plan.decisions.first.options.length, equals(3));
    });

    test('خيار بلا نص أو نتيجة يرمي خطأ', () async {
      final json = await _validJson();
      final opts = ((json['decisions'] as List).first as Map)['options'] as List;
      (opts.first as Map)['text'] = '';
      expect(
        () => RoundParser.parse(jsonEncode(json)),
        throwsA(isA<PlanFormatException>()),
      );
    });
  });
}
