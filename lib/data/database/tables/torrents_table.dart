import 'package:drift/drift.dart';

/// Drift table schema for persisted torrent entries.
class TorrentsTable extends Table {
  /// Torrent info-hash (40 hex chars or 32 base32 chars).
  TextColumn get id => text()();

  /// Whether the torrent is logically paused.
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  /// Whether the torrent is logically stopped.
  BoolColumn get isStopped => boolean().withDefault(const Constant(false))();

  /// Whether the torrent is logically completed.
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Magnet URI — null for file-based torrents.
  TextColumn get magnetUri => text().nullable()();

  /// Path to .torrent file — null for magnet-based torrents.
  TextColumn get torrentFilePath => text().nullable()();

  /// Local directory where files are saved.
  TextColumn get savePath => text()();

  /// Display name.
  TextColumn get name => text()();

  /// Total torrent size in bytes.
  IntColumn get totalSize => integer().withDefault(const Constant(0))();

  /// Downloaded bytes.
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();

  /// Download progress (0.0 – 1.0).
  RealColumn get progress => real().withDefault(const Constant(0.0))();

  /// Serialized TorrentState name.
  TextColumn get state => text().withDefault(const Constant('unknown'))();

  /// Timestamp when torrent was added.
  DateTimeColumn get addedAt => dateTime()();

  /// Timestamp of the latest torrent transfer activity/state change.
  DateTimeColumn get lastActivityAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Timestamp when torrent completed downloading.
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Whether sequential piece download is enabled.
  BoolColumn get isSequentialDownload =>
      boolean().withDefault(const Constant(false))();

  /// Fast-resume binary buffer from libtorrent.
  BlobColumn get resumeData => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
