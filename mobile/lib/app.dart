import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/onboarding/presentation/pairing_screen.dart';
import 'features/alerts/presentation/critical_alert_screen.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/pairing',
      builder: (context, state) => const PairingScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/alert',
      builder: (context, state) => const CriticalAlertScreen(),
    ),
  ],
);

class SmartGasApp extends StatelessWidget {
  const SmartGasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartGas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
