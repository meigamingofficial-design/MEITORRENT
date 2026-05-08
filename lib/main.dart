import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/foreground_service_manager.dart';
import 'core/services/notification_service.dart';
import 'core/services/shared_preferences_provider.dart';

/// App entry point.
///
/// Initialises:
/// 1. Flutter bindings
/// 2. Deep link service (captures cold-start magnet before runApp)
/// 3. Foreground task communication port
/// 4. System UI overlay style
@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task before runApp
  ForegroundServiceManager.initCommunicationPort();
  await NotificationService.instance.initialize();

  // Load SharedPreferences synchronously for instant settings access
  final sharedPrefs = await SharedPreferences.getInstance();

  // Capture cold-start magnet link (if the app was opened via magnet:// URI)
  final initialMagnet = await DeepLinkService.instance.initialize();

  // Light system UI — parchment background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFAF6EE),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: MeitorrentApp(initialMagnetUri: initialMagnet),
    ),
  );
}
