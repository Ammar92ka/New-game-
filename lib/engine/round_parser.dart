import 'dart:convert';

import '../models/budget.dart';
import '../models/round_plan.dart';

/// خطأ في شكل ما كتبه الذكاء الاصطناعي. رسالته تعاد إليه عند إعادة المحاولة.
class PlanFormatException implements Exception {
  final String message;
  const PlanFormatException(this.message);

  @override
  String toString() => message;
}

/// يحول رد الذكاء الاصطناعي (JSON) إلى جولة خام قبل المعايرة.
class RoundParser {
  RoundParser._();

  static RoundPlan parse(String text) {
    final json = _extractJson(text);
    final headline = _str(json['headline']);
    final briefing = _str(json['briefing']);
    if (briefing.isEmpty) {
      throw const PlanFormatException('حقل briefing (ملخص الوضع) فارغ أو مفقود.');
    }

    final rawDecisions = json['decisions'];
    if (rawDecisions is! List) {
      throw const PlanFormatException('حقل decisions يجب أن يكون قائمة من ثلاثة قرارات.');
    }

    final byCategory = <DecisionCategory, Decision>{};
    for (final raw in rawDecisions) {
      if (raw is! Map) continue;
      final category = DecisionCategory.fromId(raw['category']);
      if (category == null || byCategory.containsKey(category)) continue;
      byCategory[category] = _decision(category, Map<String, dynamic>.from(raw));
    }
    for (final c in DecisionCategory.values) {
      if (!byCategory.containsKey(c)) {
        throw PlanFormatException(
          'يجب قرار واحد لكل فئة: internal و economy و foreign. الفئة المفقودة: ${c.id}.',
        );
      }
    }

    return RoundPlan(
      headline: headline,
      briefing: briefing,
      chronicle: _str(json['chronicle']),
      decisions: [for (final c in DecisionCategory.values) byCategory[c]!],
    );
  }

  static Map<String, dynamic> _extractJson(String text) {
    var t = text.trim();
    // يزيل أسوار الكود إن وجدت
    t = t.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const PlanFormatException('الرد ليس كائن JSON.');
    }
    try {
      final decoded = jsonDecode(t.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException catch (e) {
      throw PlanFormatException('JSON غير صالح: ${e.message}');
    }
    throw const PlanFormatException('الرد ليس كائن JSON.');
  }

  static Decision _decision(DecisionCategory category, Map<String, dynamic> raw) {
    final title = _str(raw['title']);
    final scene = _str(raw['scene']);
    final dilemma = _str(raw['dilemma']);
    if (title.isEmpty || scene.isEmpty || dilemma.isEmpty) {
      throw PlanFormatException(
        'القرار ${category.id} ناقص: يلزم title و scene و dilemma.',
      );
    }
    final rawOptions = raw['options'];
    final options = <DecisionOption>[];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        if (o is Map && options.length < 3) {
          options.add(_option(category, Map<String, dynamic>.from(o)));
        }
      }
    }
    if (options.length < 3) {
      throw PlanFormatException('القرار ${category.id} يحتاج ثلاثة خيارات بالضبط.');
    }
    return Decision(
      category: category,
      title: title,
      place: _str(raw['place']),
      scene: scene,
      dilemma: dilemma,
      options: options,
    );
  }

  static DecisionOption _option(DecisionCategory category, Map<String, dynamic> raw) {
    final text = _str(raw['text']);
    final result = _str(raw['result']);
    if (text.isEmpty || result.isEmpty) {
      throw PlanFormatException('خيار في القرار ${category.id} بلا text أو result.');
    }
    final changes = <LineChange>[];
    final rawChanges = raw['line_changes'];
    if (rawChanges is List) {
      for (final c in rawChanges) {
        if (c is Map) {
          final line = c['line'];
          final delta = toNum(c['delta']);
          if (line is String && delta != null) changes.add(LineChange(line.trim(), delta));
        }
      }
    }
    return DecisionOption(
      text: text,
      result: result,
      reaction: _str(raw['reaction']),
      note: _str(raw['note']),
      cost: toNum(raw['cost']) ?? 0,
      loan: toNum(raw['loan']) ?? 0,
      now: _effects(raw['now']),
      later: _effects(raw['later']),
      delay: (toNum(raw['delay']) ?? 0).round(),
      lineChanges: changes,
    );
  }

  static Effects _effects(Object? raw) {
    if (raw is! Map) return const Effects();
    int n(String k) => (toNum(raw[k]) ?? 0).round();
    return Effects(
      legitimacy: n('legitimacy'),
      stability: n('stability'),
      army: n('army'),
      foreign: n('foreign'),
      education: n('education'),
    );
  }

  /// يقبل رقما أو نصا رقميا (بما فيه الفواصل والأرقام العربية الهندية).
  static double? toNum(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is String) {
      var s = v.trim();
      const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
      for (var i = 0; i < arabicDigits.length; i++) {
        s = s.replaceAll(arabicDigits[i], '$i');
      }
      s = s.replaceAll(',', '').replaceAll('٬', '').replaceAll('+', '');
      final parsed = double.tryParse(s);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  static String _str(Object? v) => v is String ? v.trim() : '';

  /// يتحقق أن المفتاح بند ميزانية معروف.
  static bool knownLine(String key) => isBudgetLine(key);
}
