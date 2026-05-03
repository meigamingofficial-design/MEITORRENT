import 'dart:async';

import 'package:app_links/app_links.dart';

import 'logger_service.dart';

/// Validates that a string is a well-formed magnet URI.
bool isValidMagnetUri(String uri) =>
    RegExp(r'^magnet:\?xt=urn:btih:[a-fA-F0-9]{32,40}', caseSensitive: false)
        .hasMatch(uri.trim());

/// Handles cold-start and warm-start magnet deep links.
///
/// Usage:
/// ```dart
/// await DeepLinkService.instance.initialize();
/// DeepLinkService.instance.magnetStream.listen((uri) => addMagnet(uri));
/// ```
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Fires whenever a valid magnet URI arrives (cold or warm start).
  Stream<String> get magnetStream => _controller.stream;

  /// Call once, before [runApp]. Returns the initial magnet URI if the app
  /// was launched via a magnet link (cold start), or null.
  Future<String?> initialize() async {
    if (_initialized) return null;
    _initialized = true;

    // Cold-start: app launched directly from a magnet link
    String? coldMagnet;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri == null) {
        // Fallback: check latest link in case getInitialLink missed it
        final latest = await _appLinks.getLatestLink();
        if (latest != null) {
          coldMagnet = _extractMagnet(latest);
          if (coldMagnet != null) {
            AppLogger.i('[DeepLink] Cold-start magnet (latest): $coldMagnet');
          }
        }
      } else {
        coldMagnet = _extractMagnet(initialUri);
        if (coldMagnet != null) {
          AppLogger.i('[DeepLink] Cold-start magnet: $coldMagnet');
        }
      }
    } catch (e, st) {
      AppLogger.w('[DeepLink] Failed to get initial link', error: e, stack: st);
    }

    // Warm-start: app already running, user taps another link
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final magnet = _extractMagnet(uri);
        if (magnet != null) {
          AppLogger.i('[DeepLink] Warm-start magnet: $magnet');
          _controller.add(magnet);
        }
      },
      onError: (Object e, StackTrace st) {
        AppLogger.w('[DeepLink] Stream error', error: e, stack: st);
      },
    );

    return coldMagnet;
  }

  /// Extracts and validates a magnet URI from a [Uri].
  String? _extractMagnet(Uri uri) {
    // The full magnet string reconstructed from the Uri object.
    final raw = uri.toString();
    if (uri.scheme == 'magnet' && isValidMagnetUri(raw)) return raw;
    return null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
