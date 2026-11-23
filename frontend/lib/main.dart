import 'package:flutter/foundation.dart' show kIsWeb;
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
  if (savedServerHost != null && savedServerHost.isNotEmpty) {
    if (savedServerHost.contains('trycloudflare.com') ||
        savedServerHost.contains('ngrok') ||
        savedServerHost.contains('jessica-western') ||
        savedServerHost.contains('bottle-equilibrium')) {
      await storage.setCustomApiUrl(null);
    } else {
      ApiConstants.setServerHost(savedServerHost);
    }
  }
  if (!ApiConstants.hasCustomServerHost && kIsWeb) {
    try {
      final webHost = Uri.base.host.trim();
      if (webHost.isNotEmpty && (webHost == 'localhost' || webHost == '127.0.0.1' || webHost.startsWith('192.168.'))) {
        ApiConstants.setRuntimeFallbackHost(webHost);
      }
    } catch (_) {}
  }

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
      child: const A2IDriverApp(),
    ),
  );
}

class A2IDriverApp extends ConsumerStatefulWidget {
  const A2IDriverApp({super.key});

  @override
  ConsumerState<A2IDriverApp> createState() => _A2IDriverAppState();
}

class _A2IDriverAppState extends ConsumerState<A2IDriverApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2I',
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
        return Scaffold(
          backgroundColor: AppColors.primaryDark,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ambulanceTeal, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ambulanceTeal.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.ambulanceTeal),
                ),
                const SizedBox(height: 16),
                const Text(
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
