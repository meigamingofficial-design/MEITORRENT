import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/torrents_table.dart';

part 'app_database.g.dart';

/// Drift database. Single instance managed via Riverpod provider.
@DriftDatabase(tables: [TorrentsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(torrentsTable, torrentsTable.resumeData);
          }
          if (from < 3) {
            await m.addColumn(torrentsTable, torrentsTable.lastActivityAt);
            await m.addColumn(torrentsTable, torrentsTable.completedAt);
          }
        },
      );

  // ─── Queries ─────────────────────────────────────────────────────

  Future<List<TorrentsTableData>> getAllTorrents() =>
      select(torrentsTable).get();

  Stream<List<TorrentsTableData>> watchAllTorrents() =>
      select(torrentsTable).watch();

  Future<TorrentsTableData?> getTorrentById(String id) =>
      (select(torrentsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTorrent(TorrentsTableCompanion entry) =>
      into(torrentsTable).insert(entry);

  Future<bool> updateTorrent(TorrentsTableCompanion entry) =>
      update(torrentsTable).replace(entry);

  Future<void> upsertTorrent(TorrentsTableCompanion entry) =>
      into(torrentsTable).insertOnConflictUpdate(entry);

  Future<int> deleteTorrentById(String id) =>
      (delete(torrentsTable)..where((t) => t.id.equals(id))).go();

  /// Batch snapshot write — called every 5 seconds (not every engine tick).
  Future<void> batchUpdateTorrents(List<TorrentsTableCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        // Use update() with where clause for batch writes — insertOnConflictUpdate
        // is not available on Batch. This upserts via delete+insert pattern.
        b.insert(torrentsTable, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }
}

DatabaseConnection _openConnection() {
  return DatabaseConnection(driftDatabase(name: 'meitorrent.db'));
}
