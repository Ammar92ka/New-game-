import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/budget.dart';
import '../models/game_state.dart';
import '../services/economy.dart';
import '../ui/format.dart';
import '../ui/theme.dart';

/// لوحة الميزانية: بنود الإيراد والنفقات السنوية، وصافي نصف السنة المتوقع، والآثار القادمة.
class BudgetPanel extends StatelessWidget {
  const BudgetPanel({super.key, required this.state});

  final GameState state;

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.gold,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final b = state.budget;
    final efficiency = EconomyRules.collectionEfficiency(state.stability);
    final revenueHalf = EconomyRules.halfYearRevenue(b, state.stability);
    final spendingHalf = EconomyRules.halfYearSpending(b);
    final interestHalf = EconomyRules.halfYearInterest(state.debt);
    final net = revenueHalf - spendingHalf - interestHalf;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.receipt_long, color: AppColors.gold),
          title: const Text('الميزانية والآثار القادمة'),
          subtitle: Text(
            'صافي نصف السنة المتوقع: ${formatMoneySigned(net)} قرش',
            style: TextStyle(
              color: net < 0 ? AppColors.bad : AppColors.good,
              fontSize: 12.5,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title('الإيراد السنوي (${formatMoney(b.totalRevenue)} قرش)'),
            for (final l in revenueLines)
              _row(l.label, formatMoney(b.lineValue(l.key))),
            _row('كفاءة الجباية الحالية', '${(efficiency * 100).round()}%'),
            _title('النفقات السنوية (${formatMoney(b.totalSpending)} قرش)'),
            for (final l in spendingLines)
              _row(l.label, formatMoney(b.lineValue(l.key))),
            _title('الدين'),
            _row(
              'فائدة نصف السنة (${(EconomyRules.interestRate * 100).round()}% سنويا)',
              formatMoney(interestHalf),
              color: AppColors.bad,
            ),
            _row(
              'نسبة الدين إلى الإيراد السنوي',
              EconomyRules.debtRatio(state.debt, b).toStringAsFixed(2),
            ),
            _title('آثار قرارات سابقة قادمة'),
            if (state.pending.isEmpty)
              const Text(
                'لا توجد.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              )
            else
              for (final p in state.pending)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '• ${GameEngine.periodLabel(p.dueRound)}: ${p.source}',
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
