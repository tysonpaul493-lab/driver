import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // After 2.4 seconds, smoothly proceed to Login Page
    _navTimer = Timer(const Duration(milliseconds: 2400), _navigateToLogin);
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
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
    _animController.dispose();
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Trust Official Logo Emblem
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 130,
                      height: 130,
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
                          width: 130,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App Title & Tagline with Fade Animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'ஆல் இந்தியா தமிழ் அனைத்து அறக்கட்டளை',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'தமிழ்நாடு அவசர ஊர்தி ஓட்டுநர் கன்சோல்',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.ambulanceTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Loading pulse
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ambulanceTeal),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                ],
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
