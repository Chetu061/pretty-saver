import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/history.dart';
import 'l10n/strings.dart';
import 'state/providers.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.open();
  runApp(const ProviderScope(child: PrettySaverApp()));
}

class PrettySaverApp extends ConsumerWidget {
  const PrettySaverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Pretty Saver',
      debugShowCheckedModeBanner: false,
      locale: Locale(appearance.language),
      supportedLocales: [for (final code in S.languages.keys) Locale(code)],
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: appearance.themeMode,
      theme: buildTheme(Brightness.light, appearance.font),
      darkTheme: buildTheme(Brightness.dark, appearance.font),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(appearance.textScale)),
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
