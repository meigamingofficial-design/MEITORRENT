import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/foreground_service_manager.dart';
import 'core/services/notification_service.dart';

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

  // Capture cold-start magnet link (if the app was opened via magnet:// URI)
  final initialMagnet = await DeepLinkService.instance.initialize();

  // Dark system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      child: MeitorrentApp(initialMagnetUri: initialMagnet),
    ),
  );
}
