import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/engine_process_manager.dart';
import '../../../core/services/foreground_service_manager.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/models/torrent_model.dart';
import '../../torrent_list/presentation/controllers/torrent_notifier.dart';
import '../../torrent_list/presentation/screens/dashboard_screen.dart';
import '../../../core/theme/app_theme.dart';

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
    unawaited(_boot());
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

    unawaited(_logoController.forward());
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

      // 6. Brief pause for logo animation
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // 8. Navigate
      if (mounted) {
        unawaited(
          Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const DashboardScreen(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
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
    // Notification permission (Android 13+) — skip if already granted
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Standard storage permission (Android 10 and below) — check once, request only if needed
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      await Permission.storage.request();
    }

    // MANAGE_EXTERNAL_STORAGE (Android 11+)
    // Only show the rationale dialog ONCE (first install). On subsequent launches where
    // permission is still denied/skipped, we silently skip — no nagging.
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown =
          prefs.getBool('meitorrent_storage_perm_shown') ?? false;

      if (!alreadyShown) {
        // Mark as shown so we never prompt again (unless user explicitly triggers it)
        await prefs.setBool('meitorrent_storage_perm_shown', true);
        await _requestManageStorageWithRationale();
      }
      // If already shown and still not granted — silently continue, app still works
    }
  }

  /// Shows a clear, friendly explanation dialog before directing the user to
  /// the "All files access" system settings page. Handles rejection gracefully.
  /// Only called ONCE per install — never nags again.
  Future<void> _requestManageStorageWithRationale() async {
    if (!mounted) return;

    final granted = await PermissionService.showStorageRationale(context);

    if (granted) {
      // Open the system "All files access" settings page
      await Permission.manageExternalStorage.request();

      // Check if the user actually granted it after returning from system settings
      // Permission handled, continue
    } else {
      // User chose to skip
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
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
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
                                  color: AppColors.downloading.withValues(
                                    alpha: 0.5 * _glowOpacity.value,
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
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.border(
                                      context,
                                    ).withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22.5),
                                  child: Image.asset(
                                    'assets/images/app_logo.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
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
                      builder: (_, _) => Text(
                        'Meitorrent',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: AppColors.text(
                                context,
                              ).withValues(alpha: _logoOpacity.value),
                              fontSize: 34,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _logoOpacity,
                      builder: (_, _) => Text(
                        'Fast. Private. Reliable.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(context).withValues(
                            alpha: _logoOpacity.value * 0.7,
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
                          color: AppColors.downloading,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary(context),
                                fontSize: 13,
                              ),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
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
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _logoOpacity,
                  builder: (_, _) => Opacity(
                    opacity: _logoOpacity.value * 0.25,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'from',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MeiGamingOfficial',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 13,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
