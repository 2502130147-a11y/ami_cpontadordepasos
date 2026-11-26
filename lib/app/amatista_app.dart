import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/logic/auth_store.dart';
import '../features/auth/ui/bio_enroll_page.dart';
import '../features/auth/ui/unlock_page.dart';
import '../features/auth/ui/welcome_page.dart';
import '../features/history/logic/history_store.dart';
import '../features/shell/home_shell.dart';
import 'theme/amatista_theme.dart';
import '../shared/widgets/anime_sparkles.dart';
import 'theme/palette.dart';

class AmatistaApp extends StatelessWidget {
  const AmatistaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStore()..init()),
        ChangeNotifierProvider(create: (_) => HistoryStore()..load()),
      ],
      child: MaterialApp(
        title: 'Amatista',
        debugShowCheckedModeBanner: false,
        theme: buildAmatistaTheme(),
        home: const _RootGate(),
      ),
    );
  }
}

/// Decide qué pantalla se ve según el estado de la sesión.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthStore, AuthStatus>((s) => s.status);
    final Widget page = switch (status) {
      AuthStatus.loading => const _Splash(),
      AuthStatus.noAccount => const WelcomePage(),
      AuthStatus.enrolling => const BioEnrollPage(),
      AuthStatus.locked => const UnlockPage(),
      AuthStatus.unlocked => const HomeShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(status), child: page),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: Palette.night),
        child: Stack(
          children: [
            Positioned.fill(child: AnimeSparkles(count: 22)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotAvatar(size: 170, ring: false),
                  SizedBox(height: 14),
                  Text(
                    'Amatista',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 26),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Palette.lilac),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
