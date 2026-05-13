import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/styles/project_styles.dart';
import '../launch/launch_screen.dart';

class OnboardingStorage {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notred_onboarding_seen.json');
  }

  static Future<bool> hasSeenOnboarding() async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['seen'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'seen': true}));
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final String hint;
  final Color color;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.hint,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  final bool openLaunchAfterFinish;

  const OnboardingScreen({
    super.key,
    this.openLaunchAfterFinish = true,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  late final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.music_note_rounded,
      title: 'Что такое NotRedSound',
      description:
          'Это мобильная музыкальная студия для создания треков прямо на телефоне: придумывай мелодии, пропевай их и наслаждайся своим произведением',
      hint: '"Готовить может каждый!" – повар Огюст Гюсто из м/ф "Рататуй"',
      color: const Color.fromARGB(255, 249, 230, 58),
    ),
    _OnboardingPageData(
      icon: Icons.layers_rounded,
      title: 'Выбирай стиль',
      description:
          'Классический, Электро, Рок и Свой — это 4 отдельные версии проекта со своим оформлением и набором инструментов',
      hint: 'Стиль можно менять в настройках проекта нажатием на надпись “Проект”',
      color: ProjectStyles.standard.primaryColor,
    ),
    _OnboardingPageData(
      icon: Icons.library_music_rounded,
      title: 'Добавляй дорожки',
      description:
          'Создавай и удаляй дорожки, переименовывай их, меняй громкость, активность и инструмент',
      hint: 'У Рока и Электро уже есть стартовые подписанные дорожки, а у Классики ещё и готовая композиция',
      color: ProjectStyles.rock.primaryColor,
    ),
    _OnboardingPageData(
      icon: Icons.piano_rounded,
      title: 'Открывай редактор нот',
      description:
          'Нажимай на предпоказ нот дорожки в нужном такте и открывай редактор нот. Там можно записывать ноты голосом и затем редактировать их',
      hint: 'Жёлтая лента и тактовая шкала помогут быстро ориентироваться',
      color: ProjectStyles.electro.primaryColor,
    ),
    _OnboardingPageData(
      icon: Icons.play_circle_fill_rounded,
      title: 'Запускай и экспортируй',
      description:
          'Наслаждайся полученным шедевром и делись своим искусством с друзьями',
      hint: 'Можно экспортировать трек в формате MIDI для доработки в профессиональной компьютерной программе',
      color: ProjectStyles.classic.primaryColor,
    ),
  ];

  Future<void> _finish() async {
    await OnboardingStorage.markSeen();
    if (!mounted) return;

    if (widget.openLaunchAfterFinish) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LaunchScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_pageIndex >= _pages.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_pageIndex];

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
            color: Colors.black.withValues(alpha: 0.80),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          widget.openLaunchAfterFinish
                              ? 'Пропустить'
                              : 'Закрыть',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_pageIndex + 1}/${_pages.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (value) {
                        setState(() {
                          _pageIndex = value;
                        });
                      },
                      itemBuilder: (context, index) {
                        final page = _pages[index];

                        return Center(
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 520),
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                            decoration: BoxDecoration(
                              color: page.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: page.color.withValues(alpha: 0.90),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 28,
                                  color: page.color.withValues(alpha: 0.20),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 18),
                                Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: page.color.withValues(alpha: 0.18),
                                    border: Border.all(
                                      color: page.color.withValues(alpha: 0.90),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    page.icon,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  page.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    page.hint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: page.color,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) {
                        final active = index == _pageIndex;
                        final dotColor = _pages[index].color;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? dotColor
                                : Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: page.color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _pageIndex == _pages.length - 1
                            ? (widget.openLaunchAfterFinish
                                ? 'На экран выбора'
                                : 'Готово')
                            : 'Далее',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppEntryScreen extends StatelessWidget {
  const AppEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingStorage.hasSeenOnboarding(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final seen = snapshot.data ?? false;
        if (seen) {
          return const LaunchScreen();
        }

        return const OnboardingScreen(
          openLaunchAfterFinish: true,
        );
      },
    );
  }
}
