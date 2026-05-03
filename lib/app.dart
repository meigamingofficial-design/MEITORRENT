import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'features/torrent_list/presentation/widgets/add_torrent_dialog.dart';

/// Global navigator key — used to show SnackBars and open dialogs from
/// outside the widget tree (e.g. from the deep-link handler).
final navigatorKey = GlobalKey<NavigatorState>();

class MeitorrentApp extends ConsumerStatefulWidget {
  const MeitorrentApp({super.key, this.initialMagnetUri});

  /// Magnet URI captured during cold-start deep linking (before runApp).
  final String? initialMagnetUri;

  @override
  ConsumerState<MeitorrentApp> createState() => _MeitorrentAppState();
}

class _MeitorrentAppState extends ConsumerState<MeitorrentApp> {
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();

    // ── Warm-start deep links ─────────────────────────────────────────
    _deepLinkSub = DeepLinkService.instance.magnetStream.listen(_handleMagnet);

    // ── Cold-start deep link (app launched from magnet in browser) ────
    if (widget.initialMagnetUri != null) {
      // Defer until the navigator is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDialogWithMagnet(widget.initialMagnetUri!);
      });
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  /// Handles an incoming magnet URI from any source (warm-start deep link).
  void _handleMagnet(String uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDialogWithMagnet(uri);
    });
  }

  /// Opens [AddTorrentDialog] pre-filled with [magnetUri] using the global
  /// navigator so it works regardless of what screen is currently showing.
  void _openDialogWithMagnet(String magnetUri) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTorrentDialog(
        initialMagnetUri: magnetUri,
        onMagnetAdded: (uri, path) {
          ref.read(torrentNotifierProvider.notifier).addMagnet(uri, savePath: path);
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF50FA7B), size: 18),
                  SizedBox(width: 10),
                  Text('Torrent added from browser'),
                ],
              ),
              backgroundColor: const Color(0xFF1A1A2E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        onFileAdded: (file, path) {
          ref
              .read(torrentNotifierProvider.notifier)
              .addTorrentFile(file, savePath: path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meitorrent',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            // Hard-lock text scale to 1.0 to completely ignore system font size settings
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
