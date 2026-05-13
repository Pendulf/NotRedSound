import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/navigation/fade_page_route.dart';
import '../../core/styles/project_style.dart';
import '../../core/styles/project_styles.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  void _openHome(
    BuildContext context, {
    required ProjectStyleType styleType,
    required bool loadSavedProject,
  }) {
    AppConstants.applyProjectStyle(styleType);

    Navigator.of(context).pushReplacement(
      FadePageRoute(
        duration: const Duration(milliseconds: 700),
        child: HomeScreen(
          initialStyleType: styleType,
          loadSavedProject: loadSavedProject,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = [
      (
        label: 'Классическая версия',
        subtitle: 'Пианино, струнные, духовые',
        styleType: ProjectStyleType.classic,
        loadSavedProject: true,
        color: ProjectStyles.classic.primaryColor,
      ),
      (
        label: 'Электро версия',
        subtitle: 'Синты, FX, электро-клавиши',
        styleType: ProjectStyleType.electro,
        loadSavedProject: true,
        color: ProjectStyles.electro.primaryColor,
      ),
      (
        label: 'Рок версия',
        subtitle: 'Гитары, бас, рок-орган, ударные',
        styleType: ProjectStyleType.rock,
        loadSavedProject: true,
        color: ProjectStyles.rock.primaryColor,
      ),
      
      
      (
        label: 'Своя версия',
        subtitle: 'Полный режим',
        styleType: ProjectStyleType.standard,
        loadSavedProject: true,
        color: ProjectStyles.standard.primaryColor,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppConstants.currentStyle.backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.82),
                  Colors.black.withValues(alpha: 0.90),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleSize =
                    (constraints.maxWidth * 0.11).clamp(32.0, 42.0).toDouble();
                final compactHeight = constraints.maxHeight < 620;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 360 ? 16 : 24,
                    vertical: compactHeight ? 18 : 28,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OnboardingScreen(
                                    openLaunchAfterFinish: false,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.help_outline_rounded),
                            label: const Text('Как это работает'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 6 : 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'NotRedSound',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: AppConstants.brandGradient,
                                ).createShader(
                                  const Rect.fromLTWH(0, 0, 260, 60),
                                ),
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 10 : 14),
                        Text(
                          'Выберите, с какой версии проекта начать',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: constraints.maxWidth < 360 ? 14 : 16,
                          ),
                        ),
                        SizedBox(height: compactHeight ? 24 : 40),
                        ...styles.map(
                          (item) => Padding(
                            padding: EdgeInsets.only(
                              bottom: compactHeight ? 12 : 16,
                            ),
                            child: _LaunchButton(
                              title: item.label,
                              subtitle: item.subtitle,
                              color: item.color,
                              compact: compactHeight,
                              onTap: () => _openHome(
                                context,
                                styleType: item.styleType,
                                loadSavedProject: item.loadSavedProject,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 10 : 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  const _LaunchButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 360 ? 16 : 20,
            vertical: compact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                color: color.withValues(alpha: 0.16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth < 360 ? 19 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: screenWidth < 360 ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
