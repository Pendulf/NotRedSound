
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/project_style.dart';
import '../../core/project_styles.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../core/navigation/fade_page_route.dart';

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
        label: 'Полная версия',
        subtitle: 'Полный режим ',
        styleType: ProjectStyleType.standard,
        loadSavedProject: true,
        color: ProjectStyles.standard.primaryColor,
      ),
      (
        label: 'Рок версия',
        subtitle: 'Гитары, бас, рок-орган, ударные',
        styleType: ProjectStyleType.rock,
        loadSavedProject: true,
        color: ProjectStyles.rock.primaryColor,
      ),
      (
        label: 'Электро версия',
        subtitle: 'Синты, FX, электро-клавиши',
        styleType: ProjectStyleType.electro,
        loadSavedProject: true,
        color: ProjectStyles.electro.primaryColor,
      ),
      (
        label: 'Классическая версия',
        subtitle: 'Пианино, струнные, духовые',
        styleType: ProjectStyleType.classic,
        loadSavedProject: true,
        color: ProjectStyles.classic.primaryColor,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                        foregroundColor: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12,),
                  Text(
                    'NotRedSound',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: AppConstants.brandGradient,
                        ).createShader(const Rect.fromLTWH(0, 0, 260, 60)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Выберите, с какой версии проекта начать',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  ...styles.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LaunchButton(
                        title: item.label,
                        subtitle: item.subtitle,
                        color: item.color,
                        onTap: () => _openHome(
                          context,
                          styleType: item.styleType,
                          loadSavedProject: item.loadSavedProject,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
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
  final VoidCallback onTap;

  const _LaunchButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
