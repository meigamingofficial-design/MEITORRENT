import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    with TickerProviderStateMixin {
  // Dual-pulse glow rings
  late final AnimationController _glowController;
  late final Animation<double> _glowPulse1;
  late final Animation<double> _glowPulse2;

  // Indeterminate loading bar
  late final AnimationController _progressController;

  String _statusText = 'Initializing…';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    unawaited(_boot());
  }

  void _setupAnimations() {
    // Dual-pulse glow: two rings breathing at different intensities
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowPulse1 = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowPulse2 = Tween<double>(begin: 0.06, end: 0.22).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    unawaited(_glowController.repeat(reverse: true));

    // Smooth indeterminate shimmer bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    unawaited(_progressController.repeat());
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

      // 6. Brief pause for logo animation to complete
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // 7. Navigate to dashboard
      if (mounted) {
        unawaited(
          Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const DashboardScreen(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
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

    // Standard storage permission (Android 10 and below)
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      await Permission.storage.request();
    }

    // MANAGE_EXTERNAL_STORAGE (Android 11+) — only prompt once
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown =
          prefs.getBool('meitorrent_storage_perm_shown') ?? false;

      if (!alreadyShown) {
        await prefs.setBool('meitorrent_storage_perm_shown', true);
        await _requestManageStorageWithRationale();
      }
    }
  }

  /// Shows a clear, friendly explanation dialog before directing the user to
  /// the "All files access" system settings page. Only called ONCE per install.
  Future<void> _requestManageStorageWithRationale() async {
    if (!mounted) return;

    final granted = await PermissionService.showStorageRationale(context);

    if (granted) {
      await Permission.manageExternalStorage.request();
    }
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: Stack(
          children: [
            // ── Subtle radial background tint ─────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.2),
                    radius: 0.75,
                    colors: [
                      AppColors.downloading.withValues(
                        alpha: isDark ? 0.06 : 0.04,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo + dual-pulse glow ──────────────────────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer breathing ring
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.downloading.withValues(
                                    alpha: _glowPulse2.value,
                                  ),
                                  blurRadius: 72,
                                  spreadRadius: 28,
                                ),
                              ],
                            ),
                          ),
                          // Inner sharp glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.downloading.withValues(
                                    alpha: _glowPulse1.value * 0.4,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Logo card
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: AppColors.downloading.withValues(
                                  alpha: _glowPulse1.value * 0.22,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.10,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26.5),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                        duration: 950.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 40),

                  // ── App name ───────────────────────────────────────────
                  Text(
                    'Meitorrent',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.text(context),
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(
                        begin: 0.35,
                        end: 0,
                        delay: 300.ms,
                        curve: Curves.easeOutCubic,
                        duration: 600.ms,
                      ),

                  const SizedBox(height: 8),

                  // ── Tagline ────────────────────────────────────────────
                  Text(
                    'Fast. Private. Reliable.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 600.ms)
                      .slideY(
                        begin: 0.35,
                        end: 0,
                        delay: 500.ms,
                        curve: Curves.easeOutCubic,
                        duration: 600.ms,
                      ),

                  const Spacer(flex: 2),

                  // ── Loading / Error area ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: Column(
                      children: [
                        if (!_hasError) ...[
                          // Sleek shimmer loading bar
                          _SleekLoadingBar(controller: _progressController),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.4),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOut,
                                )),
                                child: child,
                              ),
                            ),
                            child: Text(
                              _statusText,
                              key: ValueKey(_statusText),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 36,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _statusText,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _boot,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 750.ms, duration: 500.ms),

                  const SizedBox(height: 40),

                  // ── Footer branding ────────────────────────────────────
                  Column(
                    children: [
                      Text(
                        'from',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.35),
                          fontSize: 10,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MeiGamingOfficial',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.35),
                          fontSize: 12,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 950.ms, duration: 600.ms),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sleek Animated Loading Bar ─────────────────────────────────────────────────

/// A premium thin shimmer bar that replaces the standard circular indicator.
class _SleekLoadingBar extends StatelessWidget {
  const _SleekLoadingBar({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      decoration: BoxDecoration(
        color: AppColors.border(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          final t = controller.value;
          // Shimmer sweeps left to right, slightly wider than the bar
          final start = ((t * 1.5) - 0.35).clamp(0.0, 1.0);
          final end = ((t * 1.5) + 0.35).clamp(0.0, 1.0);
          return CustomPaint(
            size: Size.infinite,
            painter: _ShimmerBarPainter(
              start: start,
              end: end,
              color: AppColors.downloading,
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerBarPainter extends CustomPainter {
  const _ShimmerBarPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  final double start;
  final double end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (end <= start) return;
    final left = size.width * start;
    final right = size.width * end;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.9),
          color,
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, 0, right - left, size.height));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, right - left, size.height),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerBarPainter o) =>
      o.start != start || o.end != end || o.color != color;
}
