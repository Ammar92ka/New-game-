import '../models/budget.dart';

/// قواعد الاقتصاد (بالقروش). كل الأرقام هنا قابلة للتعديل من مكان واحد.
class EconomyRules {
  EconomyRules._();

  /// فائدة الدين السنوية.
  static const double interestRate = 0.12;

  /// عمولة الاقتراض الطارئ عند نفاد الخزينة.
  static const double emergencyLoanFee = 0.10;

  /// نمو اسمي (تضخم) لكل بنود الميزانية في كل نصف سنة.
  static const double nominalGrowthPerHalfYear = 0.01;

  /// كفاءة الجباية: 85% عند انعدام الاستقرار و100% عند كماله.
  static const double collectionBase = 0.85;
  static const double collectionSpan = 0.15;

  /// الإفلاس عندما يتجاوز الدين هذا المضاعف من الإيراد السنوي.
  static const double bankruptcyRatio = 6.0;

  static double collectionEfficiency(int stability) =>
      collectionBase + collectionSpan * (stability.clamp(0, 100) / 100);

  /// الإيراد المحصل فعليا في نصف سنة.
  static double halfYearRevenue(Budget b, int stability) =>
      b.totalRevenue / 2 * collectionEfficiency(stability);

  static double halfYearSpending(Budget b) => b.totalSpending / 2;

  static double halfYearInterest(double debt) => debt * interestRate / 2;

  /// نسبة الدين إلى الإيراد السنوي.
  static double debtRatio(double debt, Budget b) {
    final revenue = b.totalRevenue;
    return revenue <= 0 ? double.infinity : debt / revenue;
  }

  /// خصم الاستقرار بسبب ثقل الدين.
  static int debtUnrest(double ratio) {
    if (ratio >= 5) return 3;
    if (ratio >= 3) return 2;
    if (ratio >= 1.5) return 1;
    return 0;
  }

  /// أثر الإنفاق العسكري على قوة الجيش في نصف السنة (نسبة الإنفاق إلى الإيراد).
  static int armyDrift(double armyShare) {
    if (armyShare < 0.30) return -2;
    if (armyShare < 0.38) return -1;
    if (armyShare > 0.50) return 1;
    return 0;
  }

  /// أثر الإنفاق المدني على التعليم والتحديث.
  static int educationDrift(double civilShare) {
    if (civilShare >= 0.10) return 1;
    if (civilShare < 0.03) return -1;
    return 0;
  }
}
