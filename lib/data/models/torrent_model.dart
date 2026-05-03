import 'package:drift/drift.dart';

import '../../domain/entities/torrent_status.dart';
import '../database/app_database.dart';

/// Maps between Drift DB rows and domain [TorrentStatus] objects.
class TorrentModel {
  TorrentModel._();

  /// Converts a DB row to a lightweight [TorrentStatus] snapshot.
  ///
  /// Critical: forces progress=1.0 and downloadedBytes=totalSize for any
  /// finished/seeding torrent so the UI never shows 0% after a cold restart.
  static TorrentStatus fromRow(TorrentsTableData row) {
    final state = _parseState(row.state);
    final isComplete =
        state == TorrentState.finished || state == TorrentState.seeding;

    // If the torrent is logically complete, clamp values so the UI is correct
    // even if the DB wrote stale 0-bytes before the engine updated them.
    final progress = isComplete ? 1.0 : row.progress;
    final downloadedBytes =
        isComplete && row.totalSize > 0 ? row.totalSize : row.downloadedBytes;

    return TorrentStatus(
      id: row.id,
      name: row.name,
      progress: progress,
      downloadSpeed: 0,
      uploadSpeed: 0,
      peers: 0,
      seeds: 0,
      state: state,
      totalSize: row.totalSize,
      downloadedBytes: downloadedBytes,
      uploadedBytes: 0,
      savePath: row.savePath,
      addedAt: row.addedAt,
      ratio: 0.0,
      magnetUri: row.magnetUri,
      torrentFilePath: row.torrentFilePath,

      isPaused: row.isPaused,
      isCompleted: row.isCompleted,
      isSequentialDownload: row.isSequentialDownload,
    );
  }

  /// Converts a live [TorrentStatus] to a DB companion for upsert.
  static TorrentsTableCompanion toCompanion(TorrentStatus status) {
    return TorrentsTableCompanion(
      id: Value(status.id),
      name: Value(status.name),
      magnetUri: Value(status.magnetUri),
      torrentFilePath: Value(status.torrentFilePath),
      savePath: Value(status.savePath),
      totalSize: Value(status.totalSize),
      downloadedBytes: Value(status.downloadedBytes),
      progress: Value(status.progress),
      state: Value(status.state.name),
      addedAt: Value(status.addedAt),
      isSequentialDownload: Value(status.isSequentialDownload),

      isPaused: Value(status.isPaused),
      isCompleted: Value(status.isCompleted),
    );
  }

  static TorrentState _parseState(String raw) {
    try {
      return TorrentState.values.firstWhere((s) => s.name == raw);
    } catch (_) {
      return TorrentState.unknown;
    }
  }
}
