import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meitorrent/core/services/shared_preferences_provider.dart';
import 'package:meitorrent/domain/entities/torrent_status.dart';
import 'package:meitorrent/domain/repositories/torrent_repository.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:meitorrent/features/torrent_list/presentation/widgets/torrent_list_item.dart';

// ─── Fakes & Mocks ───────────────────────────────────────────────────────────

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

// ─── Helpers ─────────────────────────────────────────────────────────────────

TorrentStatus _makeStatus({
  String id = 'test-id',
  String name = 'Test Torrent',
  TorrentState state = TorrentState.downloading,
  double progress = 0.3,
  int downloadSpeed = 1024 * 512, // 512 KB/s
  int totalSize = 1024 * 1024 * 100, // 100 MB
  bool isPaused = false,
  bool isStopped = false,
}) => TorrentStatus(
  id: id,
  name: name,
  progress: progress,
  downloadSpeed: downloadSpeed,
  uploadSpeed: 1024 * 128,
  peers: 5,
  seeds: 20,
  state: state,
  totalSize: totalSize,
  downloadedBytes: (totalSize * progress).round(),
  uploadedBytes: 0,
  savePath: '/sdcard/Downloads',
  addedAt: DateTime(2025, 1, 1),
  lastActivityAt: DateTime.now(),
  ratio: 0.12,
  isPaused: isPaused,
  isStopped: isStopped,
);

late SharedPreferences prefs;

Widget _wrap(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    torrentRepositoryProvider.overrideWithValue(_FakeTorrentRepository()),
    ...overrides,
  ],
  child: MaterialApp(
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('TorrentListItem widget', () {
    testWidgets('shows torrent name', (tester) async {
      final status = _makeStatus(name: 'My Test Torrent');
      await tester.pumpWidget(
        _wrap(
          const TorrentListItem(torrentId: 'test-id'),
          overrides: [
            torrentProvider.overrideWith(() => _MockTorrentNotifier([status])),
          ],
        ),
      );
      // Wait for notifier to resolve future
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('My Test Torrent'), findsOneWidget);
    });

    testWidgets('shows progress percentage for active download', (
      tester,
    ) async {
      final status = _makeStatus(
        progress: 0.45,
        state: TorrentState.downloading,
      );
      await tester.pumpWidget(
        _wrap(
          const TorrentListItem(torrentId: 'test-id'),
          overrides: [
            torrentProvider.overrideWith(() => _MockTorrentNotifier([status])),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      // Should show something like "45%" or "45.0%"
      expect(find.textContaining('45'), findsWidgets);
    });

    testWidgets('shows Paused label when isPaused=true', (tester) async {
      final status = _makeStatus(
        state: TorrentState.paused,
        isPaused: true,
        downloadSpeed: 0,
      );
      await tester.pumpWidget(
        _wrap(
          const TorrentListItem(torrentId: 'test-id'),
          overrides: [
            torrentProvider.overrideWith(() => _MockTorrentNotifier([status])),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('PAUSED'), findsWidgets);
    });

    testWidgets('shows Stopped label when isStopped=true', (tester) async {
      final status = _makeStatus(
        state: TorrentState.stopped,
        isPaused: true,
        isStopped: true,
        downloadSpeed: 0,
      );
      await tester.pumpWidget(
        _wrap(
          const TorrentListItem(torrentId: 'test-id'),
          overrides: [
            torrentProvider.overrideWith(() => _MockTorrentNotifier([status])),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('STOPPED'), findsWidgets);
    });

    testWidgets('selection check icon is white when isSelected=true', (
      tester,
    ) async {
      final status = _makeStatus();
      await tester.pumpWidget(
        _wrap(
          const TorrentListItem(torrentId: 'test-id'),
          overrides: [
            torrentProvider.overrideWith(() => _MockTorrentNotifier([status])),
            selectedTorrentsProvider.overrideWith(
              () => _MockSelectedTorrents({'test-id'}),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final checkIcon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(checkIcon.color, Colors.white);
    });
  });
}

class _MockTorrentNotifier extends TorrentNotifier {
  _MockTorrentNotifier(this.initial);
  final List<TorrentStatus> initial;

  @override
  Future<List<TorrentStatus>> build() async => initial;
}

class _MockSelectedTorrents extends SelectedTorrents {
  _MockSelectedTorrents(this.initial);
  final Set<String> initial;

  @override
  Set<String> build() => initial;

  @override
  bool get isSelectionMode => true;
}
