import 'dart:convert';
import 'dart:math';

/// ذكاء اصطناعي وهمي للاختبارات: يكتب جولة JSON صالحة بأرقام عشوائية،
/// بعضها مبالغ فيه عمدا لاختبار المعايرة.
class FakeAi {
  FakeAi({int seed = 1, this.wild = false}) : _rnd = Random(seed);

  final Random _rnd;

  /// عندما تكون true يكتب أرقاما خارج الحدود المعقولة.
  final bool wild;
  int calls = 0;

  Map<String, dynamic> _effects(int scale) => {
    'legitimacy': _rnd.nextInt(scale * 2 + 1) - scale,
    'stability': _rnd.nextInt(scale * 2 + 1) - scale,
    'army': _rnd.nextInt(scale * 2 + 1) - scale,
    'foreign': _rnd.nextInt(scale * 2 + 1) - scale,
    'education': _rnd.nextInt(scale * 2 + 1) - scale,
  };

  Map<String, dynamic> _option(String name) {
    final big = wild ? 50 : 1;
    const lines = ['customs', 'land', 'provinces', 'other', 'army', 'palace', 'admin', 'civil'];
    return {
      'text': 'خيار $name',
      'result': 'نتيجة $name',
      'reaction': 'رد فعل $name',
      'note': 'أساس $name',
      'cost': _rnd.nextInt(3000000) * big,
      'loan': _rnd.nextInt(4) == 0 ? _rnd.nextInt(4000000) * big : 0,
      'now': _effects(wild ? 30 : 4),
      'later': _effects(wild ? 40 : 6),
      'delay': _rnd.nextInt(wild ? 40 : 6),
      'line_changes': [
        {
          'line': lines[_rnd.nextInt(lines.length)],
          'delta': (_rnd.nextInt(2000000) - 1000000) * big,
        },
      ],
    };
  }

  Map<String, dynamic> _decision(String category) => {
    'category': category,
    'title': 'قرار $category',
    'place': 'إسطنبول',
    'scene': 'مشهد $category',
    'dilemma': 'معضلة $category',
    'options': [_option('أ'), _option('ب'), _option('ج')],
  };

  /// يحاكي استدعاء المزود: يعيد نص JSON لجولة.
  Future<String> call(String prompt) async {
    calls++;
    return jsonEncode({
      'headline': 'عنوان',
      'briefing': 'ملخص الوضع',
      'chronicle': 'ذاكرة العالم',
      'decisions': [
        _decision('internal'),
        _decision('economy'),
        _decision('foreign'),
      ],
    });
  }
}
