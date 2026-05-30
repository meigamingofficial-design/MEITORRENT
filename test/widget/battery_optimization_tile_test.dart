import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/core/services/shared_preferences_provider.dart';
import 'package:meitorrent/core/theme/theme_service.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';
import 'package:meitorrent/domain/repositories/torrent_repository.dart';
import 'package:meitorrent/features/settings/presentation/screens/settings_screen.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Sync ThemeService override ───────────────────────────────────────────────

/// Skips the async SharedPreferences lookup so the screen builds immediately.
class _SyncThemeService extends ThemeService {
  @override
  Future<ThemeMode> build() async => ThemeMode.dark;
}

// ─── No-op TorrentRepository ──────────────────────────────────────────────────

/// Absorbs all engine calls (applyEngineConfig microtask from SettingsNotifier)
/// without touching any native platform channel.
class _FakeTorrentRepository implements TorrentRepository {
  @override
  Stream<List<TorrentStatus>> get statusStream => const Stream.empty();

  @override
  Future<List<TorrentStatus>> getStoredTorrents() async => [];

  @override
  Future<String> addMagnet(String uri, {String? savePath}) async => '';

  @override
  Future<String> addTorrentFile(String filePath, {String? savePath}) async =>
      '';

  @override
  Future<void> pauseTorrent(String id) async {}

  @override
  Future<void> stopTorrent(String id) async {}

  @override
  Future<void> resumeTorrent(String id) async {}

  @override
  Future<void> deleteTorrent(String id, {bool deleteFiles = false}) async {}

  @override
  Future<void> pauseAll() async {}

  @override
  Future<void> pauseMultiple(List<String> ids) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> stopMultiple(List<String> ids) async {}

  @override
  Future<void> resumeAll() async {}

  @override
  Future<void> resumeMultiple(List<String> ids) async {}

  @override
  Future<void> deleteMultiple(
    List<String> ids, {
    bool deleteFiles = false,
  }) async {}

  @override
  Future<void> recheckTorrent(String id) async {}

  @override
  Future<void> applyEngineConfig(EngineConfig config) async {}

  @override
  Future<void> forceSaveAllResumeData() async {}
}

// ─── Channel helpers ──────────────────────────────────────────────────────────

void _stubChannels() {
  for (final ch in [
    'plugins.flutter.io/device_info',
    'dev.fluttercommunity.plus/device_info',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(ch),
          (_) async => <String, dynamic>{
            'manufacturer': 'Xiaomi',
            'model': 'Mi 11',
            'brand': 'Xiaomi',
            'device': 'mi11',
            'display': 'display',
            'fingerprint': 'fingerprint',
            'hardware': 'hardware',
            'host': 'host',
            'id': 'id',
            'product': 'product',
            'supportedAbis': <String>['arm64-v8a'],
            'supported32BitAbis': <String>[],
            'supported64BitAbis': <String>['arm64-v8a'],
            'tags': 'tags',
            'type': 'type',
            'isPhysicalDevice': true,
            'board': 'board',
            'bootloader': 'bootloader',
            'systemFeatures': <String>[],
            'displayMetrics': <String, dynamic>{
              'widthPx': 1080.0,
              'heightPx': 2400.0,
              'xDpi': 400.0,
              'yDpi': 400.0,
            },
            'freeDiskSize': 1024 * 1024 * 1024,
            'totalDiskSize': 128 * 1024 * 1024 * 1024,
            'isLowRamDevice': false,
            'physicalRamSize': 8000,
            'availableRamSize': 4000,
            'version': <String, dynamic>{
              'sdkInt': 30,
              'baseOS': '',
              'codename': 'REL',
              'incremental': '',
              'previewSdkInt': 0,
              'release': '11',
              'securityPatch': '',
            },
          },
        );
  }

  for (final ch in [
    'com.pravera.flutter_foreground_task/methods',
    'flutter_foreground_task/methods',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(ch),
          (call) async {
            if (call.method == 'isIgnoringBatteryOptimizations') return false;
            return null;
          },
        );
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.meigaming.meitorrent/storage'),
        (call) async {
          if (call.method == 'getDownloadDirectory') {
            return '/storage/emulated/0/Download';
          }
          return null;
        },
      );
}

void _clearChannels() {
  for (final ch in [
    'plugins.flutter.io/device_info',
    'dev.fluttercommunity.plus/device_info',
    'com.pravera.flutter_foreground_task/methods',
    'flutter_foreground_task/methods',
    'com.meigaming.meitorrent/storage',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), null);
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Battery Optimization Tile Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      _stubChannels();
    });

    tearDown(() {
      _clearChannels();
    });

    testWidgets(
      'renders Battery Optimization tile and Performance section header',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          // Use a very tall surface so the entire ListView is built in one pass —
          // lazy lists only instantiate items that fit in the viewport, so
          // skipOffstage:false on find.text() does NOT help with ListView items
          // that were never constructed.
          tester.view.physicalSize = const Size(1080, 6000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                themeServiceProvider.overrideWith(() => _SyncThemeService()),
                torrentRepositoryProvider.overrideWithValue(
                  _FakeTorrentRepository(),
                ),
              ],
              child: const MaterialApp(home: SettingsScreen()),
            ),
          );

          await tester.runAsync(() async {
            await tester.pump();
            // Wait for addPostFrameCallback and async calls
            await Future.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();

          expect(find.text('PERFORMANCE'), findsOneWidget);
          expect(find.text('Ignore Battery Optimizations'), findsOneWidget);
          expect(find.text('Detected Xiaomi Device'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
