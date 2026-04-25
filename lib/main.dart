import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/services/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());

  unawaited(_warmUpAppServices());
}

Future<void> _warmUpAppServices() async {
  try {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      debugPrint('Storage permission: $storageStatus');
    }

    await AudioService().ensureInitialized();
  } catch (e) {
    debugPrint('Startup warm-up error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _audioService.handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        unawaited(_audioService.handleAppResumed());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioService.handleAppPaused();
    super.dispose();
  }

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
