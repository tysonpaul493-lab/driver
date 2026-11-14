import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/api_constants.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_theme.dart';
import 'core/network/dio_client.dart';
import 'core/services/driver_notification_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/phone_login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/dashboard/screens/driver_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DriverNotificationService.instance.initialize();

  final storage = SecureStorageService();
  await storage.init();
  final savedServerHost = await storage.getCustomApiUrl();
  ApiConstants.setServerHost(savedServerHost);
  if (!ApiConstants.hasCustomServerHost) {
    try {
      await DioClient.resolveReachableHost().timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const LifeRouteDriverApp(),
    ),
  );
}

class LifeRouteDriverApp extends ConsumerStatefulWidget {
  const LifeRouteDriverApp({super.key});

  @override
  ConsumerState<LifeRouteDriverApp> createState() => _LifeRouteDriverAppState();
}

class _LifeRouteDriverAppState extends ConsumerState<LifeRouteDriverApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeRoute Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.daylightTheme,
      home: const SplashScreen(),
    );
  }
}

/// Dynamic routing based on Sanctum authentication and driver verification status
class AuthGatekeeper extends ConsumerWidget {
  const AuthGatekeeper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    switch (authState.status) {
      case AuthStatus.loading:
      case AuthStatus.initial:
        return const Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_hospital_rounded,
                  color: AppColors.ambulanceTeal,
                  size: 56,
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.ambulanceTeal),
                ),
                SizedBox(height: 16),
                Text(
                  'Connecting to Dispatch Network...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );

      case AuthStatus.authenticated:
      case AuthStatus.verificationPending:
        return const DriverDashboardScreen();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const PhoneLoginScreen();
    }
  }
}
