import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../ui/theme.dart';
import '../widgets/settings_sheet.dart';
import 'game_screen.dart';

/// الشاشة الأولى: متابعة لعبة محفوظة أو بدء لعبة جديدة.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final SaveService _save = SaveService();
  GameState? _saved;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var s = await _save.loadState();
    // حفظ لحملة منتهية: نتجاهله
    if (s != null && s.round >= GameEngine.totalRounds) {
      await _save.clear();
      s = null;
    }
    if (!mounted) return;
    setState(() {
      _saved = s;
      _loading = false;
    });
  }

  Future<void> _open(GameState state) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => GameScreen(initial: state)));
    if (!mounted) return;
    await _load();
  }

  Future<void> _newGame() async {
    if (_saved != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('لعبة جديدة؟'),
          content: const Text('سيتم حذف اللعبة المحفوظة والبدء من جديد.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ابدأ من جديد'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final settings = await SettingsService().load();
    if (!mounted) return;
    if (!settings.hasKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف مفتاح الذكاء الاصطناعي أولا، فهو من يكتب أحداث اللعبة.'),
        ),
      );
      await _openSettings();
      return;
    }
    await _save.clear();
    if (!mounted) return;
    await _open(GameState());
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كيف تلعب؟'),
        content: SingleChildScrollView(
          child: Text(
            '• أنت السلطان. تبدأ في كانون الثاني 1800 وتحكم حتى نهاية ${GameEngine.endYear}، في جولات كل واحدة نصف سنة.\n\n'
            '• في كل جولة يكتب الذكاء الاصطناعي الوضع الراهن وثلاثة قرارات: داخلي واقتصادي وخارجي، ولكل قرار ثلاثة خيارات. لا شيء من الأحداث مكتوب سلفا في اللعبة.\n\n'
            '• اللعبة تعاير أرقام الذكاء الاصطناعي بحجم ميزانية الدولة، وتحسب الإيراد والنفقات والفوائد بالقروش، وتؤجل الآثار الكبرى كما يحدث في الواقع.\n\n'
            '• تخسر إذا نزلت الشرعية إلى 15 أو الاستقرار إلى 12، أو بلغ الدين ست أمثال الإيراد السنوي، أو انهارت قوة الجيش والمكانة الدولية معا.\n\n'
            '• اللعبة تحفظ نفسها بعد كل اختيار، بما فيها الجولة التي كتبها الذكاء الاصطناعي.',
            style: const TextStyle(height: 1.7),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final current = await SettingsService().load();
    if (!mounted) return;
    await showModalBottomSheet<AiSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      builder: (_) => AiSettingsSheet(initial: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدولة العثمانية 1800'),
        actions: [
          IconButton(
            tooltip: 'الذكاء الاصطناعي',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance,
                    size: 72,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'السلطان',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'من 1800 إلى ${GameEngine.endYear}. ثلاثة قرارات كل نصف سنة، يكتبها الذكاء الاصطناعي وتحسب اللعبة نتائجها.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      height: 1.7,
                      fontSize: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (saved != null) ...[
                      FilledButton.icon(
                        onPressed: () => _open(saved),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          'متابعة - ${GameEngine.periodLabel(saved.round)}',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _newGame,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('لعبة جديدة'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: _newGame,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('ابدأ اللعبة'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showHelp,
                      icon: const Icon(Icons.help_outline),
                      label: const Text('كيف تلعب؟'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
