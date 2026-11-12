import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/round_plan.dart';
import '../services/ai_client.dart';
import '../services/ai_provider.dart';
import '../services/economy.dart';
import '../services/round_generator.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../widgets/budget_panel.dart';
import '../widgets/option_tile.dart';
import '../widgets/report_dialog.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/stat_card.dart';
import 'end_screen.dart';

/// شاشة الجولة: الذكاء الاصطناعي يكتب الوضع والقرارات الثلاثة،
/// واللعبة تعرضها وتحفظها وتنفذ اختيارات اللاعب بقواعد ثابتة.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.initial});

  final GameState initial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = GameEngine();
  final SaveService _save = SaveService();
  late GameState _state;

  bool _loading = false;
  bool _resolving = false;
  String? _error;
  int _attempt = 1;
  String? _problem;

  static const List<String> _letters = ['أ', 'ب', 'ج'];

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    _loading = _state.plan == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePlan());
  }

  /// يطلب من الذكاء الاصطناعي جولة جديدة إن لم تكن هناك جولة محفوظة.
  Future<void> _ensurePlan() async {
    if (_state.plan != null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _attempt = 1;
      _problem = null;
    });
    final settings = await SettingsService().load();
    if (!mounted) return;
    if (!settings.hasKey) {
      setState(() {
        _loading = false;
        _error = 'أضف مفتاح الذكاء الاصطناعي من الإعدادات حتى تُكتب الجولة.';
      });
      return;
    }
    try {
      final client = AiClient.fromSettings(settings);
      final generator = RoundGenerator(
        call: client.generateJson,
        onAttempt: (attempt, problem) {
          if (!mounted) return;
          setState(() {
            _attempt = attempt;
            _problem = problem;
          });
        },
      );
      final plan = await generator.generate(_state);
      if (!mounted) return;
      _state.plan = plan;
      _state.picks = <int?>[null, null, null];
      if (plan.chronicle.isNotEmpty) _state.chronicle = plan.chronicle;
      await _save.saveState(_state);
      if (!mounted) return;
      setState(() => _loading = false);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      });
    }
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

  Future<void> _pick(int decisionIndex, int optionIndex) async {
    setState(() => _state.picks[decisionIndex] = optionIndex);
    await _save.saveState(_state);
  }

  Future<void> _resolve() async {
    if (_resolving || !_state.hasAllPicks) return;
    setState(() => _resolving = true);
    final report = _engine.resolveRound(_state);
    if (report.ending != null) {
      await _save.clear();
    } else {
      await _save.saveState(_state);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportDialog(report: report),
    );
    if (!mounted) return;
    final ending = report.ending;
    if (ending != null) {
      final restart = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => EndScreen(ending: ending, state: _state),
        ),
      );
      if (!mounted) return;
      if (restart == true) {
        _state = GameState();
        await _save.clear();
        if (!mounted) return;
        setState(() => _resolving = false);
        await _ensurePlan();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {
      _resolving = false;
      _loading = true;
    });
    await _ensurePlan();
  }

  Widget _statGrid() {
    final s = _state;
    final ratio = EconomyRules.debtRatio(s.debt, s.budget);
    final cards = <Widget>[
      StatCard(
        icon: Icons.account_balance_wallet,
        label: 'الخزينة',
        value: '${formatMoney(s.treasury)} قرش',
        warn: s.treasury < s.budget.totalSpending / 8,
      ),
      StatCard(
        icon: Icons.trending_down,
        label: 'الدين',
        value: '${formatMoney(s.debt)} قرش',
        hint: '${ratio.toStringAsFixed(1)} من الإيراد السنوي',
        warn: ratio >= 3,
      ),
      StatCard(
        icon: Icons.workspace_premium,
        label: 'الشرعية',
        value: '${s.legitimacy} / 100',
        progress: s.legitimacy / 100,
        warn: s.legitimacy <= 25,
      ),
      StatCard(
        icon: Icons.balance,
        label: 'الاستقرار',
        value: '${s.stability} / 100',
        progress: s.stability / 100,
        warn: s.stability <= 22,
      ),
      StatCard(
        icon: Icons.shield,
        label: 'الجيش',
        value: '${s.army} / 100',
        progress: s.army / 100,
        warn: s.army <= 15,
      ),
      StatCard(
        icon: Icons.public,
        label: 'المكانة الدولية',
        value: '${s.foreign} / 100',
        progress: s.foreign / 100,
        warn: s.foreign <= 20,
      ),
      StatCard(
        icon: Icons.school,
        label: 'التعليم والتحديث',
        value: '${s.education} / 100',
        progress: s.education / 100,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }

  IconData _categoryIcon(DecisionCategory c) {
    switch (c) {
      case DecisionCategory.internal:
        return Icons.account_balance;
      case DecisionCategory.economy:
        return Icons.payments_outlined;
      case DecisionCategory.foreign:
        return Icons.public;
    }
  }

  Widget _decisionSection(int i, Decision d) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(d.category), size: 18, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                d.category.label,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_state.picks[i] != null)
                const Icon(Icons.check_circle, size: 18, color: AppColors.good),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (d.place.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                d.place,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 10),
          Text(d.scene, style: const TextStyle(height: 1.8, fontSize: 15.5)),
          const SizedBox(height: 10),
          Text(
            d.dilemma,
            style: const TextStyle(
              height: 1.7,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var k = 0; k < d.options.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OptionTile(
                letter: _letters[k],
                option: d.options[k],
                selected: _state.picks[i] == k,
                onTap: () => _pick(i, k),
              ),
            ),
        ],
      ),
    );
  }

  Widget _confirmBar(RoundPlan plan) {
    var cost = 0.0;
    var loan = 0.0;
    for (var i = 0; i < 3; i++) {
      final p = _state.picks[i];
      if (p != null) {
        cost += plan.decisions[i].options[p].cost;
        loan += plan.decisions[i].options[p].loan;
      }
    }
    final chosen = _state.picks.where((p) => p != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Text(
            chosen < 3
                ? 'اخترت $chosen من 3 قرارات.'
                : 'المصروفات الفورية: ${formatMoney(cost)} قرش'
                      '${loan > 0 ? '، القروض: ${formatMoney(loan)} قرش' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        FilledButton.icon(
          onPressed: _state.hasAllPicks && !_resolving ? _resolve : null,
          icon: const Icon(Icons.gavel),
          label: const Text('نفّذ قرارات هذه الجولة'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ],
    );
  }

  Widget _history() {
    final h = _state.history;
    if (h.isEmpty) return const SizedBox.shrink();
    final recent = h.reversed.take(30).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('سجل القرارات (${h.length})'),
          children: [
            for (final e in recent)
              ListTile(
                dense: true,
                title: Text(e.choice),
                subtitle: Text(
                  '${GameEngine.periodLabel(e.round)} - ${e.category}: ${e.title}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'الديوان يُعدّ تقارير ${GameEngine.periodLabel(_state.round)}...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'الذكاء الاصطناعي يكتب الأحداث والقرارات. قد يستغرق هذا نصف دقيقة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
            if (_attempt > 1) ...[
              const SizedBox(height: 12),
              Text(
                _problem == null
                    ? 'محاولة $_attempt من 3 (الخدمة مشغولة)'
                    : 'محاولة $_attempt من 3 (كان الرد السابق غير صالح)',
                style: const TextStyle(color: AppColors.gold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.bad),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _ensurePlan,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await _openSettings();
                if (!mounted) return;
                await _ensurePlan();
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('إعدادات الذكاء الاصطناعي'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundView(RoundPlan plan) {
    final total = GameEngine.totalRounds;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'الجولة ${_state.round + 1} من $total',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_state.round / total).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            color: AppColors.gold,
            backgroundColor: AppColors.cardBorder,
          ),
        ),
        const SizedBox(height: 14),
        _statGrid(),
        const SizedBox(height: 12),
        BudgetPanel(state: _state),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plan.headline.isNotEmpty)
                Text(
                  plan.headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              if (plan.headline.isNotEmpty) const SizedBox(height: 8),
              Text(
                plan.briefing,
                style: const TextStyle(height: 1.8, fontSize: 15.5),
              ),
            ],
          ),
        ),
        for (var i = 0; i < plan.decisions.length; i++)
          _decisionSection(i, plan.decisions[i]),
        _confirmBar(plan),
        _history(),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _state.plan;
    Widget body;
    if (_loading || (_resolving && plan == null)) {
      body = _loadingView();
    } else if (_error != null || plan == null) {
      body = _errorView();
    } else {
      body = _roundView(plan);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(GameEngine.periodLabel(_state.round)),
        actions: [
          IconButton(
            tooltip: 'الذكاء الاصطناعي',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
