class Power {
  String name;
  double influence;
  double satisfaction;
  double danger;
  Power(this.name, this.influence, this.satisfaction, this.danger);
}

class PowersSystem {
  Map<String, Power> powers = {
    'السلطة الدينية': Power('السلطة الدينية', 80, 60, 40),
    'الإنكشارية': Power('الإنكشارية', 90, 35, 85),
    'الولاة': Power('الولاة', 70, 50, 55),
    'الملتزمون': Power('الملتزمون', 65, 45, 50),
    'القبائل': Power('القبائل', 50, 55, 40),
    'المماليك': Power('المماليك', 75, 30, 70),
    'التجار': Power('التجار', 60, 65, 25),
    'الأقليات': Power('الأقليات', 45, 50, 35),
  };

  String reform(String name) =>
      'بدأ إصلاح $name من الداخل: 2-5 سنوات، مخاطر منخفضة';
  String merge(String name) => 'بدأ دمج $name: 1-3 سنوات';
  String contain(String name) => 'بدأ احتواء $name: قد يصل إلى 7 سنوات';
  String dissolve(String name) {
    if (powers[name]!.danger > 70)
      return 'خطر! حل $name قد يؤدي لتمرد أو انقلاب';
    return 'تم حل $name';
  }
}
