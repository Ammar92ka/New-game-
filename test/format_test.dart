import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/ui/format.dart';

void main() {
  group('تنسيق المبالغ', () {
    test('ملايين وآلاف بلا أصفار زائدة', () {
      expect(formatMoney(3000000), equals('3 مليون'));
      expect(formatMoney(2500000), equals('2.5 مليون'));
      expect(formatMoney(18180000), equals('18.18 مليون'));
      expect(formatMoney(800000), equals('800 ألف'));
      expect(formatMoney(1500), equals('1.5 ألف'));
      expect(formatMoney(950), equals('950'));
      expect(formatMoney(0), equals('0'));
      expect(formatMoney(2000000000), equals('2 مليار'));
    });

    test('المبلغ مع الإشارة', () {
      expect(formatMoneySigned(1500000), equals('+1.5 مليون'));
      expect(formatMoneySigned(-250000), equals('-250 ألف'));
      expect(formatMoneySigned(0), equals('0'));
      expect(formatMoneySigned(0.2), equals('0'));
    });
  });
}
