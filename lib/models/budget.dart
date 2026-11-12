/// بند في الميزانية (إيراد أو نفقة) بمفتاح ثابت يستخدمه الذكاء الاصطناعي واسم عربي للعرض.
class BudgetLine {
  final String key;
  final String label;
  const BudgetLine(this.key, this.label);
}

/// بنود الإيراد السنوي (بالقروش).
const List<BudgetLine> revenueLines = [
  BudgetLine('customs', 'الجمارك والمكوس'),
  BudgetLine('land', 'الضرائب الزراعية والالتزام والمالكانة'),
  BudgetLine('provinces', 'أموال الولايات (مصر وغيرها)'),
  BudgetLine('other', 'الجزية والاحتكارات وضرائب أخرى'),
];

/// بنود النفقات السنوية (بالقروش).
const List<BudgetLine> spendingLines = [
  BudgetLine('army', 'الجيش والبحرية'),
  BudgetLine('palace', 'القصر والبلاط'),
  BudgetLine('admin', 'الإدارة والبيروقراطية'),
  BudgetLine('civil', 'التعليم والصحة والأشغال'),
];

bool isRevenueLine(String key) => revenueLines.any((l) => l.key == key);
bool isSpendingLine(String key) => spendingLines.any((l) => l.key == key);
bool isBudgetLine(String key) => isRevenueLine(key) || isSpendingLine(key);

String budgetLineLabel(String key) {
  for (final l in [...revenueLines, ...spendingLines]) {
    if (l.key == key) return l.label;
  }
  return key;
}

/// ميزانية الدولة السنوية بالقروش. 1 قرش = 40 بارة.
class Budget {
  final Map<String, double> revenue;
  final Map<String, double> spending;

  Budget({required Map<String, double> revenue, required Map<String, double> spending})
    : revenue = Map<String, double>.of(revenue),
      spending = Map<String, double>.of(spending);

  /// ميزانية بداية 1800 بقيم تقريبية مبنية على الأدبيات الاقتصادية:
  /// الإيراد المركزي نحو 10 ملايين قرش مطلع القرن الثامن عشر ثم نحو 14.5 مليون
  /// في ستينياته، مع تضخم كبير حتى 1800، وإيراد مصر نحو 3 ملايين قرش (120 مليون بارة).
  /// هذه أرقام لعب معايرة وليست إحصاء رسميا، وتعدل من هنا إن أردت.
  factory Budget.initial1800() => Budget(
    revenue: {
      'customs': 2000000,
      'land': 9000000,
      'provinces': 3000000,
      'other': 4000000,
    },
    spending: {
      'army': 8000000,
      'palace': 3500000,
      'admin': 4500000,
      'civil': 1000000,
    },
  );

  double get totalRevenue => revenue.values.fold(0.0, (a, b) => a + b);
  double get totalSpending => spending.values.fold(0.0, (a, b) => a + b);

  double lineValue(String key) => revenue[key] ?? spending[key] ?? 0;

  /// يغير بندا بقيمة سنوية، ولا يسمح بنزوله تحت الصفر. المفتاح غير المعروف يُتجاهل.
  void change(String key, double delta) {
    if (revenue.containsKey(key)) {
      revenue[key] = (revenue[key]! + delta).clamp(0.0, double.infinity).toDouble();
    } else if (spending.containsKey(key)) {
      spending[key] = (spending[key]! + delta).clamp(0.0, double.infinity).toDouble();
    }
  }

  /// نمو اسمي (تضخم) لكل البنود.
  void grow(double rate) {
    for (final k in revenue.keys.toList()) {
      revenue[k] = revenue[k]! * (1 + rate);
    }
    for (final k in spending.keys.toList()) {
      spending[k] = spending[k]! * (1 + rate);
    }
  }

  Budget copy() => Budget(revenue: revenue, spending: spending);

  Map<String, dynamic> toJson() => {'revenue': revenue, 'spending': spending};

  factory Budget.fromJson(Object? json) {
    final base = Budget.initial1800();
    if (json is! Map) return base;
    Map<String, double> read(Object? raw, Map<String, double> fallback) {
      final out = Map<String, double>.of(fallback);
      if (raw is Map) {
        for (final k in fallback.keys) {
          final v = raw[k];
          if (v is num && v.isFinite) out[k] = v.toDouble().clamp(0.0, 1e15).toDouble();
        }
      }
      return out;
    }

    return Budget(
      revenue: read(json['revenue'], base.revenue),
      spending: read(json['spending'], base.spending),
    );
  }
}
