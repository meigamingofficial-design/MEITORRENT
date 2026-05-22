import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/torrent_list/presentation/controllers/torrent_notifier.dart';

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
    _deepLinkSub = DeepLinkService.instance.torrentStream.listen(
      _handleIncomingLink,
    );
  }

  @override
  void dispose() {
    unawaited(_deepLinkSub?.cancel());
    super.dispose();
  }

  /// Handles an incoming magnet URI or local file path from any source.
  void _handleIncomingLink(String linkOrPath) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isMagnet = linkOrPath.startsWith('magnet:');
      try {
        if (isMagnet) {
          await ref.read(torrentProvider.notifier).addMagnet(linkOrPath);
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            _showToast(ctx, 'Magnet link added successfully');
          }
        } else {
          await ref.read(torrentProvider.notifier).addTorrentFile(linkOrPath);
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            _showToast(ctx, 'Torrent file added successfully');
          }
        }
      } catch (e) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          _showToast(ctx, 'Failed to add torrent: $e');
        }
      }
    });
  }

  void _showToast(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2ECC71),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message, style: TextStyle(color: AppColors.text(ctx))),
          ],
        ),
        backgroundColor: AppColors.surface(ctx),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme service. If it's still loading, default to light.
    final themeMode = ref.watch(themeServiceProvider).value ?? ThemeMode.light;
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
            // 1. Solid traditional parchment base color under the background image
            Container(
              color: const Color(0xFFF9F6F0),
            ),
            // 2. Sakura background image (behind the content routes)
            Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/sakura_bg_light.png',
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
            ),
            // 3. Subtle pink blush overlay for a gorgeous unified Sakura theme
            IgnorePointer(
              child: Container(
                color: const Color(
                  0xFFFFC0CB,
                ).withValues(alpha: 0.04), // 4% opacity soft pink tint
              ),
            ),
            // 4. All routes on top (transparent scaffolds allow the background to show through, but solid cards mask it!)
            scaled,
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
