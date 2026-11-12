class Country {
  String name;
  double relation;
  String mood;
  String goal;
  Country(this.name, this.relation, this.mood, this.goal);
}

class DiplomacySystem {
  Map<String, Country> countries = {
    'فرنسا': Country('فرنسا', 55, 'متحمسة للتحالف', 'طرد بريطانيا من مصر'),
    'بريطانيا': Country('بريطانيا', 52, 'حذرة', 'طرد الفرنسيين من مصر'),
    'روسيا': Country('روسيا', 35, 'عدائية', 'دعم تمرد البلقان'),
    'النمسا': Country('النمسا', 60, 'محايدة', 'حفظ التوازن'),
    'إيران': Country('إيران', 45, 'متوترة', 'الحدود الشرقية'),
    'مصر': Country('مصر', 48, 'متعبة', 'الاستقلال الذاتي'),
  };

  String tradeTreaty(String name) {
    var c = countries[name]!;
    c.relation = (c.relation + 8).clamp(0, 100);
    if (name == 'فرنسا') countries['بريطانيا']!.relation -= 5;
    if (name == 'بريطانيا') countries['فرنسا']!.relation -= 5;
    return 'تم توقيع معاهدة تجارة مع $name. العلاقة الآن ${c.relation}';
  }

  String requestLoan(String name) {
    var c = countries[name]!;
    if (c.relation < 30) return '$name رفضت القرض بسبب العلاقة السيئة';
    return 'وافق $name على قرض 2000 قطعة ذهبية';
  }

  String calmDown(String name) {
    countries[name]!.relation = (countries[name]!.relation + 6).clamp(0, 100);
    return 'تمت التهدئة مع $name';
  }

  String rejectDemands(String name) {
    countries[name]!.relation = (countries[name]!.relation - 10).clamp(0, 100);
    return 'تم رفض مطالب $name';
  }

  List<String> warnings() {
    List<String> w = [];
    if (countries['روسيا']!.relation < 20) w.add('خطر حرب: روسيا تحت 20');
    for (var e in countries.entries) {
      if (e.value.relation < 20)
        w.add('تحذير: ${e.key} تحت 20 - حصار أو تمرد محتمل');
    }
    return w;
  }
}
