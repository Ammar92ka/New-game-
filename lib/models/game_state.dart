import 'budget.dart';
import 'round_plan.dart';

/// سطر في سجل القرارات.
class HistoryEntry {
  final int round;
  final String category;
  final String title;
  final String choice;
  final String result;

  const HistoryEntry({
    required this.round,
    required this.category,
    required this.title,
    required this.choice,
    this.result = '',
  });

  Map<String, dynamic> toJson() => {
    'round': round,
    'category': category,
    'title': title,
    'choice': choice,
    'result': result,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k] is String ? json[k] as String : '';
    final r = json['round'];
    return HistoryEntry(
      round: r is num ? r.toInt() : 0,
      category: s('category'),
      title: s('title'),
      choice: s('choice'),
      result: s('result'),
    );
  }
}

/// أثر مؤجل ينتظر موعده (بعد عدد من أنصاف السنوات).
class PendingEffect {
  final int dueRound;
  final Effects effects;
  final List<LineChange> lines;
  final String source;

  const PendingEffect({
    required this.dueRound,
    this.effects = const Effects(),
    this.lines = const [],
    this.source = '',
  });

  Map<String, dynamic> toJson() => {
    'due': dueRound,
    'effects': effects.toJson(),
    'lines': [for (final l in lines) l.toJson()],
    'source': source,
  };

  factory PendingEffect.fromJson(Map<String, dynamic> json) {
    final lines = <LineChange>[];
    final raw = json['lines'];
    if (raw is List) {
      for (final l in raw) {
        final lc = LineChange.fromJson(l);
        if (lc.line.isNotEmpty) lines.add(lc);
      }
    }
    final due = json['due'];
    return PendingEffect(
      dueRound: due is num ? due.toInt() : 0,
      effects: Effects.fromJson(json['effects']),
      lines: lines,
      source: json['source'] is String ? json['source'] as String : '',
    );
  }
}

/// حالة الحملة كاملة. تحفظ وتستعاد بما فيها الجولة الحالية التي كتبها الذكاء الاصطناعي،
/// فلا تضيع عند إغلاق التطبيق ولا تُولَّد من جديد.
class GameState {
  /// نسخة صيغة الحفظ. أي حفظ بنسخة أخرى يهمل ولا يكسر التطبيق.
  static const int schema = 2;

  double treasury; // قروش
  double debt; // قروش
  int legitimacy;
  int stability;
  int army;
  int foreign;
  int education;
  Budget budget;

  /// رقم نصف السنة (0 = النصف الأول من 1800).
  int round;
  List<PendingEffect> pending;
  List<HistoryEntry> history;

  /// ذاكرة العالم كما كتبها الذكاء الاصطناعي في آخر جولة.
  String chronicle;

  /// نص تقرير نصف السنة الأخير، يرسل للذكاء الاصطناعي لتكتب الجولة التالية بناء عليه.
  String lastReport;

  /// الجولة الحالية واختيارات اللاعب فيها (null = لم يختر بعد).
  RoundPlan? plan;
  List<int?> picks;

  GameState({
    this.treasury = 3000000,
    this.debt = 6000000,
    this.legitimacy = 65,
    this.stability = 55,
    this.army = 45,
    this.foreign = 45,
    this.education = 15,
    Budget? budget,
    this.round = 0,
    List<PendingEffect>? pending,
    List<HistoryEntry>? history,
    this.chronicle = '',
    this.lastReport = '',
    this.plan,
    List<int?>? picks,
  }) : budget = budget ?? Budget.initial1800(),
       pending = pending ?? <PendingEffect>[],
       history = history ?? <HistoryEntry>[],
       picks = picks ?? <int?>[null, null, null];

  bool get hasAllPicks => picks.length == 3 && picks.every((p) => p != null);

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'treasury': treasury,
    'debt': debt,
    'legitimacy': legitimacy,
    'stability': stability,
    'army': army,
    'foreign': foreign,
    'education': education,
    'budget': budget.toJson(),
    'round': round,
    'pending': [for (final p in pending) p.toJson()],
    'history': [for (final h in history) h.toJson()],
    'chronicle': chronicle,
    'lastReport': lastReport,
    'plan': plan?.toJson(),
    'picks': picks,
  };

  /// يرمي خطأ إذا كان الحفظ بصيغة غير مدعومة؛ والخدمة التي تستدعيه تلتقط الخطأ.
  factory GameState.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != schema) {
      throw const FormatException('صيغة حفظ غير مدعومة');
    }
    double money(String k, double d) {
      final v = json[k];
      return v is num && v.isFinite ? v.toDouble().clamp(0.0, 1e15).toDouble() : d;
    }

    int ind(String k, int d) {
      final v = json[k];
      return v is num && v.isFinite ? v.round().clamp(0, 100).toInt() : d;
    }

    final history = <HistoryEntry>[];
    final rawHistory = json['history'];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is Map) history.add(HistoryEntry.fromJson(Map<String, dynamic>.from(h)));
      }
    }
    final pending = <PendingEffect>[];
    final rawPending = json['pending'];
    if (rawPending is List) {
      for (final p in rawPending) {
        if (p is Map) pending.add(PendingEffect.fromJson(Map<String, dynamic>.from(p)));
      }
    }
    RoundPlan? plan;
    final rawPlan = json['plan'];
    if (rawPlan is Map) {
      final parsed = RoundPlan.fromJson(Map<String, dynamic>.from(rawPlan));
      if (parsed.decisions.length == 3) plan = parsed;
    }
    final picks = <int?>[null, null, null];
    final rawPicks = json['picks'];
    if (plan != null && rawPicks is List) {
      for (var i = 0; i < 3 && i < rawPicks.length; i++) {
        final p = rawPicks[i];
        if (p is num) {
          final idx = p.toInt();
          if (idx >= 0 && idx < plan.decisions[i].options.length) picks[i] = idx;
        }
      }
    }
    final round = json['round'];
    return GameState(
      treasury: money('treasury', 3000000),
      debt: money('debt', 6000000),
      legitimacy: ind('legitimacy', 65),
      stability: ind('stability', 55),
      army: ind('army', 45),
      foreign: ind('foreign', 45),
      education: ind('education', 15),
      budget: Budget.fromJson(json['budget']),
      round: round is num ? round.toInt().clamp(0, 100000).toInt() : 0,
      pending: pending,
      history: history,
      chronicle: json['chronicle'] is String ? json['chronicle'] as String : '',
      lastReport: json['lastReport'] is String ? json['lastReport'] as String : '',
      plan: plan,
      picks: picks,
    );
  }

  /// نسخة مستقلة (للتجارب والاختبارات).
  GameState copy() => GameState.fromJson(
    (toJson()..['schema'] = schema),
  );
}
