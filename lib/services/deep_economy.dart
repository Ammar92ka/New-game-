class ProvinceEconomy {
  String name;
  double revenue;
  double expenses;
  double mood;
  ProvinceEconomy(this.name, this.revenue, this.expenses, this.mood);
}

class DeepEconomy {
  double treasury = 12000;
  double debt = 0;
  double grainPrice = 12;
  double inflation = 4;
  int deficitMonths = 0;
  double corruptionLeak = 0.15;

  Map<String, ProvinceEconomy> provinces = {
    'بغداد': ProvinceEconomy('بغداد', 900, 700, 55),
    'مصر': ProvinceEconomy('مصر', 1800, 1200, 40),
    'الشام': ProvinceEconomy('الشام', 1100, 800, 60),
    'البلقان': ProvinceEconomy('البلقان', 1300, 1000, 45),
    'الأناضول': ProvinceEconomy('الأناضول', 1500, 900, 65),
  };

  String monthlyReport() {
    double totalRev = provinces.values.fold(0, (a, b) => a + b.revenue);
    double totalExp = provinces.values.fold(0, (a, b) => a + b.expenses);
    double leak = totalRev * corruptionLeak;
    double net = totalRev - leak - totalExp;
    treasury += net;
    if (net < 0)
      deficitMonths++;
    else
      deficitMonths = 0;
    String crisis = '';
    if (deficitMonths >= 3) {
      inflation += 2;
      grainPrice += 3;
      crisis = 'أزمة: 3 أشهر عجز - أزمة عملة وارتفاع أسعار';
    }
    return 'إيرادات $totalRev - تسرب $leak - نفقات $totalExp = صافي $net - $crisis';
  }
}
