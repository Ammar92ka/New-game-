import 'budget.dart';

/// أثر على المؤشرات الخمسة (من 0 إلى 100).
class Effects {
  final int legitimacy;
  final int stability;
  final int army;
  final int foreign;
  final int education;

  const Effects({
    this.legitimacy = 0,
    this.stability = 0,
    this.army = 0,
    this.foreign = 0,
    this.education = 0,
  });

  bool get isZero =>
      legitimacy == 0 && stability == 0 && army == 0 && foreign == 0 && education == 0;

  Effects clampTo(int limit) => Effects(
    legitimacy: legitimacy.clamp(-limit, limit),
    stability: stability.clamp(-limit, limit),
    army: army.clamp(-limit, limit),
    foreign: foreign.clamp(-limit, limit),
    education: education.clamp(-limit, limit),
  );

  Map<String, dynamic> toJson() => {
    'legitimacy': legitimacy,
    'stability': stability,
    'army': army,
    'foreign': foreign,
    'education': education,
  };

  factory Effects.fromJson(Object? json) {
    if (json is! Map) return const Effects();
    int n(String k) {
      final v = json[k];
      if (v is num && v.isFinite) return v.round();
      return 0;
    }

    return Effects(
      legitimacy: n('legitimacy'),
      stability: n('stability'),
      army: n('army'),
      foreign: n('foreign'),
      education: n('education'),
    );
  }
}

/// تغيير سنوي في بند من الميزانية (بالقروش). الموجب يزيد البند والسالب ينقصه.
class LineChange {
  final String line;
  final double delta;
  const LineChange(this.line, this.delta);

  Map<String, dynamic> toJson() => {'line': line, 'delta': delta};

  factory LineChange.fromJson(Object? json) {
    if (json is Map) {
      final line = json['line'];
      final delta = json['delta'];
      if (line is String && delta is num && delta.isFinite) {
        return LineChange(line, delta.toDouble());
      }
    }
    return const LineChange('', 0);
  }
}

/// أنواع القرارات الثلاثة في كل جولة.
enum DecisionCategory {
  internal('internal', 'سياسة داخلية'),
  economy('economy', 'اقتصاد ومالية'),
  foreign('foreign', 'سياسة خارجية');

  final String id;
  final String label;
  const DecisionCategory(this.id, this.label);

  static DecisionCategory? fromId(Object? raw) {
    if (raw is! String) return null;
    final s = raw.trim().toLowerCase();
    for (final c in DecisionCategory.values) {
      if (c.id == s) return c;
    }
    return null;
  }
}

/// خيار واحد من ثلاثة، كتبه الذكاء الاصطناعي وعايرته اللعبة.
class DecisionOption {
  final String text;
  final String result;
  final String reaction;
  final String note;

  /// مصروف لمرة واحدة (قروش).
  final double cost;

  /// قرض لمرة واحدة: يدخل الخزينة ويضاف إلى الدين (قروش).
  final double loan;

  /// أثر فوري على المؤشرات.
  final Effects now;

  /// أثر مؤجل على المؤشرات وعلى بنود الميزانية بعد [delay] نصف سنة.
  final Effects later;
  final int delay;
  final List<LineChange> lineChanges;

  /// هل عدّلت اللعبة أحد أرقام هذا الخيار ليوافق الواقع؟
  final bool calibrated;

  const DecisionOption({
    required this.text,
    required this.result,
    this.reaction = '',
    this.note = '',
    this.cost = 0,
    this.loan = 0,
    this.now = const Effects(),
    this.later = const Effects(),
    this.delay = 0,
    this.lineChanges = const [],
    this.calibrated = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'result': result,
    'reaction': reaction,
    'note': note,
    'cost': cost,
    'loan': loan,
    'now': now.toJson(),
    'later': later.toJson(),
    'delay': delay,
    'line_changes': [for (final c in lineChanges) c.toJson()],
    'calibrated': calibrated,
  };

  factory DecisionOption.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k] is String ? (json[k] as String).trim() : '';
    double d(String k) {
      final v = json[k];
      return v is num && v.isFinite ? v.toDouble() : 0;
    }

    final changes = <LineChange>[];
    final rawChanges = json['line_changes'];
    if (rawChanges is List) {
      for (final c in rawChanges) {
        final lc = LineChange.fromJson(c);
        if (lc.line.isNotEmpty) changes.add(lc);
      }
    }
    final delay = json['delay'];
    return DecisionOption(
      text: s('text'),
      result: s('result'),
      reaction: s('reaction'),
      note: s('note'),
      cost: d('cost'),
      loan: d('loan'),
      now: Effects.fromJson(json['now']),
      later: Effects.fromJson(json['later']),
      delay: delay is num && delay.isFinite ? delay.round() : 0,
      lineChanges: changes,
      calibrated: json['calibrated'] == true,
    );
  }
}

class Decision {
  final DecisionCategory category;
  final String title;
  final String place;
  final String scene;
  final String dilemma;
  final List<DecisionOption> options;

  const Decision({
    required this.category,
    required this.title,
    this.place = '',
    required this.scene,
    required this.dilemma,
    required this.options,
  });

  Map<String, dynamic> toJson() => {
    'category': category.id,
    'title': title,
    'place': place,
    'scene': scene,
    'dilemma': dilemma,
    'options': [for (final o in options) o.toJson()],
  };

  factory Decision.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k] is String ? (json[k] as String).trim() : '';
    final options = <DecisionOption>[];
    final raw = json['options'];
    if (raw is List) {
      for (final o in raw) {
        if (o is Map) options.add(DecisionOption.fromJson(Map<String, dynamic>.from(o)));
      }
    }
    return Decision(
      category: DecisionCategory.fromId(json['category']) ?? DecisionCategory.internal,
      title: s('title'),
      place: s('place'),
      scene: s('scene'),
      dilemma: s('dilemma'),
      options: options,
    );
  }
}

/// جولة نصف سنوية: ثلاثة قرارات كتبها الذكاء الاصطناعي.
class RoundPlan {
  final String headline;
  final String briefing;

  /// ملاحظات الذاكرة المحدثة التي يعيدها الذكاء الاصطناعي ليتذكر العالم في الجولة التالية.
  final String chronicle;
  final List<Decision> decisions;

  const RoundPlan({
    required this.headline,
    required this.briefing,
    this.chronicle = '',
    required this.decisions,
  });

  Map<String, dynamic> toJson() => {
    'headline': headline,
    'briefing': briefing,
    'chronicle': chronicle,
    'decisions': [for (final d in decisions) d.toJson()],
  };

  factory RoundPlan.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k] is String ? (json[k] as String).trim() : '';
    final decisions = <Decision>[];
    final raw = json['decisions'];
    if (raw is List) {
      for (final d in raw) {
        if (d is Map) decisions.add(Decision.fromJson(Map<String, dynamic>.from(d)));
      }
    }
    return RoundPlan(
      headline: s('headline'),
      briefing: s('briefing'),
      chronicle: s('chronicle'),
      decisions: decisions,
    );
  }
}

/// أسماء بنود الميزانية في وصف الأثر.
String describeLineChange(LineChange c) => budgetLineLabel(c.line);
