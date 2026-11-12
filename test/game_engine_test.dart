import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/engine/game_engine.dart';
import 'package:ottoman_empire_1800/engine/round_parser.dart';
import 'package:ottoman_empire_1800/engine/calibrator.dart';
import 'package:ottoman_empire_1800/models/budget.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';
import 'package:ottoman_empire_1800/models/round_plan.dart';

import 'support/fake_ai.dart';

/// جولة بثلاثة قرارات، لكل قرار خيار أول بالخصائص المعطاة وخياران محايدان.
RoundPlan _plan({
  DecisionOption first = const DecisionOption(text: 'أ', result: 'ن'),
  DecisionOption second = const DecisionOption(text: 'أ', result: 'ن'),
  DecisionOption third = const DecisionOption(text: 'أ', result: 'ن'),
}) {
  const neutral = DecisionOption(text: 'محايد', result: 'ن');
  Decision d(DecisionCategory c, DecisionOption o) => Decision(
    category: c,
    title: 'قرار ${c.id}',
    scene: 'مشهد',
    dilemma: 'معضلة',
    options: [o, neutral, neutral],
  );
  return RoundPlan(
    headline: 'ع',
    briefing: 'ملخص',
    decisions: [
      d(DecisionCategory.internal, first),
      d(DecisionCategory.economy, second),
      d(DecisionCategory.foreign, third),
    ],
  );
}

GameState _ready(RoundPlan plan, {GameState? base}) {
  final s = base ?? GameState();
  s.plan = plan;
  s.picks = [0, 0, 0];
  return s;
}

void main() {
  final engine = GameEngine();

  group('التقويم', () {
    test('أنصاف السنوات والتسميات', () {
      expect(GameEngine.totalRounds, equals(222));
      expect(GameEngine.yearOf(0), equals(1800));
      expect(GameEngine.yearOf(1), equals(1800));
      expect(GameEngine.yearOf(2), equals(1801));
      expect(GameEngine.periodLabel(0), equals('كانون الثاني - حزيران 1800'));
      expect(GameEngine.periodLabel(1), equals('تموز - كانون الأول 1800'));
      expect(GameEngine.periodLabel(221), equals('تموز - كانون الأول 1910'));
    });
  });

  group('تنفيذ الجولة', () {
    test('بدون جولة جاهزة أو اختيارات يرمي خطأ', () {
      expect(() => engine.resolveRound(GameState()), throwsStateError);
      final s = GameState()..plan = _plan();
      expect(() => engine.resolveRound(s), throwsStateError);
    });

    test('المصروف والقرض والميزانية ونصف السنة', () {
      final s = _ready(
        _plan(
          first: const DecisionOption(text: 'أ', result: 'ن', cost: 1000000),
          second: const DecisionOption(text: 'أ', result: 'ن', loan: 2000000),
        ),
      );
      final report = engine.resolveRound(s);
      // الدين بعد القرض 8,000,000؛ الجباية بكفاءة 0.9325
      expect(report.revenue, closeTo(8392500, 0.01));
      expect(report.spending, closeTo(8500000, 0.01));
      expect(report.interest, closeTo(480000, 0.01));
      expect(report.oneTimeCosts, equals(1000000));
      expect(report.loans, equals(2000000));
      // 3,000,000 - 1,000,000 + 2,000,000 + (8,392,500 - 8,500,000 - 480,000)
      expect(s.treasury, closeTo(3412500, 0.01));
      expect(s.debt, closeTo(8000000, 0.01));
      expect(s.round, equals(1));
      expect(s.plan, isNull);
      expect(s.hasAllPicks, isFalse);
      expect(s.history.length, equals(3));
      expect(report.period, equals('كانون الثاني - حزيران 1800'));
      expect(s.lastReport, isNotEmpty);
    });

    test('الأثر الفوري يطبق والمؤشرات لا تخرج عن 0 و100', () {
      final s = _ready(
        _plan(
          first: const DecisionOption(
            text: 'أ',
            result: 'ن',
            now: Effects(legitimacy: 8, army: -8),
          ),
        ),
      );
      engine.resolveRound(s);
      expect(s.legitimacy, equals(73));
      expect(s.army, equals(37));
      final low = GameState(army: 3);
      low.plan = _plan(
        first: const DecisionOption(text: 'أ', result: 'ن', now: Effects(army: -8)),
      );
      low.picks = [0, 0, 0];
      engine.resolveRound(low);
      expect(low.army, equals(0));
    });

    test('الأثر المؤجل يظهر بعد المدة لا قبلها', () {
      final s = _ready(
        _plan(
          first: const DecisionOption(
            text: 'مدارس',
            result: 'ن',
            later: Effects(education: 5),
            delay: 2,
            lineChanges: [LineChange('civil', 600000)],
          ),
        ),
      );
      final r1 = engine.resolveRound(s);
      expect(r1.dueNotes, isEmpty);
      expect(s.pending.length, equals(1));
      expect(s.pending.first.dueRound, equals(2));
      expect(s.education, equals(15));
      final civilBefore = s.budget.lineValue('civil');

      s.plan = _plan();
      s.picks = [0, 0, 0];
      final r2 = engine.resolveRound(s);
      expect(r2.dueNotes.length, equals(1));
      expect(s.pending, isEmpty);
      expect(s.education, equals(20));
      // البند زاد 600,000 فوق النمو الاسمي
      expect(s.budget.lineValue('civil'), greaterThan(civilBefore + 590000));
    });

    test('التأخير صفر يطبق الأثر فورا', () {
      final s = _ready(
        _plan(
          first: const DecisionOption(
            text: 'أ',
            result: 'ن',
            later: Effects(foreign: 4),
            delay: 0,
          ),
        ),
      );
      engine.resolveRound(s);
      expect(s.pending, isEmpty);
      expect(s.foreign, equals(49));
    });

    test('نفاد الخزينة يتحول إلى اقتراض طارئ بعمولة وعقوبات', () {
      final s = GameState(treasury: 100000);
      s.plan = _plan();
      s.picks = [0, 0, 0];
      final debtBefore = s.debt;
      final report = engine.resolveRound(s);
      expect(s.treasury, equals(0));
      expect(report.emergencyBorrowed, greaterThan(0));
      expect(s.debt, greaterThan(debtBefore));
      expect(s.army, lessThan(45));
      expect(s.legitimacy, lessThan(65));
    });

    test('إنفاق كبير على الجيش يحتاج مالا فعلا (لا يُعطى مجانا)', () {
      final s = _ready(
        _plan(
          first: const DecisionOption(text: 'أ', result: 'ن', cost: 12000000),
        ),
      );
      final report = engine.resolveRound(s);
      expect(report.emergencyBorrowed, greaterThan(0));
    });

    test('الدين الثقيل يخصم من الاستقرار', () {
      final s = GameState(debt: 60000000, treasury: 50000000);
      s.plan = _plan();
      s.picks = [0, 0, 0];
      engine.resolveRound(s);
      // نسبة الدين فوق 3 مرات: خصم 2 على الأقل
      expect(s.stability, lessThanOrEqualTo(53));
    });
  });

  group('الدين الطارئ والتسديد', () {
    test('تسديد جزء من الدين من الخزينة', () {
      final s = GameState(treasury: 1000, debt: 600);
      expect(engine.repayDebt(s, 400), equals(400));
      expect(s.treasury, equals(600));
      expect(s.debt, equals(200));
    });

    test('لا يسدد أكثر من الدين ولا أكثر من الخزينة', () {
      final a = GameState(treasury: 1000, debt: 600);
      expect(engine.repayDebt(a, 800), equals(600));
      final b = GameState(treasury: 200, debt: 600);
      expect(engine.repayDebt(b, 500), equals(200));
      expect(b.debt, equals(400));
    });

    test('مبلغ صفر أو سالب لا يغير شيئا', () {
      final s = GameState(treasury: 1000, debt: 600);
      expect(engine.repayDebt(s, 0), equals(0));
      expect(engine.repayDebt(s, -50), equals(0));
      expect(s.treasury, equals(1000));
    });
  });

  group('شروط النهاية', () {
    test('حملة جارية بدون نهاية', () {
      expect(engine.evaluate(GameState()), isNull);
    });

    test('الخلع والانهيار والإفلاس والتقاسم', () {
      expect(engine.evaluate(GameState(legitimacy: 15))!.type, equals(EndingType.deposed));
      expect(engine.evaluate(GameState(stability: 12))!.type, equals(EndingType.collapse));
      // الإيراد السنوي 18,000,000 × 6 = 108,000,000
      expect(
        engine.evaluate(GameState(debt: 108000000))!.type,
        equals(EndingType.bankruptcy),
      );
      expect(
        engine.evaluate(GameState(army: 8, foreign: 12))!.type,
        equals(EndingType.conquest),
      );
      expect(engine.evaluate(GameState(army: 8, foreign: 30)), isNull);
      for (final s in [
        GameState(legitimacy: 15),
        GameState(stability: 12),
      ]) {
        expect(engine.evaluate(s)!.isVictory, isFalse);
      }
    });

    test('النجاة بثلاث درجات عند نهاية السنوات', () {
      final n = GameEngine.totalRounds;
      final gold = engine.evaluate(
        GameState(round: n, legitimacy: 80, stability: 75, army: 70, foreign: 70, education: 60, debt: 1000000),
      );
      expect(gold!.isVictory, isTrue);
      expect(gold.title, equals('إمبراطورية مزدهرة'));

      final solid = engine.evaluate(
        GameState(round: n, legitimacy: 55, stability: 55, army: 50, foreign: 50, education: 45, debt: 20000000),
      );
      expect(solid!.title, equals('دولة متماسكة'));

      final barely = engine.evaluate(
        GameState(round: n, legitimacy: 30, stability: 30, army: 30, foreign: 30, education: 30, debt: 60000000),
      );
      expect(barely!.isVictory, isTrue);
      expect(barely.title, equals('نجوت بالكاد'));
    });

    test('الخسارة لها أولوية على النجاة', () {
      final e = engine.evaluate(GameState(round: GameEngine.totalRounds, legitimacy: 10));
      expect(e!.type, equals(EndingType.deposed));
    });
  });

  group('حملة كاملة بذكاء اصطناعي وهمي', () {
    Future<GameState> play(FakeAi ai, int seed, {int maxRounds = 300}) async {
      final rnd = Random(seed);
      final s = GameState();
      for (var i = 0; i < maxRounds; i++) {
        final raw = RoundParser.parse(await ai.call(''));
        s.plan = Calibrator.calibrate(raw, s);
        s.picks = [for (var k = 0; k < 3; k++) rnd.nextInt(3)];
        final report = engine.resolveRound(s);

        expect(s.treasury, greaterThanOrEqualTo(0));
        expect(s.debt, greaterThanOrEqualTo(0));
        for (final v in [s.legitimacy, s.stability, s.army, s.foreign, s.education]) {
          expect(v, inInclusiveRange(0, 100));
        }
        for (final l in [...revenueLines, ...spendingLines]) {
          expect(s.budget.lineValue(l.key), greaterThanOrEqualTo(0));
        }
        if (report.ending != null) break;
      }
      return s;
    }

    test('الأرقام تبقى ضمن حدود المنطق مع ذكاء معقول', () async {
      for (var seed = 1; seed <= 25; seed++) {
        await play(FakeAi(seed: seed), seed);
      }
    });

    test('الأرقام تبقى ضمن حدود المنطق حتى لو بالغ الذكاء الاصطناعي', () async {
      for (var seed = 1; seed <= 25; seed++) {
        await play(FakeAi(seed: seed, wild: true), seed);
      }
    });

    test('الحملة تنتهي بنهاية معروفة وليست لا نهائية', () async {
      final s = await play(FakeAi(seed: 5), 5, maxRounds: 400);
      expect(engine.evaluate(s), isNotNull);
    });
  });
}
