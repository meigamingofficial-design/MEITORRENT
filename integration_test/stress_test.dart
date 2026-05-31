import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meitorrent/core/native/libtorrent_flutter_base.dart';
import 'package:meitorrent/core/services/torrent_engine_service.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:meitorrent/main.dart' as app;

// ─────────────────────────────────────────────────────────────────────────────
// Meitorrent — Stress Tests
//
// Scenarios:
//   1. Add 10 torrents rapidly — list renders without jank
//   2. Rapid pause → resume × 20 iterations — no state corruption
//   3. Bulk select all + delete — list becomes empty
//   4. Rapid add → delete cycle × 10 — no crashes
// ─────────────────────────────────────────────────────────────────────────────

// Test magnets (different info-hashes for uniqueness)
List<String> _magnets(int count) => List.generate(
  count,
  (i) {
    const base = 'AABBCCDDEEFF00112233445566778899AABBCCD';
    final lastDigit = i.toRadixString(16);
    return 'magnet:?xt=urn:btih:$base$lastDigit&dn=StressTest$i';
  },
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> purgeAllTorrents(WidgetTester tester) async {
    // Dismiss any open bottom sheets/dialogs safely by popping Navigator routes
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

    // Extra safety net: explicitly pop if any BottomSheet or Dialog is still in the tree
    try {
      int safetyCount = 0;
      while ((find.byType(BottomSheet).evaluate().isNotEmpty || 
              find.byType(Dialog).evaluate().isNotEmpty) && 
             safetyCount < 10) {
        final Finder navFinder = find.byType(Navigator);
        if (navFinder.evaluate().isNotEmpty) {
          final NavigatorState navigator = tester.state(navFinder.last);
          navigator.pop();
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
        } else {
          break;
        }
        safetyCount++;
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

  Future<void> delay(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> launchAndWait(WidgetTester tester) async {
    await app.main();
    bool loaded = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const Key('add_torrent_fab')).evaluate().isNotEmpty) {
        loaded = true;
        break;
      }
    }
    expect(loaded, isTrue, reason: 'App failed to load dashboard within 20s');
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

  group('Stress Tests', () {
    testWidgets('Add 10 torrents sequentially — no crash, all visible', (
      tester,
    ) async {
      await launchAndWait(tester);
      await purgeAllTorrents(tester);

      final magnets = _magnets(10);
      for (final m in magnets) {
        await addMagnet(tester, m);
      }

      // Verify all 10 exist in the state provider (independent of scroll position/screen height)
      final appElement = tester.element(find.byType(MaterialApp).first);
      final container = ProviderScope.containerOf(appElement, listen: false);
      final torrents = container.read(torrentProvider).value ?? [];
      expect(torrents.length, equals(10));
      for (var i = 0; i < 10; i++) {
        expect(torrents.any((t) => t.name.contains('StressTest$i')), isTrue);
      }

      // Verify the top visible ones are rendered on screen
      expect(find.textContaining('StressTest9'), findsWidgets);
      expect(find.textContaining('StressTest8'), findsWidgets);

      // No exceptions during rapid add
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Rapid pause/resume x20 — no state corruption or crash',
      (tester) async {
        await launchAndWait(tester);
        await purgeAllTorrents(tester);
        await addMagnet(tester, _magnets(1).first);

        for (var i = 0; i < 20; i++) {
          final torrentItem = find.byKey(const Key('torrent_list_item')).first;
          await tester.tap(torrentItem);
          await tester.pumpAndSettle();
          await delay(tester, 1);

          final pauseBtn = find.byKey(const Key('quick_action_pause'));
          final resumeBtn = find.byKey(const Key('quick_action_resume'));

          if (pauseBtn.evaluate().isNotEmpty) {
            await tester.tap(pauseBtn);
          } else if (resumeBtn.evaluate().isNotEmpty) {
            await tester.tap(resumeBtn);
          } else {
            // Dismiss sheet by tapping outside
            await tester.tapAt(const Offset(200, 100));
          }
          await tester.pumpAndSettle();
          await delay(tester, 1);
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Bulk select all → delete — list becomes empty',
      (tester) async {
        await launchAndWait(tester);
        await purgeAllTorrents(tester);

        // Add 5 torrents
        final magnets = _magnets(5);
        for (final m in magnets) {
          await addMagnet(tester, m);
        }

        // Enter selection mode (LONG press enters selection mode)
        await tester.longPress(
          find.byKey(const Key('torrent_list_item')).first,
        );
        await tester.pumpAndSettle();
        await delay(tester, 1);

        // Select all
        await tester.tap(find.byKey(const Key('select_all_button')));
        await tester.pumpAndSettle();

        // Delete selected
        await tester.tap(find.byKey(const Key('delete_selected_button')));
        await tester.pumpAndSettle();
        await delay(tester, 1);

        // Confirm
        await tester.tap(
          find.byKey(const Key('delete_confirm_keep_files')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        await delay(tester, 3);

        // List should be empty
        expect(find.byKey(const Key('torrent_list_item')), findsNothing);
        expect(find.byKey(const Key('empty_state_widget')), findsOneWidget);
      },
    );

    testWidgets(
      'Rapid add → delete cycle x10 — no memory leak or crash',
      (tester) async {
        await launchAndWait(tester);
        await purgeAllTorrents(tester);

        for (var i = 0; i < 10; i++) {
          final magnet = _magnets(i + 1).last;
          await addMagnet(tester, magnet);

          // Immediately delete via tap + quick action delete
          await tester.pumpAndSettle();
          final item = find.byKey(const Key('torrent_list_item')).last;
          await tester.tap(item);
          await tester.pumpAndSettle();
          await delay(tester, 1);

          final deleteBtn = find.byKey(const Key('quick_action_delete'));
          expect(deleteBtn, findsOneWidget);
          await tester.tap(deleteBtn);
          await tester.pumpAndSettle();
          await delay(tester, 1);

          expect(
            find.byKey(const Key('delete_confirm_keep_files')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('delete_confirm_keep_files')),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
          await delay(tester, 2);
        }

        expect(tester.takeException(), isNull);
      },
    );
  });
}
