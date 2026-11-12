import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import 'effect_chips.dart';

/// تقرير نصف السنة بعد تنفيذ قرارات الجولة.
class ReportDialog extends StatelessWidget {
  const ReportDialog({super.key, required this.report});

  final HalfYearReport report;

  Widget _row(String label, double value, {bool signed = true, Color? color}) {
    final text = signed ? formatMoneySigned(value) : formatMoney(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final net = r.net;
    final changes = r.indicatorChanges.entries.where((e) => e.value != 0).toList();
    return AlertDialog(
      title: Text('تقرير ${r.period}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('الإيراد المحصل', r.revenue),
            _row('النفقات', -r.spending),
            _row('فوائد الدين', -r.interest),
            if (r.oneTimeCosts > 0) _row('مصروفات القرارات', -r.oneTimeCosts),
            if (r.loans > 0) _row('قروض حصلت عليها', r.loans),
            const Divider(height: 18),
            _row(
              'صافي الميزانية',
              net,
              color: net < 0 ? AppColors.bad : AppColors.good,
            ),
            _row('الخزينة الآن', r.treasuryAfter, signed: false),
            _row('الدين الآن', r.debtAfter, signed: false),
            if (r.emergencyBorrowed > 0) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.bad, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'نفدت الخزينة فاقترضت الدولة ${formatMoney(r.emergencyBorrowed)} قرش بعمولة، وتأخرت رواتب الجند والموظفين.',
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ],
              ),
            ],
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'تغير المؤشرات',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in changes)
                    Pill(
                      text: '${c.key} ${formatSigned(c.value)}',
                      good: c.value > 0,
                      up: c.value > 0,
                    ),
                ],
              ),
            ],
            if (r.dueNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'آثار ظهرت الآن',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              for (final n in r.dueNotes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $n', style: const TextStyle(height: 1.5)),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(r.ending == null ? 'تابع' : 'النتيجة'),
        ),
      ],
    );
  }
}
