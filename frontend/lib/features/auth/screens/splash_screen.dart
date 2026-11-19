import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    // Smooth, prompt transition to Login Page without bouncy animation delays
    _navTimer = Timer(const Duration(milliseconds: 1200), _navigateToLogin);
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGatekeeper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: InkWell(
        onTap: _navigateToLogin, // Allow tapping to skip splash instantly
        child: Stack(
          children: [
            // Ambient background glow
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ambulanceTeal.withValues(alpha: 0.06),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Official Trust Logo Emblem - Clean Static Display (Zero Animation / Zero LifeRoute Old Badges)
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ambulanceTeal, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ambulanceTeal.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // App Title & Tagline with Proper Padding & Gap
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'ஆல் இந்தியா தமிழ் அனைத்து அறக்கட்டளை',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'தமிழ்நாடு அவசர ஊர்தி ஓட்டுநர் கன்சோல்',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ambulanceTeal,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Dispatch network status spinner
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ambulanceTeal),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Initializing Dispatch Grid...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Version badge
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v1.0.0 • Emergency Response Unit',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
