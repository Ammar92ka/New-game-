import '../data/history_anchors.dart';
import '../engine/calibrator.dart';
import '../engine/game_engine.dart';
import '../models/budget.dart';
import '../models/game_state.dart';
import '../services/economy.dart';

String _n(num v) => v.round().toString();

String _lines(List<BudgetLine> lines, Budget b) =>
    lines.map((l) => '${l.key}=${_n(b.lineValue(l.key))}').join('، ');

/// يبني طلب الجولة. الذكاء الاصطناعي هو الكاتب الوحيد للأحداث والقرارات؛
/// اللعبة ترسل له الحالة والقواعد وتستقبل JSON تعايره بعد ذلك.
String buildRoundPrompt(GameState s, {String? problem}) {
  final revenue = s.budget.totalRevenue;
  final ratio = EconomyRules.debtRatio(s.debt, s.budget);
  final period = GameEngine.periodLabel(s.round);

  final history = s.history.length <= 24
      ? s.history
      : s.history.sublist(s.history.length - 24);
  final historyText = history.isEmpty
      ? 'لا توجد قرارات سابقة، وهذه بداية الحملة: ابدأ من الوضع الحقيقي مطلع 1800.'
      : history
            .map(
              (h) =>
                  '- ${GameEngine.periodLabel(h.round)} | ${h.category} | ${h.title}: ${h.choice}',
            )
            .join('\n');

  final pendingText = s.pending.isEmpty
      ? 'لا يوجد.'
      : s.pending
            .map(
              (p) =>
                  '- ${GameEngine.periodLabel(p.dueRound)}: ${p.source}',
            )
            .join('\n');

  final buf = StringBuffer()
    ..writeln(
      'أنت راوٍ ومحكّم تاريخي للعبة محاكاة الدولة العثمانية من 1800 إلى ${GameEngine.endYear}. اللاعب هو السلطان نفسه.',
    )
    ..writeln(
      'مهمتك كتابة جولة واحدة (نصف سنة) كاملة: ملخص الوضع، ثم ثلاثة قرارات (سياسة داخلية، اقتصاد ومالية، سياسة خارجية)، لكل قرار ثلاثة خيارات. أنت وحدك تكتب الأحداث والقرارات والخيارات.',
    )
    ..writeln()
    ..writeln('الفترة: $period (الجولة ${s.round + 1} من ${GameEngine.totalRounds}).')
    ..writeln()
    ..writeln('حالة الدولة (المبالغ بالقروش، 1 قرش = 40 بارة):')
    ..writeln(
      '- الخزينة: ${_n(s.treasury)}. الدين: ${_n(s.debt)} (${ratio.toStringAsFixed(2)} من الإيراد السنوي).',
    )
    ..writeln(
      '- المؤشرات من 100: الشرعية ${s.legitimacy}، الاستقرار ${s.stability}، الجيش ${s.army}، المكانة الدولية ${s.foreign}، التعليم والتحديث ${s.education}.',
    )
    ..writeln('- الإيراد السنوي: ${_n(revenue)} ← ${_lines(revenueLines, s.budget)}')
    ..writeln(
      '- النفقات السنوية: ${_n(s.budget.totalSpending)} ← ${_lines(spendingLines, s.budget)}',
    )
    ..writeln('- آثار مؤجلة قادمة:')
    ..writeln(pendingText)
    ..writeln('- تقرير نصف السنة الماضي: ${s.lastReport.isEmpty ? 'لا يوجد.' : s.lastReport}')
    ..writeln('- ذاكرة العالم (ملاحظات كتبتها أنت سابقا): ${s.chronicle.isEmpty ? 'لا يوجد.' : s.chronicle}')
    ..writeln()
    ..writeln('آخر قرارات اللاعب:')
    ..writeln(historyText)
    ..writeln()
    ..writeln('قواعد الواقعية:')
    ..writeln(
      '1. التزم بالتاريخ الحقيقي في خلفية الأحداث، ثم ابنِ التاريخ البديل على قرارات اللاعب ونتائجها فقط. لا تكرر ما فعله اللاعب كأنه لم يحدث.',
    )
    ..writeln(
      '2. لا مفارقات تاريخية: لا تذكر تقنية أو مؤسسة قبل ظهورها فعلا، إلا إن مهد لها اللاعب بقرارات منطقية وتأخرت بما يناسب زمنها.',
    )
    ..writeln(
      '3. للتنفيذ وقت وللقرارات ردود فعل: اذكر موقف الانكشارية والعلماء والأعيان والدول الكبرى والرعايا، ولا تجعل أثرا كبيرا يظهر فورا.',
    )
    ..writeln(
      '4. الخيارات الثلاثة مختلفة جوهريا، ولكل خيار ثمن وخطر، ولا يوجد خيار صحيح بوضوح.',
    )
    ..writeln(
      '5. briefing يلخص ما جرى منذ آخر جولة ويربطه بقرارات اللاعب وبالتقرير المالي، ثم يعرض الوضع الحالي.',
    )
    ..writeln(
      '6. حدود الأرقام (ما يتجاوزها تخفضه اللعبة تلقائيا): مصروف الخيار cost لا يزيد على ${_n(revenue * Calibrator.maxCostShare)}، والقرض loan لا يزيد على ${_n(revenue * Calibrator.maxLoanShare)}، وتغيير البند السنوي في line_changes بين ±${_n(revenue * Calibrator.maxLineShare)} (ثلاثة بنود كحد أقصى). التأثير الفوري now بين -${Calibrator.maxNow} و+${Calibrator.maxNow}، والمؤجل later بين -${Calibrator.maxLater} و+${Calibrator.maxLater}، وdelay من 0 إلى ${Calibrator.maxDelay} (أنصاف سنوات). مجموع المكاسب الموجبة في الخيار الواحد لا يتجاوز ${Calibrator.maxTotalGain}.',
    )
    ..writeln(
      '7. مفاتيح الميزانية المسموحة في line_changes: ${[...revenueLines, ...spendingLines].map((l) => '${l.key} (${l.label})').join('، ')}. الإيراد الجديد يظهر بعد تأخير لا يقل عن نصف سنة.',
    )
    ..writeln(
      '8. اكتب بالعربية الفصحى المبسطة بأسلوب مشوق وموجز: scene حتى 80 كلمة، dilemma حتى 40، text لكل خيار حتى 35، result حتى 45، reaction حتى 30، note (الأساس التاريخي) حتى 25، briefing حتى 120.',
    )
    ..writeln(
      '9. chronicle: ملاحظات ذاكرة محدثة بالعربية (حتى 200 كلمة): من يحكم ومن الحلفاء والأعداء، الحروب والإصلاحات الجارية، الوعود والالتزامات، وأي تطور تحتاج تذكره لاحقا. أعد كتابتها كاملة وليست إضافة فقط.',
    )
    ..writeln()
    ..writeln('مرجع التاريخ الحقيقي للمعايرة (قد ينحرف بسبب قرارات اللاعب):');
  for (final a in historyAnchors) {
    buf.writeln('- $a');
  }
  buf
    ..writeln()
    ..writeln(
      'الرد: كائن JSON واحد فقط، بلا أي نص خارجه ولا أسوار كود، بهذا الشكل بالضبط (ثلاثة قرارات بالفئات internal وeconomy وforeign، ولكل قرار ثلاثة خيارات):',
    )
    ..writeln(_schemaExample);
  if (problem != null && problem.trim().isNotEmpty) {
    buf
      ..writeln()
      ..writeln('تنبيه: ردك السابق رُفض لأن: $problem')
      ..writeln('أعد كتابة JSON كاملا وصحيحا.');
  }
  return buf.toString();
}

const String _schemaExample = '''{
  "headline": "عنوان الجولة",
  "briefing": "ملخص ما جرى والوضع الحالي",
  "chronicle": "ملاحظات الذاكرة المحدثة",
  "decisions": [
    {
      "category": "internal",
      "title": "عنوان القرار",
      "place": "المكان",
      "scene": "وصف المشهد",
      "dilemma": "المعضلة",
      "options": [
        {
          "text": "نص الخيار",
          "result": "ما سيجري إذا اخترته",
          "reaction": "ردود فعل القوى",
          "note": "الأساس التاريخي",
          "cost": 0,
          "loan": 0,
          "now": {"legitimacy": 0, "stability": 0, "army": 0, "foreign": 0, "education": 0},
          "later": {"legitimacy": 0, "stability": 0, "army": 0, "foreign": 0, "education": 0},
          "delay": 0,
          "line_changes": [{"line": "army", "delta": 0}]
        }
      ]
    }
  ]
}''';
