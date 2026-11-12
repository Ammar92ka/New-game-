import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';
import 'package:ottoman_empire_1800/models/round_plan.dart';

RoundPlan _plan() => RoundPlan(
  headline: 'عنوان',
  briefing: 'ملخص',
  chronicle: 'ذاكرة',
  decisions: [
    for (final c in DecisionCategory.values)
      Decision(
        category: c,
        title: 'قرار ${c.id}',
        scene: 'مشهد',
        dilemma: 'معضلة',
        options: [
          for (var i = 0; i < 3; i++)
            DecisionOption(
              text: 'خيار $i',
              result: 'نتيجة $i',
              cost: 1000.0 * i,
              later: const Effects(education: 3),
              delay: 2,
              lineChanges: const [LineChange('civil', 500)],
            ),
        ],
      ),
  ],
);

void main() {
  group('GameState', () {
    test('القيم الابتدائية', () {
      final s = GameState();
      expect(s.treasury, equals(3000000));
      expect(s.debt, equals(6000000));
      expect(s.legitimacy, equals(65));
      expect(s.round, equals(0));
      expect(s.plan, isNull);
      expect(s.history, isEmpty);
      expect(s.hasAllPicks, isFalse);
    });

    test('الحفظ والاستعادة يحفظان كل شيء بما فيه الجولة واختياراتها', () {
      final s = GameState(
        treasury: 1234567,
        debt: 7000000,
        legitimacy: 71,
        stability: 48,
        army: 52,
        foreign: 33,
        education: 21,
        round: 24,
        chronicle: 'ذاكرة العالم',
        lastReport: 'تقرير',
        plan: _plan(),
        picks: [1, null, 2],
        pending: const [
          PendingEffect(
            dueRound: 26,
            effects: Effects(army: 4),
            lines: [LineChange('army', 100000)],
            source: 'مدرسة',
          ),
        ],
        history: const [
          HistoryEntry(round: 23, category: 'اقتصاد', title: 'عنوان', choice: 'خيار'),
        ],
      );
      final back = GameState.fromJson(s.toJson());
      expect(back.treasury, equals(1234567));
      expect(back.debt, equals(7000000));
      expect(back.legitimacy, equals(71));
      expect(back.foreign, equals(33));
      expect(back.round, equals(24));
      expect(back.chronicle, equals('ذاكرة العالم'));
      expect(back.lastReport, equals('تقرير'));
      expect(back.plan, isNotNull);
      expect(back.plan!.decisions[2].options[1].later.education, equals(3));
      expect(back.plan!.decisions[0].options[2].lineChanges.first.line, equals('civil'));
      expect(back.picks[0], equals(1));
      expect(back.picks[1], isNull);
      expect(back.picks[2], equals(2));
      expect(back.pending.length, equals(1));
      expect(back.pending.first.dueRound, equals(26));
      expect(back.pending.first.lines.first.delta, equals(100000));
      expect(back.history.first.title, equals('عنوان'));
    });

    test('حفظ بصيغة قديمة أو مجهولة يرمي خطأ يلتقطه الحفظ', () {
      expect(() => GameState.fromJson(<String, dynamic>{}), throwsA(isA<FormatException>()));
      expect(
        () => GameState.fromJson(<String, dynamic>{'schema': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('القيم الخارجة عن الحدود تُقص عند الاستعادة', () {
      final s = GameState.fromJson(<String, dynamic>{
        'schema': GameState.schema,
        'legitimacy': 500,
        'stability': -20,
        'debt': -50,
        'round': -4,
      });
      expect(s.legitimacy, equals(100));
      expect(s.stability, equals(0));
      expect(s.debt, equals(0));
      expect(s.round, equals(0));
    });

    test('اختيار برقم غير موجود يُهمل', () {
      final json = GameState(plan: _plan(), picks: [0, 1, 2]).toJson();
      json['picks'] = [0, 9, -1];
      final s = GameState.fromJson(json);
      expect(s.picks[0], equals(0));
      expect(s.picks[1], isNull);
      expect(s.picks[2], isNull);
    });

    test('جولة ناقصة القرارات تُهمل', () {
      final json = GameState(plan: _plan()).toJson();
      ((json['plan'] as Map<String, dynamic>)['decisions'] as List).removeLast();
      final s = GameState.fromJson(json);
      expect(s.plan, isNull);
    });

    test('النسخة مستقلة عن الأصل', () {
      final s = GameState();
      final c = s.copy();
      c.history.add(const HistoryEntry(round: 0, category: 'x', title: 'y', choice: 'z'));
      c.treasury = 1;
      c.budget.change('army', 5);
      expect(s.history, isEmpty);
      expect(s.treasury, equals(3000000));
      expect(s.budget.lineValue('army'), equals(8000000));
    });
  });
}
