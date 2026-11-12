import '../models/game_state.dart';
import '../models/round_plan.dart';
import '../services/economy.dart';

enum EndingType { deposed, collapse, bankruptcy, conquest, survived }

class Ending {
  final EndingType type;
  final String title;
  final String description;
  const Ending(this.type, this.title, this.description);

  bool get isVictory => type == EndingType.survived;
}

/// تقرير نصف السنة بعد تنفيذ قرارات الجولة.
class HalfYearReport {
  final int round;
  final String period;
  final double revenue;
  final double spending;
  final double interest;
  final double oneTimeCosts;
  final double loans;
  final double emergencyBorrowed;
  final List<String> dueNotes;
  final Map<String, int> indicatorChanges;
  final double treasuryAfter;
  final double debtAfter;
  final Ending? ending;

  const HalfYearReport({
    required this.round,
    required this.period,
    required this.revenue,
    required this.spending,
    required this.interest,
    required this.oneTimeCosts,
    required this.loans,
    required this.emergencyBorrowed,
    required this.dueNotes,
    required this.indicatorChanges,
    required this.treasuryAfter,
    required this.debtAfter,
    this.ending,
  });

  double get net => revenue - spending - interest;

  /// ملخص نصي يرسل للذكاء الاصطناعي في الجولة التالية.
  String toPromptText() {
    String n(double v) => v.round().toString();
    final changes = indicatorChanges.entries
        .where((e) => e.value != 0)
        .map((e) => '${e.key} ${e.value > 0 ? '+' : ''}${e.value}')
        .join('، ');
    final buf = StringBuffer()
      ..write('تقرير $period: إيراد ${n(revenue)}، نفقات ${n(spending)}، فوائد ${n(interest)}')
      ..write('، صافي ${n(net)}، مصروفات قرارات ${n(oneTimeCosts)}');
    if (loans > 0) buf.write('، قروض ${n(loans)}');
    if (emergencyBorrowed > 0) buf.write('، اقتراض طارئ ${n(emergencyBorrowed)}');
    if (changes.isNotEmpty) buf.write('. تغير المؤشرات: $changes');
    if (dueNotes.isNotEmpty) buf.write('. آثار ظهرت الآن: ${dueNotes.join('؛ ')}');
    return buf.toString();
  }
}

/// محرك اللعبة. لا يعرف شيئا عن الواجهة ولا عن الذكاء الاصطناعي:
/// يستقبل جولة جاهزة واختيارات اللاعب ويحسب النتائج بقواعد ثابتة.
class GameEngine {
  static const int startYear = 1800;
  static const int endYear = 1910;

  /// عدد أنصاف السنوات في الحملة (1800 إلى 1910 شاملة).
  static int get totalRounds => (endYear - startYear + 1) * 2;

  static int yearOf(int round) => startYear + round ~/ 2;

  static String halfLabel(int round) =>
      round % 2 == 0 ? 'كانون الثاني - حزيران' : 'تموز - كانون الأول';

  /// مثال: "تموز - كانون الأول 1812".
  static String periodLabel(int round) => '${halfLabel(round)} ${yearOf(round)}';

  static const int _legitimacyLossAt = 15;
  static const int _stabilityLossAt = 12;

  /// شروط النهاية. الخسارة لها الأولوية، والنجاة عند انتهاء السنوات.
  Ending? evaluate(GameState s) {
    if (s.legitimacy <= _legitimacyLossAt) {
      return const Ending(
        EndingType.deposed,
        'خُلعت عن العرش',
        'فقدت ثقة العلماء والجند وكبار رجال الدولة، فاجتمعوا على خلعك وأعلنوا سلطانا جديدا.',
      );
    }
    if (s.stability <= _stabilityLossAt) {
      return const Ending(
        EndingType.collapse,
        'انهيار النظام',
        'عمّت الفوضى والثورات الولايات والعاصمة، وانفرط عقد الدولة قبل أن تستعيد زمامها.',
      );
    }
    if (EconomyRules.debtRatio(s.debt, s.budget) >= EconomyRules.bankruptcyRatio) {
      return const Ending(
        EndingType.bankruptcy,
        'إفلاس الدولة',
        'عجزت الخزينة عن خدمة الديون، فتدخل الدائنون الأجانب في مالية الدولة وصارت قراراتها رهينة لهم.',
      );
    }
    if (s.army <= 8 && s.foreign <= 12) {
      return const Ending(
        EndingType.conquest,
        'تقاسم الدول الكبرى للأراضي',
        'ضعف الجيش وغابت المكانة الدولية، فاقتطعت القوى الكبرى الولايات واحدة بعد أخرى.',
      );
    }
    if (s.round >= totalRounds) {
      final avg = (s.legitimacy + s.stability + s.army + s.foreign + s.education) / 5;
      final ratio = EconomyRules.debtRatio(s.debt, s.budget);
      if (avg >= 70 && ratio < 1.5) {
        return Ending(
          EndingType.survived,
          'إمبراطورية مزدهرة',
          'بلغت عام $endYear والدولة قوية ومحدثة، وصارت لها كلمة بين الكبار.',
        );
      }
      if (avg >= 50 && ratio < 3) {
        return Ending(
          EndingType.survived,
          'دولة متماسكة',
          'بلغت عام $endYear والدولة ما زالت متماسكة رغم الأزمات، وأمامها طريق إصلاح طويل.',
        );
      }
      return Ending(
        EndingType.survived,
        'نجوت بالكاد',
        'بلغت عام $endYear والدولة مثقلة بالديون والضعف، لكنها ما زالت قائمة.',
      );
    }
    return null;
  }

  int _ind(int v) => v.clamp(0, 100).toInt();

  void _applyEffects(GameState s, Effects e) {
    s.legitimacy = _ind(s.legitimacy + e.legitimacy);
    s.stability = _ind(s.stability + e.stability);
    s.army = _ind(s.army + e.army);
    s.foreign = _ind(s.foreign + e.foreign);
    s.education = _ind(s.education + e.education);
  }

  Map<String, int> _snapshot(GameState s) => {
    'الشرعية': s.legitimacy,
    'الاستقرار': s.stability,
    'الجيش': s.army,
    'المكانة الدولية': s.foreign,
    'التعليم': s.education,
  };

  /// يسدد من الدين من الخزينة. يعيد المبلغ المسدد فعلا.
  double repayDebt(GameState s, double amount) {
    if (amount <= 0) return 0;
    final paid = [amount, s.debt, s.treasury].reduce((a, b) => a < b ? a : b);
    s.treasury -= paid;
    s.debt -= paid;
    return paid;
  }

  /// ينفذ قرارات الجولة الحالية ويدخل نصف السنة التالي.
  /// يشترط أن تكون الجولة جاهزة وأن يكون اللاعب قد اختار في القرارات الثلاثة.
  HalfYearReport resolveRound(GameState s) {
    final plan = s.plan;
    if (plan == null || !s.hasAllPicks) {
      throw StateError('الجولة غير جاهزة للتنفيذ');
    }
    final before = _snapshot(s);
    final finishedRound = s.round;
    var costs = 0.0;
    var loans = 0.0;

    // 1) قرارات اللاعب
    for (var i = 0; i < 3; i++) {
      final decision = plan.decisions[i];
      final option = decision.options[s.picks[i]!];
      costs += option.cost;
      loans += option.loan;
      s.treasury -= option.cost;
      s.treasury += option.loan;
      s.debt += option.loan;
      _applyEffects(s, option.now);
      if (!option.later.isZero || option.lineChanges.isNotEmpty) {
        if (option.delay <= 0) {
          _applyEffects(s, option.later);
          for (final c in option.lineChanges) {
            s.budget.change(c.line, c.delta);
          }
        } else {
          s.pending.add(
            PendingEffect(
              dueRound: finishedRound + option.delay,
              effects: option.later,
              lines: option.lineChanges,
              source: '${decision.title}: ${_short(option.text)}',
            ),
          );
        }
      }
      s.history.add(
        HistoryEntry(
          round: finishedRound,
          category: decision.category.label,
          title: decision.title,
          choice: option.text,
          result: option.result,
        ),
      );
    }

    // 2) ميزانية نصف السنة
    final revenue = EconomyRules.halfYearRevenue(s.budget, s.stability);
    final spending = EconomyRules.halfYearSpending(s.budget);
    final interest = EconomyRules.halfYearInterest(s.debt);
    s.treasury += revenue - spending - interest;

    // 3) اقتراض طارئ عند نفاد الخزينة (رواتب متأخرة تضر بالجيش والاستقرار)
    var emergency = 0.0;
    if (s.treasury < 0) {
      emergency = -s.treasury * (1 + EconomyRules.emergencyLoanFee);
      s.debt += emergency;
      s.treasury = 0;
      s.legitimacy = _ind(s.legitimacy - 1);
      s.stability = _ind(s.stability - 1);
      s.army = _ind(s.army - 2);
    }

    // 4) انجراف المؤشرات بحسب الدين والإنفاق
    final ratio = EconomyRules.debtRatio(s.debt, s.budget);
    s.stability = _ind(s.stability - EconomyRules.debtUnrest(ratio));
    final totalRevenue = s.budget.totalRevenue;
    if (totalRevenue > 0) {
      s.army = _ind(s.army + EconomyRules.armyDrift(s.budget.lineValue('army') / totalRevenue));
      s.education = _ind(
        s.education + EconomyRules.educationDrift(s.budget.lineValue('civil') / totalRevenue),
      );
    }

    // 5) نمو اسمي ثم دخول نصف السنة التالي وظهور الآثار المؤجلة
    s.budget.grow(EconomyRules.nominalGrowthPerHalfYear);
    s.round += 1;
    final due = <String>[];
    final stillPending = <PendingEffect>[];
    for (final p in s.pending) {
      if (p.dueRound <= s.round) {
        _applyEffects(s, p.effects);
        for (final c in p.lines) {
          s.budget.change(c.line, c.delta);
        }
        due.add(p.source);
      } else {
        stillPending.add(p);
      }
    }
    s.pending = stillPending;

    // 6) تنظيف الجولة المنتهية
    s.plan = null;
    s.picks = <int?>[null, null, null];

    final after = _snapshot(s);
    final changes = <String, int>{
      for (final k in before.keys) k: after[k]! - before[k]!,
    };
    final report = HalfYearReport(
      round: finishedRound,
      period: periodLabel(finishedRound),
      revenue: revenue,
      spending: spending,
      interest: interest,
      oneTimeCosts: costs,
      loans: loans,
      emergencyBorrowed: emergency,
      dueNotes: due,
      indicatorChanges: changes,
      treasuryAfter: s.treasury,
      debtAfter: s.debt,
      ending: evaluate(s),
    );
    s.lastReport = report.toPromptText();
    return report;
  }

  String _short(String text) =>
      text.length <= 60 ? text : '${text.substring(0, 60)}...';
}
