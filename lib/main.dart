import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/theme.dart';
import 'core/app_init.dart';
import 'core/update_checker.dart';
import 'features/typing_test/typing_test_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/achievements/trophy_case_screen.dart';
import 'features/touch_training/training_menu_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/settings_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInit.initialize();
  runApp(const ProviderScope(child: TypeMagicApp()));
}

/// Fade transition for route changes.
CustomTransitionPage<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _fadePage(const TypingTestScreen(), state),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) =>
              _fadePage(const StatsScreen(), state),
        ),
        GoRoute(
          path: '/trophies',
          pageBuilder: (context, state) =>
              _fadePage(const TrophyCaseScreen(), state),
        ),
        GoRoute(
          path: '/training',
          pageBuilder: (context, state) =>
              _fadePage(const TrainingMenuScreen(), state),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _fadePage(const SettingsScreen(), state),
        ),
      ],
    ),
  ],
);

class TypeMagicApp extends ConsumerWidget {
  const TypeMagicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(settingsProvider.select((s) => s.themeId));
    return MaterialApp.router(
      title: 'TypeMagic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeId),
      routerConfig: _router,
    );
  }
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final update = ref.watch(updateCheckProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _NavBar(currentPath: location),
          if (update case AsyncData(value: final info) when info.updateAvailable)
            _UpdateBanner(info: info),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateBanner({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.accent.withValues(alpha: 0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ny versjon tilgjengelig: v${info.latestVersion}',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.accent,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse(info.releaseUrl)),
              child: Text(
                'Last ned →',
                style: AppTheme.monoStyleSmall.copyWith(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final String currentPath;
  const _NavBar({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Logo / home link
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⌨️',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TypeMagic',
                    style: AppTheme.monoStyleSmall.copyWith(
                      color: currentPath == '/'
                          ? AppColors.accent
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Stats link
          _NavIcon(
            emoji: '📊',
            tooltip: 'Statistikk',
            active: currentPath == '/stats',
            onTap: () => context.go('/stats'),
          ),
          const SizedBox(width: 12),
          // Training link
          _NavIcon(
            emoji: '🖐️',
            tooltip: 'Tastaturtrening',
            active: currentPath == '/training',
            onTap: () => context.go('/training'),
          ),
          const SizedBox(width: 12),
          // Trophies link
          _NavIcon(
            emoji: '🏆',
            tooltip: 'Medaljer',
            active: currentPath == '/trophies',
            onTap: () => context.go('/trophies'),
          ),
          const SizedBox(width: 12),
          // Settings link
          _NavIcon(
            emoji: '⚙️',
            tooltip: 'Innstillinger',
            active: currentPath == '/settings',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final String emoji;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.emoji,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: 18,
                color: active ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
