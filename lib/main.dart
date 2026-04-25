import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/services/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await Permission.storage.request().isGranted) {
    debugPrint('Разрешение на storage получено');
  }

  final audioService = AudioService();
  await audioService.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotRedSound',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}