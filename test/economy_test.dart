import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/models/budget.dart';
import 'package:ottoman_empire_1800/services/economy.dart';

void main() {
  group('الميزانية', () {
    test('ميزانية 1800 الابتدائية', () {
      final b = Budget.initial1800();
      expect(b.totalRevenue, equals(18000000));
      expect(b.totalSpending, equals(17000000));
      expect(b.lineValue('customs'), equals(2000000));
      expect(b.lineValue('army'), equals(8000000));
    });

    test('تغيير البند لا ينزل تحت الصفر والمفتاح المجهول يتجاهل', () {
      final b = Budget.initial1800();
      b.change('civil', -99000000);
      expect(b.lineValue('civil'), equals(0));
      b.change('nonsense', 5);
      expect(b.totalSpending, equals(16000000));
    });

    test('النمو الاسمي يطبق على الإيراد والنفقات', () {
      final b = Budget.initial1800()..grow(0.01);
      expect(b.totalRevenue, closeTo(18180000, 0.01));
      expect(b.totalSpending, closeTo(17170000, 0.01));
    });

    test('النسخة مستقلة والحفظ والاستعادة يحفظان القيم', () {
      final b = Budget.initial1800();
      final c = b.copy()..change('army', 1000);
      expect(b.lineValue('army'), equals(8000000));
      final back = Budget.fromJson(c.toJson());
      expect(back.lineValue('army'), equals(8001000));
    });

    test('استعادة قيم تالفة ترجع للافتراضي', () {
      final b = Budget.fromJson({
        'revenue': {'customs': 'x', 'land': -5},
        'spending': 7,
      });
      expect(b.lineValue('customs'), equals(2000000));
      expect(b.lineValue('land'), equals(0));
      expect(b.lineValue('army'), equals(8000000));
    });
  });

  group('قواعد الاقتصاد', () {
    test('كفاءة الجباية تتبع الاستقرار', () {
      expect(EconomyRules.collectionEfficiency(0), closeTo(0.85, 1e-9));
      expect(EconomyRules.collectionEfficiency(100), closeTo(1.0, 1e-9));
      expect(EconomyRules.collectionEfficiency(55), closeTo(0.9325, 1e-9));
    });

    test('إيراد ونفقات وفائدة نصف السنة', () {
      final b = Budget.initial1800();
      expect(EconomyRules.halfYearRevenue(b, 55), closeTo(8392500, 0.01));
      expect(EconomyRules.halfYearSpending(b), equals(8500000));
      expect(EconomyRules.halfYearInterest(8000000), closeTo(480000, 0.01));
    });

    test('نسبة الدين وأثرها على الاستقرار على درجات', () {
      final b = Budget.initial1800();
      expect(EconomyRules.debtRatio(36000000, b), closeTo(2, 1e-9));
      expect(EconomyRules.debtUnrest(1.49), equals(0));
      expect(EconomyRules.debtUnrest(1.5), equals(1));
      expect(EconomyRules.debtUnrest(3), equals(2));
      expect(EconomyRules.debtUnrest(5), equals(3));
    });

    test('إهمال الجيش يضعفه والإنفاق الكبير يقويه', () {
      expect(EconomyRules.armyDrift(0.25), equals(-2));
      expect(EconomyRules.armyDrift(0.35), equals(-1));
      expect(EconomyRules.armyDrift(0.44), equals(0));
      expect(EconomyRules.armyDrift(0.55), equals(1));
    });

    test('الإنفاق المدني يرفع التعليم وإهماله يخفضه', () {
      expect(EconomyRules.educationDrift(0.12), equals(1));
      expect(EconomyRules.educationDrift(0.056), equals(0));
      expect(EconomyRules.educationDrift(0.02), equals(-1));
    });
  });
}
