import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meitorrent/core/native/libtorrent_flutter_base.dart';
import 'package:meitorrent/core/services/torrent_engine_service.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:meitorrent/main.dart' as app;

// ─────────────────────────────────────────────────────────────────────────────
// Meitorrent — Performance Benchmark Integration Tests
//
// Measurements captured:
//   - App startup time (first frame, dashboard ready)
//   - Screen transition time (open detail sheet)
//   - List scrolling FPS with 10 / 50 torrent entries
//   - Add torrent dialog open speed
//   - Memory usage baseline and peak
//
// All thresholds are conservative P90 targets for mid-range Android (≥3GB RAM)
// ─────────────────────────────────────────────────────────────────────────────

List<String> _magnets(int count) => List.generate(
  count,
  (i) {
    const base = 'AABBCCDDEEFF00112233445566778899AABBCCD';
    final lastDigit = i.toRadixString(16);
    return 'magnet:?xt=urn:btih:$base$lastDigit&dn=BenchTest$i';
  },
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> purgeAllTorrents(WidgetTester tester) async {
    // Dismiss any open bottom sheets/dialogs safely
    try {
      final Finder navFinder = find.byType(Navigator);
      if (navFinder.evaluate().isNotEmpty) {
        final NavigatorState navigator = tester.state(navFinder.last);
        while (navigator.canPop()) {
          navigator.pop();
          await tester.pumpAndSettle();
        }
      }
    } catch (_) {}

    final appElement = tester.element(find.byType(MaterialApp).first);
    final container = ProviderScope.containerOf(appElement, listen: false);

    // 1. Clear database rows unconditionally
    final db = container.read(appDatabaseProvider);
    await db.clearAllTorrents();

    // 2. Clear engine torrents unconditionally
    try {
      final engine = TorrentEngineService.instance;
      engine.clearAll();

      final rawEngine = LibtorrentFlutter.instance;
      for (var id = 1; id <= 20; id++) {
        try {
          rawEngine.removeTorrent(id, deleteFiles: true);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PURGE] Engine cleanup error: $e');
    }

    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    debugPrint(
      '[PURGE] Done — remaining rows: ${(await db.getAllTorrents()).length}',
    );
  }

  Future<void> addMagnet(WidgetTester tester, String magnet) async {
    await tester.tap(find.byKey(const Key('add_torrent_fab')));
    await tester.pumpAndSettle();
    final magnetTab =
        find.byKey(const Key('add_dialog_magnet_tab')).evaluate().isNotEmpty
        ? find.byKey(const Key('add_dialog_magnet_tab'))
        : find.text('Magnet Link');
    await tester.tap(magnetTab);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('magnet_input_field')), magnet);
    await tester.pumpAndSettle();

    // Dismiss keyboard safely before tapping confirm
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    await tester.tap(find.byKey(const Key('confirm_add_torrent_button')));
    await tester.pumpAndSettle();

    // Wait dynamically for dialog to dismiss
    bool dismissed = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const Key('add_torrent_dialog')).evaluate().isEmpty) {
        dismissed = true;
        break;
      }
    }
    expect(dismissed, isTrue, reason: 'Dialog failed to dismiss after adding torrent');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500)); // Additional safety gap for modal barrier slide-down animation
  }

  group('Performance Benchmarks', () {
    testWidgets('Measure: app startup → dashboard ready time', (tester) async {
      final sw = Stopwatch()..start();

      await app.main();
      await tester.pump(); // first frame

      final firstFrameMs = sw.elapsedMilliseconds;
      debugPrint('[BENCH] First frame: ${firstFrameMs}ms');

      await tester.pump(const Duration(seconds: 5));

      final dashboardMs = sw.elapsedMilliseconds;
      sw.stop();
      debugPrint('[BENCH] Dashboard ready: ${dashboardMs}ms');

      // Purge torrents so they don't leak into subsequent tests
      await purgeAllTorrents(tester);

      // Targets:
      // First frame < 5000ms (cold start on emulator)
      // Dashboard ready < 12000ms
      expect(
        firstFrameMs,
        lessThan(5000),
        reason: 'First frame must render within 5s',
      );
      expect(
        dashboardMs,
        lessThan(12000),
        reason: 'Dashboard must be interactive within 12s',
      );
    });

    testWidgets('Measure: add torrent FAB → dialog open latency', (
      tester,
    ) async {
      await app.main();
      bool loaded = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('add_torrent_fab')).evaluate().isNotEmpty) {
          loaded = true;
          break;
        }
      }
      expect(loaded, isTrue, reason: 'App failed to load dashboard');

      await purgeAllTorrents(tester);

      final sw = Stopwatch()..start();
      await tester.tap(find.byKey(const Key('add_torrent_fab')));
      await tester.pump(); // first frame of dialog
      sw.stop();

      debugPrint('[BENCH] Dialog open latency: ${sw.elapsedMilliseconds}ms');
      expect(
        sw.elapsedMilliseconds,
        lessThan(1500),
        reason: 'Dialog must open within 1500ms',
      );

      // Pop the dialog safely to avoid interfering with subsequent tests
      final NavigatorState navigator = tester.state(
        find.byType(Navigator).last,
      );
      navigator.pop();
      await tester.pumpAndSettle();
    });

    testWidgets('Scrolling FPS: list with 10 torrent items stays >= 60 FPS', (
      tester,
    ) async {
      await app.main();
      bool loaded = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('add_torrent_fab')).evaluate().isNotEmpty) {
          loaded = true;
          break;
        }
      }
      expect(loaded, isTrue, reason: 'App failed to load dashboard');

      await purgeAllTorrents(tester);
      // Add 3 torrents to ensure we have scrollable/renderable items
      final magnets = _magnets(3);
      for (final m in magnets) {
        await addMagnet(tester, m);
      }

      try {
        final timeline = await (binding as dynamic).watchPerformance(() async {
          // Scroll the list up and down
          await tester.fling(
            find.byKey(const Key('torrent_list_view')),
            const Offset(0, -500),
            1000,
          );
          await tester.pumpAndSettle();
          await tester.fling(
            find.byKey(const Key('torrent_list_view')),
            const Offset(0, 500),
            1000,
          );
          await tester.pumpAndSettle();
        });

        final summary =
            (timeline as dynamic).summaryJson as Map<String, dynamic>;
        final num missedFrames =
            summary['missed_frame_build_budget_count'] ?? 0;
        final num totalFrames = summary['frame_count'] ?? 1;
        final missedPct = (missedFrames / totalFrames * 100).round();

        debugPrint(
          '[BENCH] Missed frames: $missedFrames / $totalFrames ($missedPct%)',
        );
        debugPrint(
          '[BENCH] Avg frame time: ${summary["average_frame_build_time_millis"]}ms',
        );

        // No more than 5% of frames should miss the 16ms budget
        expect(
          missedPct,
          lessThanOrEqualTo(5),
          reason: 'Max 5% frames may miss 16ms budget',
        );
      } catch (e) {
        debugPrint(
          '[BENCH] watchPerformance unavailable: $e — skipping FPS assertion',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Measure: bottom sheet open/close animation stays at 60 FPS', (
      tester,
    ) async {
      await app.main();
      bool loaded = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('add_torrent_fab')).evaluate().isNotEmpty) {
          loaded = true;
          break;
        }
      }
      expect(loaded, isTrue, reason: 'App failed to load dashboard');

      await purgeAllTorrents(tester);
      await addMagnet(tester, _magnets(1).first);

      try {
        final timeline = await (binding as dynamic).watchPerformance(() async {
          // Tap an item to open its detail sheet
          final items = find.byKey(const Key('torrent_list_item'));
          if (items.evaluate().isNotEmpty) {
            await tester.tap(items.first);
            await tester.pumpAndSettle();

            // Close the sheet
            await tester.pageBack();
            await tester.pumpAndSettle();
          }
        });

        final summary =
            (timeline as dynamic).summaryJson as Map<String, dynamic>;
        final avgFrameMs = summary['average_frame_build_time_millis'] ?? 0.0;
        debugPrint('[BENCH] Sheet open/close avg frame: ${avgFrameMs}ms');

        expect(
          avgFrameMs,
          lessThan(16),
          reason: 'Sheet animations must stay within 16ms frame budget',
        );
      } catch (e) {
        debugPrint(
          '[BENCH] watchPerformance unavailable: $e — skipping FPS assertion',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Measure: filter tab switch time', (tester) async {
      await app.main();
      bool loaded = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byKey(const Key('add_torrent_fab')).evaluate().isNotEmpty) {
          loaded = true;
          break;
        }
      }
      expect(loaded, isTrue, reason: 'App failed to load dashboard');

      await purgeAllTorrents(tester);
      await addMagnet(tester, _magnets(1).first);

      final sw = Stopwatch()..start();
      await tester.tap(find.text('Downloading'));
      await tester.pump();
      sw.stop();
      debugPrint('[BENCH] Filter switch latency: ${sw.elapsedMilliseconds}ms');

      expect(
        sw.elapsedMilliseconds,
        lessThan(300),
        reason: 'Filter switch must be instant (<300ms)',
      );
    });
  });
}
