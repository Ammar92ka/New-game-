import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/engine/calibrator.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';
import 'package:ottoman_empire_1800/models/round_plan.dart';

const double revenue = 18000000;

DecisionOption _opt({
  double cost = 0,
  double loan = 0,
  Effects now = const Effects(),
  Effects later = const Effects(),
  int delay = 0,
  List<LineChange> lines = const [],
}) => DecisionOption(
  text: 'خيار',
  result: 'نتيجة',
  cost: cost,
  loan: loan,
  now: now,
  later: later,
  delay: delay,
  lineChanges: lines,
);

void main() {
  group('معايرة الخيار', () {
    test('الأرقام المعقولة تبقى كما هي بلا علامة معايرة', () {
      final o = Calibrator.calibrateOption(
        _opt(
          cost: 2000000,
          loan: 3000000,
          now: const Effects(stability: 3, army: -2),
          later: const Effects(education: 5),
          delay: 4,
          lines: const [LineChange('civil', 400000)],
        ),
        revenue,
      );
      expect(o.cost, equals(2000000));
      expect(o.loan, equals(3000000));
      expect(o.now.stability, equals(3));
      expect(o.delay, equals(4));
      expect(o.calibrated, isFalse);
    });

    test('المصروف والقرض يقصان إلى نسبة من الإيراد السنوي', () {
      final o = Calibrator.calibrateOption(
        _opt(cost: 50000000, loan: 90000000),
        revenue,
      );
      expect(o.cost, closeTo(revenue * Calibrator.maxCostShare, 1));
      expect(o.loan, closeTo(revenue * Calibrator.maxLoanShare, 1));
      expect(o.calibrated, isTrue);
    });

    test('القيم السالبة للمصروف تصير صفرا', () {
      final o = Calibrator.calibrateOption(_opt(cost: -500000), revenue);
      expect(o.cost, equals(0));
    });

    test('الأثر الفوري والمؤجل يقصان إلى حدودهما', () {
      final o = Calibrator.calibrateOption(
        _opt(
          now: const Effects(legitimacy: -30),
          later: const Effects(stability: -40),
        ),
        revenue,
      );
      expect(o.now.legitimacy, equals(-Calibrator.maxNow));
      expect(o.later.stability, equals(-Calibrator.maxLater));
      expect(o.calibrated, isTrue);
    });

    test('المكاسب الموجبة لها سقف حتى لا يوجد خيار بلا ثمن', () {
      final o = Calibrator.calibrateOption(
        _opt(
          now: const Effects(legitimacy: 8, stability: 8, army: 8),
          later: const Effects(foreign: 12, education: 12),
        ),
        revenue,
      );
      final gain = [
        o.now.legitimacy, o.now.stability, o.now.army,
        o.later.foreign, o.later.education,
      ].fold(0, (a, b) => a + b);
      expect(gain, lessThanOrEqualTo(Calibrator.maxTotalGain));
      expect(o.calibrated, isTrue);
    });

    test('بنود الميزانية المجهولة تُحذف والمكررة تُدمج', () {
      final o = Calibrator.calibrateOption(
        _opt(
          lines: const [
            LineChange('nonsense', 100000),
            LineChange('army', 300000),
            LineChange('army', 200000),
          ],
        ),
        revenue,
      );
      expect(o.lineChanges.length, equals(1));
      expect(o.lineChanges.first.line, equals('army'));
      expect(o.lineChanges.first.delta, closeTo(500000, 1));
      expect(o.calibrated, isTrue);
    });

    test('تغيير البند السنوي له سقف نسبي', () {
      final o = Calibrator.calibrateOption(
        _opt(lines: const [LineChange('army', 99000000)]),
        revenue,
      );
      expect(o.lineChanges.first.delta, closeTo(revenue * Calibrator.maxLineShare, 1));
    });

    test('زيادة الإيراد لا تأتي فورا', () {
      final o = Calibrator.calibrateOption(
        _opt(delay: 0, lines: const [LineChange('customs', 500000)]),
        revenue,
      );
      expect(o.delay, greaterThanOrEqualTo(1));
      expect(o.calibrated, isTrue);
    });

    test('مدة التأخير لها سقف', () {
      final o = Calibrator.calibrateOption(_opt(delay: 99), revenue);
      expect(o.delay, equals(Calibrator.maxDelay));
    });

    test('عدد تغييرات الميزانية لا يزيد على الحد', () {
      final o = Calibrator.calibrateOption(
        _opt(
          lines: const [
            LineChange('army', 100000),
            LineChange('palace', 100000),
            LineChange('admin', 100000),
            LineChange('civil', 100000),
            LineChange('land', 100000),
          ],
        ),
        revenue,
      );
      expect(o.lineChanges.length, equals(Calibrator.maxLineChanges));
    });
  });

  group('معايرة النصوص', () {
    test('النص الطويل يقص بعلامة اقتطاع', () {
      final long = 'ك' * 5000;
      final plan = Calibrator.calibrate(
        RoundPlan(
          headline: long,
          briefing: long,
          chronicle: long,
          decisions: [
            for (final c in DecisionCategory.values)
              Decision(
                category: c,
                title: 'عنوان',
                scene: long,
                dilemma: long,
                options: [for (var i = 0; i < 3; i++) _opt()],
              ),
          ],
        ),
        GameState(),
      );
      expect(plan.briefing.length, lessThanOrEqualTo(Calibrator.maxBriefing));
      expect(plan.chronicle.length, lessThanOrEqualTo(Calibrator.maxChronicle));
      expect(plan.decisions.first.scene.length, lessThanOrEqualTo(Calibrator.maxScene));
    });
  });
}
