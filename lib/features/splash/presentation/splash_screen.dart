import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/engine_process_manager.dart';
import '../../../core/services/foreground_service_manager.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/oem_battery_guard.dart';
import '../../../data/models/torrent_model.dart';
import '../../torrent_list/presentation/controllers/torrent_notifier.dart';
import '../../torrent_list/presentation/screens/dashboard_screen.dart';

/// Splash screen that orchestrates:
/// 1. Permission requests (notifications, battery optimization)
/// 2. OEM battery guard prompt
/// 3. Engine initialization + DB restore
/// 4. Navigation to dashboard
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;

  String _statusText = 'Initializing…';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _boot();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _logoController.forward();
  }

  Future<void> _boot() async {
    try {
      // 1. Request permissions
      _setStatus('Requesting permissions…');
      await _requestPermissions();

      // 2. Setup foreground service
      _setStatus('Configuring background service…');
      await ForegroundServiceManager.instance.setup();

      // 3. Load stored torrents directly from DB (before engine is ready)
      _setStatus('Loading saved torrents…');
      final db = ref.read(appDatabaseProvider);
      final rows = await db.getAllTorrents();
      final stored = rows.map(TorrentModel.fromRow).toList();

      // 4. Initialize engine + restore torrents
      _setStatus('Starting torrent engine…');
      await EngineProcessManager.instance.initialize(
        storedTorrents: stored,
        database: db,
      );

      // 5. Start foreground service
      await ForegroundServiceManager.instance.startService();

      // 6. OEM battery guard (non-blocking)
      if (mounted) {
        unawaited(OemBatteryGuard.instance.promptIfNeeded(context));
      }

      // 7. Brief pause for logo animation
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // 8. Navigate
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.e('[Splash] Boot failed', error: e, stack: st);
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusText = 'Failed to start: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Notification permission (Android 13+)
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Battery optimization exemption
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with glow
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow backdrop
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(
                              alpha: 0.6 * _glowOpacity.value,
                            ),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    // Logo
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF6C63FF)
                                  .withValues(alpha: _logoOpacity.value),
                              const Color(0xFF9D4EDD)
                                  .withValues(alpha: _logoOpacity.value),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withValues(
                                alpha: 0.4 * _logoOpacity.value,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          color: Colors.white
                              .withValues(alpha: _logoOpacity.value),
                          size: 52,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // App name
              AnimatedBuilder(
                animation: _logoOpacity,
                builder: (_, __) => Text(
                  'Meitorrent',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: _logoOpacity.value),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _logoOpacity,
                builder: (_, __) => Text(
                  'Fast. Private. Reliable.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(
                      alpha: _logoOpacity.value * 0.54,
                    ),
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Status indicator
              if (!_hasError) ...[
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_statusText),
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF5555), size: 32),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFFFF5555), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _boot,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
