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
  Future<ThemeMode> build() async => ThemeMode.light;
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
  Future<void> deleteMultiple(List<String> ids,
      {bool deleteFiles = false}) async {}

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
        'isPhysicalDevice': true,
        'version': <String, dynamic>{'sdkInt': 30},
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
}

void _clearChannels() {
  for (final ch in [
    'plugins.flutter.io/device_info',
    'dev.fluttercommunity.plus/device_info',
    'com.pravera.flutter_foreground_task/methods',
    'flutter_foreground_task/methods',
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

    tearDown(_clearChannels);

    testWidgets(
      'renders Battery Optimization tile and Performance section header',
      (WidgetTester tester) async {
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
              torrentRepositoryProvider
                  .overrideWithValue(_FakeTorrentRepository()),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        // Pump the initial frame + one microtask flush.
        // We avoid pumpAndSettle() because _BatteryOptimizationTile's async
        // _checkStatus() call may never resolve in the pure-Dart test env.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('PERFORMANCE'), findsOneWidget);
        expect(find.text('Ignore Battery Optimizations'), findsOneWidget);
      },
    );
  });
}
