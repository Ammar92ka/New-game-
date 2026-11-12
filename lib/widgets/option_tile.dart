import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/round_plan.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import 'effect_chips.dart';

String _months(int halfYears) {
  final n = halfYears * 6;
  return n <= 10 ? '$n أشهر' : '$n شهرا';
}

/// خيار واحد من قرار: نصه وتكلفته وآثاره الظاهرة قبل الاختيار.
/// عند الاختيار تظهر النتيجة المتوقعة وردود الفعل والأساس التاريخي.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.letter,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final DecisionOption option;
  final bool selected;
  final VoidCallback onTap;

  static const Color _selectedBg = Color(0x1FC9A227);

  Widget _labeled(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = <Widget>[];
    if (option.cost > 0) {
      now.add(
        Pill(
          text: 'مصروف ${formatMoney(option.cost)} قرش',
          icon: Icons.payments_outlined,
          good: false,
        ),
      );
    }
    if (option.loan > 0) {
      now.add(
        Pill(
          text: 'قرض ${formatMoney(option.loan)} قرش',
          icon: Icons.account_balance,
        ),
      );
    }

    final later = <Widget>[];
    for (final c in option.lineChanges) {
      final revenue = isRevenueLine(c.line);
      final up = c.delta > 0;
      later.add(
        Pill(
          text: '${budgetLineLabel(c.line)} ${formatMoneySigned(c.delta)} سنويا',
          up: up,
          good: revenue ? up : !up,
        ),
      );
    }

    final hasLater = !option.later.isZero || option.lineChanges.isNotEmpty;

    return Semantics(
      button: true,
      selected: selected,
      label: 'الخيار $letter: ${option.text}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? _selectedBg : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: selected
                        ? AppColors.gold
                        : AppColors.cardBorder,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected ? AppColors.navy : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.text,
                      style: const TextStyle(fontSize: 15.5, height: 1.6),
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 6),
                      child: Icon(Icons.check_circle, color: AppColors.gold),
                    ),
                ],
              ),
              if (now.isNotEmpty || !option.now.isZero) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...now,
                    EffectChips(effects: option.now),
                  ],
                ),
              ],
              if (hasLater) ...[
                const SizedBox(height: 8),
                Text(
                  option.delay <= 0
                      ? 'آثار ممتدة:'
                      : 'بعد ${_months(option.delay)}:',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    EffectChips(effects: option.later),
                    ...later,
                  ],
                ),
              ],
              if (selected) ...[
                const Divider(height: 20),
                _labeled('النتيجة المتوقعة', option.result),
                if (option.reaction.isNotEmpty)
                  _labeled('ردود الفعل', option.reaction),
                if (option.note.isNotEmpty)
                  _labeled('الأساس التاريخي', option.note),
                if (option.calibrated)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tune, size: 16, color: AppColors.muted),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'عُدّلت بعض أرقام هذا الخيار لتوافق حجم ميزانية الدولة في هذه المرحلة.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
