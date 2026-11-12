import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/start_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const OttomanApp());

class OttomanApp extends StatelessWidget {
  const OttomanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الدولة العثمانية 1800',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // اللغة العربية مع اتجاه من اليمين إلى اليسار لكل التطبيق
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const StartScreen(),
    );
  }
}
