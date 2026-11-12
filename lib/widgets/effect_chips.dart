import 'package:flutter/material.dart';

import '../models/round_plan.dart';
import '../ui/format.dart';
import '../ui/theme.dart';

/// حبة صغيرة: أيقونة سهم ونص، بلون أخضر للخير وأحمر للضرر.
/// السهم والإشارة يوصلان المعنى حتى بدون الاعتماد على اللون.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.good,
    this.up,
    this.icon,
  });

  final String text;

  /// true أخضر، false أحمر، null محايد.
  final bool? good;
  final bool? up;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = good == null
        ? AppColors.muted
        : (good! ? AppColors.good : AppColors.bad);
    final bg = good == null
        ? AppColors.cardBorder
        : (good! ? AppColors.goodBg : AppColors.badBg);
    final iconData = icon ?? (up == null ? null : (up! ? Icons.arrow_upward : Icons.arrow_downward));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

/// يعرض أثرا على المؤشرات الخمسة.
class EffectChips extends StatelessWidget {
  const EffectChips({super.key, required this.effects, this.prefix = ''});

  final Effects effects;

  /// نص يسبق كل اسم (مثل "لاحقا: ").
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    void add(String label, int value) {
      if (value == 0) return;
      chips.add(
        Pill(
          text: '$prefix$label ${formatSigned(value)}',
          good: value > 0,
          up: value > 0,
        ),
      );
    }

    add('الشرعية', effects.legitimacy);
    add('الاستقرار', effects.stability);
    add('الجيش', effects.army);
    add('المكانة الدولية', effects.foreign);
    add('التعليم', effects.education);

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
