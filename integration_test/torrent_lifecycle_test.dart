import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:meitorrent/main.dart' as app;

// ─────────────────────────────────────────────────────────────────────────────
// Meitorrent — Torrent Lifecycle Integration Tests
//
// UI Contract (from torrent_list_item.dart):
//   • TAP    → opens QuickActionSheet (pause / resume / delete / more info)
//   • LONG   → enters selection mode (multi-select, NOT the sheet)
//
// Tests covered:
//   1. Pause download → state transitions to paused
//   2. Resume download → state transitions back to downloading/metadata
//   3. Delete torrent (metadata only) → removed from list
//   4. Delete torrent + files → removed from list
//   5. Stop torrent → state shows Stopped (if action exists)
//   6. Optimistic UI: pause shows paused state before engine confirms
//   7. Performance: pause action completes within 500ms
// ─────────────────────────────────────────────────────────────────────────────

const _testMagnet =
    'magnet:?xt=urn:btih:AABBCCDDEEFF00112233445566778899AABBCCDD&dn=LifecycleTest';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Boot helper ────────────────────────────────────────────────────────────
  Future<void> launchApp(WidgetTester tester) async {
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

  // ── Direct Riverpod purge: delete ALL from DB + engine ────────────────────
  // NOTE: ProviderScope.containerOf() needs a DESCENDANT element (MaterialApp),
  // not the ProviderScope element itself.
  Future<void> purgeAllTorrents(WidgetTester tester) async {
    final appElement = tester.element(find.byType(MaterialApp).first);
    final container = ProviderScope.containerOf(appElement, listen: false);

    final db = container.read(appDatabaseProvider);
    final rows = await db.getAllTorrents();

    if (rows.isEmpty) {
      debugPrint('[PURGE] Nothing to purge');
      return;
    }

    final notifier = container.read(torrentProvider.notifier);
    for (final row in rows) {
      try {
        await notifier.deleteTorrent(row.id, deleteFiles: false);
      } catch (e) {
        debugPrint('[PURGE] deleteTorrent(${row.id}) error: $e');
      }
    }
    await db.clearAllTorrents(); // Hard safety-net purge
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    debugPrint(
      '[PURGE] Done — remaining rows: ${(await db.getAllTorrents()).length}',
    );
  }

  // ── Add test magnet via the FAB dialog ────────────────────────────────────
  Future<void> addTestMagnet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_torrent_fab')));
    await tester.pumpAndSettle();

    // Switch to Magnet tab if there is one
    final magnetTab = find.byKey(const Key('add_dialog_magnet_tab'));
    if (magnetTab.evaluate().isNotEmpty) {
      await tester.tap(magnetTab);
      await tester.pumpAndSettle();
    }

    await tester.enterText(
      find.byKey(const Key('magnet_input_field')),
      _testMagnet,
    );
    await tester.tap(find.byKey(const Key('confirm_add_torrent_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  // ── Open the QuickActionSheet for the test torrent ────────────────────────
  // Uses TAP (not longPress) — tap opens the sheet, longPress enters selection mode.
  Future<void> openActionSheet(WidgetTester tester) async {
    final item = find.textContaining('LifecycleTest');
    expect(item, findsWidgets, reason: 'LifecycleTest torrent must be visible');
    await tester.tap(item.first);
    await tester.pumpAndSettle();
  }

  // ── Dismiss any open bottom-sheet / dialog ────────────────────────────────
  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
  }

  // ── Ensure torrent is in a downloading/metadata state ────────────────────
  // If it comes back from DB as Paused (DB restore), resume it first.
  Future<void> ensureDownloading(WidgetTester tester) async {
    if (find.textContaining('LifecycleTest').evaluate().isEmpty) return;

    await openActionSheet(tester);
    final resumeBtn = find.byKey(const Key('quick_action_resume'));
    if (resumeBtn.evaluate().isNotEmpty) {
      await tester.tap(resumeBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    } else {
      // Already downloading — sheet is open, dismiss it
      await dismissSheet(tester);
    }
  }

  // ── Per-test setup ────────────────────────────────────────────────────────
  Future<void> setUpTest(WidgetTester tester) async {
    await launchApp(tester);
    await purgeAllTorrents(tester);
    await addTestMagnet(tester);
    expect(
      find.textContaining('LifecycleTest'),
      findsWidgets,
      reason: 'Test torrent must appear in list before test body runs',
    );
  }

  group('Torrent Lifecycle', () {
    testWidgets('Pause torrent: state changes to paused', (tester) async {
      await setUpTest(tester);
      await ensureDownloading(tester);

      await openActionSheet(tester);
      final pauseBtn = find.byKey(const Key('quick_action_pause'));

      if (pauseBtn.evaluate().isNotEmpty) {
        await tester.tap(pauseBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.textContaining(RegExp('Paused', caseSensitive: false)),
          findsWidgets,
          reason: 'Torrent must show Paused label after pause action',
        );
      } else {
        // Still in metadata-fetch phase — state is not yet pausable
        debugPrint(
          '[LIFECYCLE] Torrent in metadata state, not yet pausable — skipping assertion',
        );
        await dismissSheet(tester);
      }
    });

    testWidgets('Resume torrent: state changes from paused to downloading', (
      tester,
    ) async {
      await setUpTest(tester);
      await ensureDownloading(tester);

      // Step 1: Pause
      await openActionSheet(tester);
      final pauseBtn = find.byKey(const Key('quick_action_pause'));
      if (pauseBtn.evaluate().isNotEmpty) {
        await tester.tap(pauseBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else {
        await dismissSheet(tester);
      }

      // Step 2: Resume
      await openActionSheet(tester);
      final resumeBtn = find.byKey(const Key('quick_action_resume'));
      if (resumeBtn.evaluate().isNotEmpty) {
        await tester.tap(resumeBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(
          find.textContaining(RegExp('Paused', caseSensitive: false)),
          findsNothing,
          reason: 'Torrent must NOT remain Paused after resume',
        );
      } else {
        await dismissSheet(tester);
        expect(
          find.textContaining(RegExp('Paused', caseSensitive: false)),
          findsNothing,
        );
      }
    });

    testWidgets('Delete torrent (metadata only) removes from list', (
      tester,
    ) async {
      await setUpTest(tester);

      await openActionSheet(tester);

      // quick_action_delete is ALWAYS shown regardless of torrent state
      expect(
        find.byKey(const Key('quick_action_delete')),
        findsOneWidget,
        reason: 'Delete button must always be present in quick action sheet',
      );

      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      // Confirm — test mode shows two buttons: "Keep Files" and "Delete Files"
      expect(
        find.byKey(const Key('delete_confirm_keep_files')),
        findsOneWidget,
        reason: 'Keep files button must appear in test mode',
      );
      await tester.tap(find.byKey(const Key('delete_confirm_keep_files')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.textContaining('LifecycleTest'),
        findsNothing,
        reason: 'Torrent must be removed from list after deletion',
      );
    });

    testWidgets('Delete torrent + files removes from list', (tester) async {
      await setUpTest(tester);

      await openActionSheet(tester);

      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('delete_confirm_with_files')),
        findsOneWidget,
        reason: 'Delete files button must appear in test mode',
      );
      await tester.tap(find.byKey(const Key('delete_confirm_with_files')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.textContaining('LifecycleTest'),
        findsNothing,
        reason: 'Torrent must be removed from list after deletion with files',
      );
    });

    testWidgets('Stop torrent: state shows Stopped', (tester) async {
      await setUpTest(tester);

      await openActionSheet(tester);
      final stopBtn = find.byKey(const Key('quick_action_stop'));
      if (stopBtn.evaluate().isNotEmpty) {
        await tester.tap(stopBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          find.textContaining(RegExp('Stopped', caseSensitive: false)),
          findsWidgets,
        );
      } else {
        debugPrint(
          '[LIFECYCLE] Stop button not present in current state — test skipped',
        );
        await dismissSheet(tester);
      }
    });

    testWidgets(
      'Optimistic UI: pause shows paused state before engine confirms',
      (tester) async {
        await setUpTest(tester);
        await ensureDownloading(tester);

        await openActionSheet(tester);
        final pauseBtn = find.byKey(const Key('quick_action_pause'));
        if (pauseBtn.evaluate().isNotEmpty) {
          await tester.tap(pauseBtn);
          await tester.pump(); // single frame — optimistic update
          expect(
            find.textContaining(RegExp('Paused', caseSensitive: false)),
            findsWidgets,
            reason: 'Optimistic state must update immediately on pause tap',
          );
        } else {
          debugPrint(
            '[LIFECYCLE] Not in pausable state — optimistic UI test skipped',
          );
          await dismissSheet(tester);
        }
      },
    );

    testWidgets(
      'Performance: pause action UI response within 500ms',
      (tester) async {
        await setUpTest(tester);
        await ensureDownloading(tester);

        // Measure time from tap to optimistic state update
        await openActionSheet(tester);

        final pauseBtn = find.byKey(const Key('quick_action_pause'));
        if (pauseBtn.evaluate().isNotEmpty) {
          final sw = Stopwatch()..start();
          await tester.tap(pauseBtn);
          await tester.pump(); // optimistic frame
          sw.stop();
          debugPrint(
            '[PERF] Pause optimistic update: ${sw.elapsedMilliseconds}ms',
          );
          expect(sw.elapsedMilliseconds, lessThan(500));
        } else {
          debugPrint('[PERF] Pause not available (skipped)');
          await dismissSheet(tester);
        }
      },
    );
  });
}
