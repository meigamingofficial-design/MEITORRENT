import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'features/torrent_list/presentation/widgets/add_torrent_dialog.dart';

/// Global navigator key — used to show SnackBars and open dialogs from
/// outside the widget tree (e.g. from the deep-link handler).
final navigatorKey = GlobalKey<NavigatorState>();

class MeitorrentApp extends ConsumerStatefulWidget {
  const MeitorrentApp({super.key, this.initialLinkOrPath});

  /// Magnet URI or cached local .torrent file path captured during cold-start.
  final String? initialLinkOrPath;

  @override
  ConsumerState<MeitorrentApp> createState() => _MeitorrentAppState();
}

class _MeitorrentAppState extends ConsumerState<MeitorrentApp> {
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();

    // ── Warm-start deep links ─────────────────────────────────────────
    _deepLinkSub = DeepLinkService.instance.torrentStream.listen(_handleIncomingLink);
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  /// Handles an incoming magnet URI or local file path from any source.
  void _handleIncomingLink(String linkOrPath) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDialogWithLink(linkOrPath);
    });
  }

  /// Opens [AddTorrentDialog] pre-filled with [linkOrPath] using the global
  /// navigator so it works regardless of what screen is currently showing.
  void _openDialogWithLink(String linkOrPath) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final isMagnet = linkOrPath.startsWith('magnet:');

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTorrentDialog(
        initialMagnetUri: isMagnet ? linkOrPath : null,
        initialTorrentFilePath: isMagnet ? null : linkOrPath,
        onMagnetAdded: (uri, path) {
          ref
              .read(torrentNotifierProvider.notifier)
              .addMagnet(uri, savePath: path);
          _showToast(ctx, 'Torrent added from browser');
        },
        onFileAdded: (file, path) {
          ref
              .read(torrentNotifierProvider.notifier)
              .addTorrentFile(file, savePath: path);
          _showToast(ctx, 'Torrent added from storage');
        },
      ),
    );
  }

  void _showToast(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF2ECC71), size: 18),
            const SizedBox(width: 10),
            Text(message, style: TextStyle(color: AppColors.text(ctx))),
          ],
        ),
        backgroundColor: AppColors.surface(ctx),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme service. If it's still loading, default to light.
    final themeMode =
        ref.watch(themeServiceProvider).valueOrNull ?? ThemeMode.light;
    final isLight = themeMode != ThemeMode.dark;

    return MaterialApp(
      title: 'Meitorrent',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // Use our centralized theme definitions
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );

        // ── Sakura background (light theme only) ──────────────────────
        if (!isLight) return scaled;

        return Stack(
          fit: StackFit.expand,
          children: [
            // All routes (now opaque parchment in light mode)
            scaled,
            // Subtle pink blush overlay for a gorgeous unified Sakura theme
            IgnorePointer(
              child: Container(
                color: const Color(0xFFFFC0CB).withValues(alpha: 0.04), // 4% opacity soft pink tint
              ),
            ),
            // Sakura watermark — on top of UI with IgnorePointer to prevent interference
            // This prevents "ghosting" during transitions because routes are now opaque
            IgnorePointer(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/sakura_bg_light.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topRight,
                ),
              ),
            ),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
