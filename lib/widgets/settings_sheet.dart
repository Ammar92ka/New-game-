import 'package:flutter/material.dart';

import '../services/ai_client.dart';
import '../services/ai_provider.dart';
import '../services/settings_service.dart';
import '../ui/theme.dart';

/// ورقة إعدادات الذكاء الاصطناعي: اختيار المزود والمفتاح والنموذج واختبار الاتصال.
/// ترجع الإعدادات المحفوظة، أو null إذا أغلقها المستخدم بدون حفظ.
class AiSettingsSheet extends StatefulWidget {
  const AiSettingsSheet({super.key, required this.initial});

  final AiSettings initial;

  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  late String _provider;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  bool _showKey = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.initial.provider;
    _keyCtrl = TextEditingController(text: widget.initial.apiKey);
    _modelCtrl = TextEditingController(text: widget.initial.model);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  AiSettings _current() => AiSettings(
    provider: _provider,
    apiKey: _keyCtrl.text.trim(),
    model: _modelCtrl.text.trim(),
  );

  Future<void> _test() async {
    final s = _current();
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      await AiClient.fromSettings(s).generateText('أجب بكلمة واحدة فقط: جاهز');
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testMessage = 'الاتصال ناجح.';
        _testing = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = e.message;
        _testing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = 'فشل الاختبار لسبب غير متوقع.';
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    final s = _current();
    await SettingsService().save(s);
    if (!mounted) return;
    Navigator.pop(context, s);
  }

  Future<void> _clearKey() async {
    _keyCtrl.clear();
    final s = _current();
    await SettingsService().save(s);
    if (!mounted) return;
    setState(() {
      _testMessage = 'تم مسح المفتاح من هذا الجهاز.';
      _testOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = aiProviderById(_provider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الذكاء الاصطناعي (مطلوب للعب)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'الذكاء الاصطناعي هو من يكتب أحداث اللعبة وقراراتها وخياراتها في كل جولة، واللعبة تعاير أرقامه وتحسب الميزانية والنتائج. مفتاحك يحفظ على هذا الجهاز فقط ولا يرسل إلا للمزود الذي تختاره.',
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                for (final p in aiProviders)
                  ButtonSegment<String>(value: p.id, label: Text(p.name)),
              ],
              selected: {_provider},
              onSelectionChanged: (set) {
                setState(() {
                  _provider = set.first;
                  _modelCtrl.clear();
                  _testMessage = null;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _keyCtrl,
              onChanged: (_) => setState(() {}),
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'مفتاح API',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showKey ? 'إخفاء المفتاح' : 'إظهار المفتاح',
                  icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'اسم النموذج (اتركه فارغا للافتراضي)',
                hintText: provider.defaultModel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testOk ? Icons.check_circle_outline : Icons.error_outline,
                    size: 18,
                    color: _testOk ? AppColors.good : AppColors.bad,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _testMessage!,
                      style: TextStyle(
                        color: _testOk ? AppColors.good : AppColors.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _testing ? null : _save,
                  child: const Text('حفظ'),
                ),
                OutlinedButton(
                  onPressed: (_testing || _keyCtrl.text.trim().isEmpty)
                      ? null
                      : _test,
                  child: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('اختبار الاتصال'),
                ),
                TextButton(
                  onPressed: _testing ? null : _clearKey,
                  child: const Text('مسح المفتاح'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
