import '../engine/calibrator.dart';
import '../engine/round_parser.dart';
import '../models/game_state.dart';
import '../models/round_plan.dart';
import 'ai_provider.dart';
import 'round_prompt.dart';

typedef AiCall = Future<String> Function(String prompt);

Future<void> _realWait(Duration d) => Future<void>.delayed(d);

/// يطلب من الذكاء الاصطناعي جولة، ويتحقق منها ويعايرها، ويعيد المحاولة عند الخطأ.
class RoundGenerator {
  RoundGenerator({
    required this.call,
    this.maxAttempts = 3,
    this.wait = _realWait,
    this.onAttempt,
  });

  final AiCall call;
  final int maxAttempts;
  final Future<void> Function(Duration) wait;

  /// للواجهة: رقم المحاولة والمشكلة التي أعيدت من أجلها (إن وجدت).
  final void Function(int attempt, String? problem)? onAttempt;

  Future<RoundPlan> generate(GameState s) async {
    String? problem;
    AiException? lastAi;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      onAttempt?.call(attempt, problem);
      final prompt = buildRoundPrompt(s, problem: problem);
      try {
        final text = await call(prompt);
        final raw = RoundParser.parse(text);
        return Calibrator.calibrate(raw, s);
      } on PlanFormatException catch (e) {
        problem = e.message;
        lastAi = null;
      } on AiException catch (e) {
        if (!e.retryable) rethrow;
        lastAi = e;
        if (attempt < maxAttempts) await wait(Duration(seconds: 3 * attempt));
      }
    }
    if (lastAi != null) throw lastAi;
    throw AiException(
      'كتب الذكاء الاصطناعي جولة غير صالحة $maxAttempts مرات ($problem). حاول مرة أخرى أو غيّر النموذج.',
    );
  }
}
