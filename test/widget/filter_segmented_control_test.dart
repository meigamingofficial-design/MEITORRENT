import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/features/torrent_list/presentation/controllers/torrent_notifier.dart';
import 'package:meitorrent/features/torrent_list/presentation/widgets/filter_segmented_control.dart';

Widget _wrap({required Widget child}) => MaterialApp(
  home: Scaffold(body: child),
);

void main() {
  group('FilterSegmentedControl', () {
    testWidgets('renders All, Downloading, Completed tabs', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: FilterSegmentedControl(
            activeFilter: TorrentFilter.all,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Downloading'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('tapping Downloading calls onChanged', (tester) async {
      TorrentFilter? selected;
      await tester.pumpWidget(
        _wrap(
          child: FilterSegmentedControl(
            activeFilter: TorrentFilter.all,
            onChanged: (f) => selected = f,
          ),
        ),
      );

      await tester.tap(find.text('Downloading'));
      await tester.pumpAndSettle();

      expect(selected, TorrentFilter.downloading);
    });

    testWidgets('tapping Completed calls onChanged', (tester) async {
      TorrentFilter? selected;
      await tester.pumpWidget(
        _wrap(
          child: FilterSegmentedControl(
            activeFilter: TorrentFilter.all,
            onChanged: (f) => selected = f,
          ),
        ),
      );

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(selected, TorrentFilter.completed);
    });

    testWidgets('tapping All calls onChanged', (tester) async {
      TorrentFilter? selected;
      await tester.pumpWidget(
        _wrap(
          child: FilterSegmentedControl(
            activeFilter: TorrentFilter.downloading,
            onChanged: (f) => selected = f,
          ),
        ),
      );

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(selected, TorrentFilter.all);
    });
  });
}
