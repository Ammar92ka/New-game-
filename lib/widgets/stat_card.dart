import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// بطاقة مؤشر واحد: أيقونة واسم وقيمة، وشريط تقدم اختياري.
/// عند التحذير تظهر أيقونة تحذير بجانب لون الإطار، فلا يعتمد الفهم على اللون وحده.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.progress,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  /// بين 0 و 1.
  final double? progress;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppColors.bad : AppColors.gold;
    return Semantics(
      label:
          '$label: $value${hint == null ? '' : '، $hint'}${warn ? '، تحذير' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: warn ? AppColors.bad : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (warn)
                  const Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: AppColors.bad,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  color: accent,
                  backgroundColor: AppColors.cardBorder,
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
