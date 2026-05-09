import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';

import 'logger_service.dart';

/// Validates that a string is a well-formed magnet URI.
bool isValidMagnetUri(String uri) =>
    RegExp(r'^magnet:\?xt=urn:btih:[a-fA-F0-9]{32,40}', caseSensitive: false)
        .hasMatch(uri.trim());

/// Handles cold-start and warm-start magnet and local .torrent file links.
///
/// Usage:
/// ```dart
/// await DeepLinkService.instance.initialize();
/// DeepLinkService.instance.torrentStream.listen((linkOrPath) => handleLink(linkOrPath));
/// ```
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _channel = MethodChannel('com.meigaming.meitorrent/files');
  final _appLinks = AppLinks();
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Fires whenever a valid magnet URI or a copied local .torrent file path arrives.
  Stream<String> get torrentStream => _controller.stream;

  /// Call once, before [runApp]. Returns the initial magnet URI or copied local .torrent path
  /// if the app was launched via a file/link (cold start), or null.
  Future<String?> initialize() async {
    if (_initialized) return null;
    _initialized = true;

    // Cold-start: app launched directly from a magnet or local torrent file
    String? coldLink;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri == null) {
        // Fallback: check latest link in case getInitialLink missed it
        final latest = await _appLinks.getLatestLink();
        if (latest != null) {
          coldLink = await _resolveIncomingUri(latest);
          if (coldLink != null) {
            AppLogger.i('[DeepLink] Cold-start link (latest): $coldLink');
          }
        }
      } else {
        coldLink = await _resolveIncomingUri(initialUri);
        if (coldLink != null) {
          AppLogger.i('[DeepLink] Cold-start link: $coldLink');
        }
      }
    } catch (e, st) {
      AppLogger.w('[DeepLink] Failed to get initial link', error: e, stack: st);
    }

    // Warm-start: app already running, user taps/opens another file/link
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        final resolved = await _resolveIncomingUri(uri);
        if (resolved != null) {
          AppLogger.i('[DeepLink] Warm-start link: $resolved');
          _controller.add(resolved);
        }
      },
      onError: (Object e, StackTrace st) {
        AppLogger.w('[DeepLink] Stream error', error: e, stack: st);
      },
    );

    return coldLink;
  }

  /// Resolves an incoming Uri into either a validated magnet link or a locally copied file path.
  Future<String?> _resolveIncomingUri(Uri uri) async {
    final raw = uri.toString();
    
    // Scheme 1: Magnet deep links
    if (uri.scheme == 'magnet' && isValidMagnetUri(raw)) {
      return raw;
    }

    // Scheme 2: .torrent files from local storage (either file:// or content://)
    final pathLower = uri.path.toLowerCase();
    if (uri.scheme == 'content' || uri.scheme == 'file' || pathLower.endsWith('.torrent')) {
      try {
        AppLogger.i('[DeepLink] Copying incoming torrent URI to secure cache: $raw');
        final String? cachedPath = await _channel.invokeMethod('copyContentUriToCache', {'uri': raw});
        if (cachedPath != null) {
          return cachedPath;
        }
      } catch (e, st) {
        AppLogger.w('[DeepLink] Failed to resolve local torrent file content', error: e, stack: st);
      }
    }

    return null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
