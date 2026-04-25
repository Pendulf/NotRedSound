import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../onboarding/onboarding_screen.dart';
import '../../core/navigation/fade_page_route.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;

  late final Animation<double> _backgroundOpacity;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _frameOpacity;
  late final Animation<double> _frameScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleOffset;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _backgroundOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
    );

    _iconOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
    );

    _iconScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutBack),
      ),
    );

    _frameOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
    );

    _frameScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutBack),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.333, 0.55, curve: Curves.easeOut),
    );

    _titleOffset = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.333, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();

    _navigationTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
  FadePageRoute(
    child: const AppEntryScreen(),
    duration: const Duration(milliseconds: 800),
  ),
);
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _pulseController]),
      builder: (context, child) {
        final pulse = 0.5 + (_pulseController.value * 0.5);
        final glowScale = 1.0 + (pulse * 0.05);
        final glowOpacity = 0.18 + (pulse * 0.16);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildAnimatedBackground(pulse),
              Opacity(
                opacity: _backgroundOpacity.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.38),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = constraints.maxHeight;
                    final screenWidth = constraints.maxWidth;

                    final iconSize = math.min(
                      screenWidth * 0.66,
                      screenHeight * 0.42,
                    );

                    final frameSize = iconSize + 26;

                    return Column(
                      children: [
                        SizedBox(height: screenHeight * 0.05),
                        SizedBox(
                          height: screenHeight * 0.50,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: glowScale,
                                  child: Opacity(
                                    opacity: glowOpacity * _iconOpacity.value,
                                    child: Container(
                                      width: frameSize + 34,
                                      height: frameSize + 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.16,
                                            ),
                                            blurRadius: 30,
                                            spreadRadius: 6,
                                          ),
                                          BoxShadow(
                                            color: Colors.purple.withValues(
                                              alpha: 0.24,
                                            ),
                                            blurRadius: 46,
                                            spreadRadius: 12,
                                          ),
                                          BoxShadow(
                                            color: Colors.blue.withValues(
                                              alpha: 0.20,
                                            ),
                                            blurRadius: 56,
                                            spreadRadius: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                Transform.scale(
                                  scale: _frameScale.value,
                                  child: Opacity(
                                    opacity: _frameOpacity.value,
                                    child: Container(
                                      width: frameSize,
                                      height: frameSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withValues(
                                              alpha: 0.18,
                                            ),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.blue.withValues(
                                              alpha: 0.14,
                                            ),
                                            blurRadius: 30,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                Transform.translate(
                                  offset: Offset(
                                    0,
                                    math.sin(_pulseController.value * math.pi * 2) *
                                        4,
                                  ),
                                  child: Transform.scale(
                                    scale: _iconScale.value,
                                    child: Opacity(
                                      opacity: _iconOpacity.value,
                                      child: SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(iconSize * 0.22),
                                          child: Image.asset(
                                            'assets/splash_icon.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleOffset.value),
                            child: _buildTitle(),
                          ),
                        ),

                        const Spacer(),

                      
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBackground(double pulse) {
    final shiftA = math.sin(_pulseController.value * math.pi * 2) * 18;
    final shiftB = math.cos(_pulseController.value * math.pi * 2) * 22;

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: _backgroundOpacity.value,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.25),
                radius: 1.15,
                colors: [
                  Color(0xFF221036),
                  Color(0xFF11081D),
                  Color(0xFF050507),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 60 + shiftA,
          left: -40,
          child: _buildGlowBlob(
            size: 220,
            colors: [
              Colors.red.withValues(alpha: 0.18),
              Colors.purple.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),

        Positioned(
          top: 120 - shiftB,
          right: -30,
          child: _buildGlowBlob(
            size: 260,
            colors: [
              Colors.blue.withValues(alpha: 0.18),
              Colors.cyan.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),

        Positioned(
          bottom: 60 + (shiftB * 0.5),
          left: 20,
          child: _buildGlowBlob(
            size: 180,
            colors: [
              Colors.purple.withValues(alpha: 0.15),
              Colors.pink.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlowBlob({
    required double size,
    required List<Color> colors,
  }) {
    return Opacity(
      opacity: _backgroundOpacity.value,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppConstants.brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'NotRedSound',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Твори. Записывай. Чувствуй',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}