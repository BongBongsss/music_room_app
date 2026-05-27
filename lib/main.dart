import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/core/router.dart';
import 'package:music_room_app/core/theme.dart';
import 'package:music_room_app/firebase_options.dart';
import 'package:music_room_app/screens/common/auth_gate_error_screen.dart';
import 'package:music_room_app/screens/common/auth_gate_screen.dart';
import 'package:music_room_app/services/auth_service.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '음악연습실 관리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authStateProvider);
            return authState.when(
              loading: () => const AuthGateScreen(),
              data: (_) => child ?? const SizedBox.shrink(),
              error: (err, stack) => AuthGateErrorScreen(
                error: err,
                onRetry: () => ref.invalidate(authStateProvider),
                onLogin: () => context.go('/login'),
              ),
            );
          },
        );
      },
    );
  }
}
