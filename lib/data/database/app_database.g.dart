// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TorrentsTableTable extends TorrentsTable
    with TableInfo<$TorrentsTableTable, TorrentsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TorrentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isPausedMeta =
      const VerificationMeta('isPaused');
  @override
  late final GeneratedColumn<bool> isPaused = GeneratedColumn<bool>(
      'is_paused', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_paused" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isStoppedMeta =
      const VerificationMeta('isStopped');
  @override
  late final GeneratedColumn<bool> isStopped = GeneratedColumn<bool>(
      'is_stopped', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_stopped" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _magnetUriMeta =
      const VerificationMeta('magnetUri');
  @override
  late final GeneratedColumn<String> magnetUri = GeneratedColumn<String>(
      'magnet_uri', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _torrentFilePathMeta =
      const VerificationMeta('torrentFilePath');
  @override
  late final GeneratedColumn<String> torrentFilePath = GeneratedColumn<String>(
      'torrent_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _savePathMeta =
      const VerificationMeta('savePath');
  @override
  late final GeneratedColumn<String> savePath = GeneratedColumn<String>(
      'save_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalSizeMeta =
      const VerificationMeta('totalSize');
  @override
  late final GeneratedColumn<int> totalSize = GeneratedColumn<int>(
      'total_size', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _downloadedBytesMeta =
      const VerificationMeta('downloadedBytes');
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
      'downloaded_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _progressMeta =
      const VerificationMeta('progress');
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
      'progress', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unknown'));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isSequentialDownloadMeta =
      const VerificationMeta('isSequentialDownload');
  @override
  late final GeneratedColumn<bool> isSequentialDownload = GeneratedColumn<bool>(
      'is_sequential_download', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_sequential_download" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _resumeDataMeta =
      const VerificationMeta('resumeData');
  @override
  late final GeneratedColumn<Uint8List> resumeData = GeneratedColumn<Uint8List>(
      'resume_data', aliasedName, true,
      type: DriftSqlType.blob, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        isPaused,
        isStopped,
        isCompleted,
        magnetUri,
        torrentFilePath,
        savePath,
        name,
        totalSize,
        downloadedBytes,
        progress,
        state,
        addedAt,
        isSequentialDownload,
        resumeData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'torrents_table';
  @override
  VerificationContext validateIntegrity(Insertable<TorrentsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('is_paused')) {
      context.handle(_isPausedMeta,
          isPaused.isAcceptableOrUnknown(data['is_paused']!, _isPausedMeta));
    }
    if (data.containsKey('is_stopped')) {
      context.handle(_isStoppedMeta,
          isStopped.isAcceptableOrUnknown(data['is_stopped']!, _isStoppedMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('magnet_uri')) {
      context.handle(_magnetUriMeta,
          magnetUri.isAcceptableOrUnknown(data['magnet_uri']!, _magnetUriMeta));
    }
    if (data.containsKey('torrent_file_path')) {
      context.handle(
          _torrentFilePathMeta,
          torrentFilePath.isAcceptableOrUnknown(
              data['torrent_file_path']!, _torrentFilePathMeta));
    }
    if (data.containsKey('save_path')) {
      context.handle(_savePathMeta,
          savePath.isAcceptableOrUnknown(data['save_path']!, _savePathMeta));
    } else if (isInserting) {
      context.missing(_savePathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('total_size')) {
      context.handle(_totalSizeMeta,
          totalSize.isAcceptableOrUnknown(data['total_size']!, _totalSizeMeta));
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
          _downloadedBytesMeta,
          downloadedBytes.isAcceptableOrUnknown(
              data['downloaded_bytes']!, _downloadedBytesMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta,
          progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('is_sequential_download')) {
      context.handle(
          _isSequentialDownloadMeta,
          isSequentialDownload.isAcceptableOrUnknown(
              data['is_sequential_download']!, _isSequentialDownloadMeta));
    }
    if (data.containsKey('resume_data')) {
      context.handle(
          _resumeDataMeta,
          resumeData.isAcceptableOrUnknown(
              data['resume_data']!, _resumeDataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TorrentsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TorrentsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      isPaused: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_paused'])!,
      isStopped: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_stopped'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      magnetUri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}magnet_uri']),
      torrentFilePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}torrent_file_path']),
      savePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}save_path'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      totalSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_size'])!,
      downloadedBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}downloaded_bytes'])!,
      progress: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}progress'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
      isSequentialDownload: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_sequential_download'])!,
      resumeData: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}resume_data']),
    );
  }

  @override
  $TorrentsTableTable createAlias(String alias) {
    return $TorrentsTableTable(attachedDatabase, alias);
  }
}

class TorrentsTableData extends DataClass
    implements Insertable<TorrentsTableData> {
  /// Torrent info-hash (40 hex chars or 32 base32 chars).
  final String id;

  /// Whether the torrent is logically paused.
  final bool isPaused;

  /// Whether the torrent is logically stopped.
  final bool isStopped;

  /// Whether the torrent is logically completed.
  final bool isCompleted;

  /// Magnet URI — null for file-based torrents.
  final String? magnetUri;

  /// Path to .torrent file — null for magnet-based torrents.
  final String? torrentFilePath;

  /// Local directory where files are saved.
  final String savePath;

  /// Display name.
  final String name;

  /// Total torrent size in bytes.
  final int totalSize;

  /// Downloaded bytes.
  final int downloadedBytes;

  /// Download progress (0.0 – 1.0).
  final double progress;

  /// Serialized TorrentState name.
  final String state;

  /// Timestamp when torrent was added.
  final DateTime addedAt;

  /// Whether sequential piece download is enabled.
  final bool isSequentialDownload;

  /// Fast-resume binary buffer from libtorrent.
  final Uint8List? resumeData;
  const TorrentsTableData(
      {required this.id,
      required this.isPaused,
      required this.isStopped,
      required this.isCompleted,
      this.magnetUri,
      this.torrentFilePath,
      required this.savePath,
      required this.name,
      required this.totalSize,
      required this.downloadedBytes,
      required this.progress,
      required this.state,
      required this.addedAt,
      required this.isSequentialDownload,
      this.resumeData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['is_paused'] = Variable<bool>(isPaused);
    map['is_stopped'] = Variable<bool>(isStopped);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || magnetUri != null) {
      map['magnet_uri'] = Variable<String>(magnetUri);
    }
    if (!nullToAbsent || torrentFilePath != null) {
      map['torrent_file_path'] = Variable<String>(torrentFilePath);
    }
    map['save_path'] = Variable<String>(savePath);
    map['name'] = Variable<String>(name);
    map['total_size'] = Variable<int>(totalSize);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['progress'] = Variable<double>(progress);
    map['state'] = Variable<String>(state);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['is_sequential_download'] = Variable<bool>(isSequentialDownload);
    if (!nullToAbsent || resumeData != null) {
      map['resume_data'] = Variable<Uint8List>(resumeData);
    }
    return map;
  }

  TorrentsTableCompanion toCompanion(bool nullToAbsent) {
    return TorrentsTableCompanion(
      id: Value(id),
      isPaused: Value(isPaused),
      isStopped: Value(isStopped),
      isCompleted: Value(isCompleted),
      magnetUri: magnetUri == null && nullToAbsent
          ? const Value.absent()
          : Value(magnetUri),
      torrentFilePath: torrentFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(torrentFilePath),
      savePath: Value(savePath),
      name: Value(name),
      totalSize: Value(totalSize),
      downloadedBytes: Value(downloadedBytes),
      progress: Value(progress),
      state: Value(state),
      addedAt: Value(addedAt),
      isSequentialDownload: Value(isSequentialDownload),
      resumeData: resumeData == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeData),
    );
  }

  factory TorrentsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TorrentsTableData(
      id: serializer.fromJson<String>(json['id']),
      isPaused: serializer.fromJson<bool>(json['isPaused']),
      isStopped: serializer.fromJson<bool>(json['isStopped']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      magnetUri: serializer.fromJson<String?>(json['magnetUri']),
      torrentFilePath: serializer.fromJson<String?>(json['torrentFilePath']),
      savePath: serializer.fromJson<String>(json['savePath']),
      name: serializer.fromJson<String>(json['name']),
      totalSize: serializer.fromJson<int>(json['totalSize']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      progress: serializer.fromJson<double>(json['progress']),
      state: serializer.fromJson<String>(json['state']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      isSequentialDownload:
          serializer.fromJson<bool>(json['isSequentialDownload']),
      resumeData: serializer.fromJson<Uint8List?>(json['resumeData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'isPaused': serializer.toJson<bool>(isPaused),
      'isStopped': serializer.toJson<bool>(isStopped),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'magnetUri': serializer.toJson<String?>(magnetUri),
      'torrentFilePath': serializer.toJson<String?>(torrentFilePath),
      'savePath': serializer.toJson<String>(savePath),
      'name': serializer.toJson<String>(name),
      'totalSize': serializer.toJson<int>(totalSize),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'progress': serializer.toJson<double>(progress),
      'state': serializer.toJson<String>(state),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'isSequentialDownload': serializer.toJson<bool>(isSequentialDownload),
      'resumeData': serializer.toJson<Uint8List?>(resumeData),
    };
  }

  TorrentsTableData copyWith(
          {String? id,
          bool? isPaused,
          bool? isStopped,
          bool? isCompleted,
          Value<String?> magnetUri = const Value.absent(),
          Value<String?> torrentFilePath = const Value.absent(),
          String? savePath,
          String? name,
          int? totalSize,
          int? downloadedBytes,
          double? progress,
          String? state,
          DateTime? addedAt,
          bool? isSequentialDownload,
          Value<Uint8List?> resumeData = const Value.absent()}) =>
      TorrentsTableData(
        id: id ?? this.id,
        isPaused: isPaused ?? this.isPaused,
        isStopped: isStopped ?? this.isStopped,
        isCompleted: isCompleted ?? this.isCompleted,
        magnetUri: magnetUri.present ? magnetUri.value : this.magnetUri,
        torrentFilePath: torrentFilePath.present
            ? torrentFilePath.value
            : this.torrentFilePath,
        savePath: savePath ?? this.savePath,
        name: name ?? this.name,
        totalSize: totalSize ?? this.totalSize,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        progress: progress ?? this.progress,
        state: state ?? this.state,
        addedAt: addedAt ?? this.addedAt,
        isSequentialDownload: isSequentialDownload ?? this.isSequentialDownload,
        resumeData: resumeData.present ? resumeData.value : this.resumeData,
      );
  TorrentsTableData copyWithCompanion(TorrentsTableCompanion data) {
    return TorrentsTableData(
      id: data.id.present ? data.id.value : this.id,
      isPaused: data.isPaused.present ? data.isPaused.value : this.isPaused,
      isStopped: data.isStopped.present ? data.isStopped.value : this.isStopped,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      magnetUri: data.magnetUri.present ? data.magnetUri.value : this.magnetUri,
      torrentFilePath: data.torrentFilePath.present
          ? data.torrentFilePath.value
          : this.torrentFilePath,
      savePath: data.savePath.present ? data.savePath.value : this.savePath,
      name: data.name.present ? data.name.value : this.name,
      totalSize: data.totalSize.present ? data.totalSize.value : this.totalSize,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      progress: data.progress.present ? data.progress.value : this.progress,
      state: data.state.present ? data.state.value : this.state,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      isSequentialDownload: data.isSequentialDownload.present
          ? data.isSequentialDownload.value
          : this.isSequentialDownload,
      resumeData:
          data.resumeData.present ? data.resumeData.value : this.resumeData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TorrentsTableData(')
          ..write('id: $id, ')
          ..write('isPaused: $isPaused, ')
          ..write('isStopped: $isStopped, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('magnetUri: $magnetUri, ')
          ..write('torrentFilePath: $torrentFilePath, ')
          ..write('savePath: $savePath, ')
          ..write('name: $name, ')
          ..write('totalSize: $totalSize, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('progress: $progress, ')
          ..write('state: $state, ')
          ..write('addedAt: $addedAt, ')
          ..write('isSequentialDownload: $isSequentialDownload, ')
          ..write('resumeData: $resumeData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      isPaused,
      isStopped,
      isCompleted,
      magnetUri,
      torrentFilePath,
      savePath,
      name,
      totalSize,
      downloadedBytes,
      progress,
      state,
      addedAt,
      isSequentialDownload,
      $driftBlobEquality.hash(resumeData));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TorrentsTableData &&
          other.id == this.id &&
          other.isPaused == this.isPaused &&
          other.isStopped == this.isStopped &&
          other.isCompleted == this.isCompleted &&
          other.magnetUri == this.magnetUri &&
          other.torrentFilePath == this.torrentFilePath &&
          other.savePath == this.savePath &&
          other.name == this.name &&
          other.totalSize == this.totalSize &&
          other.downloadedBytes == this.downloadedBytes &&
          other.progress == this.progress &&
          other.state == this.state &&
          other.addedAt == this.addedAt &&
          other.isSequentialDownload == this.isSequentialDownload &&
          $driftBlobEquality.equals(other.resumeData, this.resumeData));
}

class TorrentsTableCompanion extends UpdateCompanion<TorrentsTableData> {
  final Value<String> id;
  final Value<bool> isPaused;
  final Value<bool> isStopped;
  final Value<bool> isCompleted;
  final Value<String?> magnetUri;
  final Value<String?> torrentFilePath;
  final Value<String> savePath;
  final Value<String> name;
  final Value<int> totalSize;
  final Value<int> downloadedBytes;
  final Value<double> progress;
  final Value<String> state;
  final Value<DateTime> addedAt;
  final Value<bool> isSequentialDownload;
  final Value<Uint8List?> resumeData;
  final Value<int> rowid;
  const TorrentsTableCompanion({
    this.id = const Value.absent(),
    this.isPaused = const Value.absent(),
    this.isStopped = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.magnetUri = const Value.absent(),
    this.torrentFilePath = const Value.absent(),
    this.savePath = const Value.absent(),
    this.name = const Value.absent(),
    this.totalSize = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.progress = const Value.absent(),
    this.state = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.isSequentialDownload = const Value.absent(),
    this.resumeData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TorrentsTableCompanion.insert({
    required String id,
    this.isPaused = const Value.absent(),
    this.isStopped = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.magnetUri = const Value.absent(),
    this.torrentFilePath = const Value.absent(),
    required String savePath,
    required String name,
    this.totalSize = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.progress = const Value.absent(),
    this.state = const Value.absent(),
    required DateTime addedAt,
    this.isSequentialDownload = const Value.absent(),
    this.resumeData = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        savePath = Value(savePath),
        name = Value(name),
        addedAt = Value(addedAt);
  static Insertable<TorrentsTableData> custom({
    Expression<String>? id,
    Expression<bool>? isPaused,
    Expression<bool>? isStopped,
    Expression<bool>? isCompleted,
    Expression<String>? magnetUri,
    Expression<String>? torrentFilePath,
    Expression<String>? savePath,
    Expression<String>? name,
    Expression<int>? totalSize,
    Expression<int>? downloadedBytes,
    Expression<double>? progress,
    Expression<String>? state,
    Expression<DateTime>? addedAt,
    Expression<bool>? isSequentialDownload,
    Expression<Uint8List>? resumeData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isPaused != null) 'is_paused': isPaused,
      if (isStopped != null) 'is_stopped': isStopped,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (magnetUri != null) 'magnet_uri': magnetUri,
      if (torrentFilePath != null) 'torrent_file_path': torrentFilePath,
      if (savePath != null) 'save_path': savePath,
      if (name != null) 'name': name,
      if (totalSize != null) 'total_size': totalSize,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (progress != null) 'progress': progress,
      if (state != null) 'state': state,
      if (addedAt != null) 'added_at': addedAt,
      if (isSequentialDownload != null)
        'is_sequential_download': isSequentialDownload,
      if (resumeData != null) 'resume_data': resumeData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TorrentsTableCompanion copyWith(
      {Value<String>? id,
      Value<bool>? isPaused,
      Value<bool>? isStopped,
      Value<bool>? isCompleted,
      Value<String?>? magnetUri,
      Value<String?>? torrentFilePath,
      Value<String>? savePath,
      Value<String>? name,
      Value<int>? totalSize,
      Value<int>? downloadedBytes,
      Value<double>? progress,
      Value<String>? state,
      Value<DateTime>? addedAt,
      Value<bool>? isSequentialDownload,
      Value<Uint8List?>? resumeData,
      Value<int>? rowid}) {
    return TorrentsTableCompanion(
      id: id ?? this.id,
      isPaused: isPaused ?? this.isPaused,
      isStopped: isStopped ?? this.isStopped,
      isCompleted: isCompleted ?? this.isCompleted,
      magnetUri: magnetUri ?? this.magnetUri,
      torrentFilePath: torrentFilePath ?? this.torrentFilePath,
      savePath: savePath ?? this.savePath,
      name: name ?? this.name,
      totalSize: totalSize ?? this.totalSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      state: state ?? this.state,
      addedAt: addedAt ?? this.addedAt,
      isSequentialDownload: isSequentialDownload ?? this.isSequentialDownload,
      resumeData: resumeData ?? this.resumeData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (isPaused.present) {
      map['is_paused'] = Variable<bool>(isPaused.value);
    }
    if (isStopped.present) {
      map['is_stopped'] = Variable<bool>(isStopped.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (magnetUri.present) {
      map['magnet_uri'] = Variable<String>(magnetUri.value);
    }
    if (torrentFilePath.present) {
      map['torrent_file_path'] = Variable<String>(torrentFilePath.value);
    }
    if (savePath.present) {
      map['save_path'] = Variable<String>(savePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (totalSize.present) {
      map['total_size'] = Variable<int>(totalSize.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (isSequentialDownload.present) {
      map['is_sequential_download'] =
          Variable<bool>(isSequentialDownload.value);
    }
    if (resumeData.present) {
      map['resume_data'] = Variable<Uint8List>(resumeData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TorrentsTableCompanion(')
          ..write('id: $id, ')
          ..write('isPaused: $isPaused, ')
          ..write('isStopped: $isStopped, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('magnetUri: $magnetUri, ')
          ..write('torrentFilePath: $torrentFilePath, ')
          ..write('savePath: $savePath, ')
          ..write('name: $name, ')
          ..write('totalSize: $totalSize, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('progress: $progress, ')
          ..write('state: $state, ')
          ..write('addedAt: $addedAt, ')
          ..write('isSequentialDownload: $isSequentialDownload, ')
          ..write('resumeData: $resumeData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TorrentsTableTable torrentsTable = $TorrentsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [torrentsTable];
}

typedef $$TorrentsTableTableCreateCompanionBuilder = TorrentsTableCompanion
    Function({
  required String id,
  Value<bool> isPaused,
  Value<bool> isStopped,
  Value<bool> isCompleted,
  Value<String?> magnetUri,
  Value<String?> torrentFilePath,
  required String savePath,
  required String name,
  Value<int> totalSize,
  Value<int> downloadedBytes,
  Value<double> progress,
  Value<String> state,
  required DateTime addedAt,
  Value<bool> isSequentialDownload,
  Value<Uint8List?> resumeData,
  Value<int> rowid,
});
typedef $$TorrentsTableTableUpdateCompanionBuilder = TorrentsTableCompanion
    Function({
  Value<String> id,
  Value<bool> isPaused,
  Value<bool> isStopped,
  Value<bool> isCompleted,
  Value<String?> magnetUri,
  Value<String?> torrentFilePath,
  Value<String> savePath,
  Value<String> name,
  Value<int> totalSize,
  Value<int> downloadedBytes,
  Value<double> progress,
  Value<String> state,
  Value<DateTime> addedAt,
  Value<bool> isSequentialDownload,
  Value<Uint8List?> resumeData,
  Value<int> rowid,
});

class $$TorrentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $TorrentsTableTable> {
  $$TorrentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPaused => $composableBuilder(
      column: $table.isPaused, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStopped => $composableBuilder(
      column: $table.isStopped, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get magnetUri => $composableBuilder(
      column: $table.magnetUri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get torrentFilePath => $composableBuilder(
      column: $table.torrentFilePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get savePath => $composableBuilder(
      column: $table.savePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSize => $composableBuilder(
      column: $table.totalSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSequentialDownload => $composableBuilder(
      column: $table.isSequentialDownload,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get resumeData => $composableBuilder(
      column: $table.resumeData, builder: (column) => ColumnFilters(column));
}

class $$TorrentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TorrentsTableTable> {
  $$TorrentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPaused => $composableBuilder(
      column: $table.isPaused, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStopped => $composableBuilder(
      column: $table.isStopped, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get magnetUri => $composableBuilder(
      column: $table.magnetUri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get torrentFilePath => $composableBuilder(
      column: $table.torrentFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get savePath => $composableBuilder(
      column: $table.savePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSize => $composableBuilder(
      column: $table.totalSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progress => $composableBuilder(
      column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSequentialDownload => $composableBuilder(
      column: $table.isSequentialDownload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get resumeData => $composableBuilder(
      column: $table.resumeData, builder: (column) => ColumnOrderings(column));
}

class $$TorrentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TorrentsTableTable> {
  $$TorrentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isPaused =>
      $composableBuilder(column: $table.isPaused, builder: (column) => column);

  GeneratedColumn<bool> get isStopped =>
      $composableBuilder(column: $table.isStopped, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<String> get magnetUri =>
      $composableBuilder(column: $table.magnetUri, builder: (column) => column);

  GeneratedColumn<String> get torrentFilePath => $composableBuilder(
      column: $table.torrentFilePath, builder: (column) => column);

  GeneratedColumn<String> get savePath =>
      $composableBuilder(column: $table.savePath, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get totalSize =>
      $composableBuilder(column: $table.totalSize, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
      column: $table.downloadedBytes, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSequentialDownload => $composableBuilder(
      column: $table.isSequentialDownload, builder: (column) => column);

  GeneratedColumn<Uint8List> get resumeData => $composableBuilder(
      column: $table.resumeData, builder: (column) => column);
}

class $$TorrentsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TorrentsTableTable,
    TorrentsTableData,
    $$TorrentsTableTableFilterComposer,
    $$TorrentsTableTableOrderingComposer,
    $$TorrentsTableTableAnnotationComposer,
    $$TorrentsTableTableCreateCompanionBuilder,
    $$TorrentsTableTableUpdateCompanionBuilder,
    (
      TorrentsTableData,
      BaseReferences<_$AppDatabase, $TorrentsTableTable, TorrentsTableData>
    ),
    TorrentsTableData,
    PrefetchHooks Function()> {
  $$TorrentsTableTableTableManager(_$AppDatabase db, $TorrentsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TorrentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TorrentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TorrentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<bool> isPaused = const Value.absent(),
            Value<bool> isStopped = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> magnetUri = const Value.absent(),
            Value<String?> torrentFilePath = const Value.absent(),
            Value<String> savePath = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> totalSize = const Value.absent(),
            Value<int> downloadedBytes = const Value.absent(),
            Value<double> progress = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<bool> isSequentialDownload = const Value.absent(),
            Value<Uint8List?> resumeData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TorrentsTableCompanion(
            id: id,
            isPaused: isPaused,
            isStopped: isStopped,
            isCompleted: isCompleted,
            magnetUri: magnetUri,
            torrentFilePath: torrentFilePath,
            savePath: savePath,
            name: name,
            totalSize: totalSize,
            downloadedBytes: downloadedBytes,
            progress: progress,
            state: state,
            addedAt: addedAt,
            isSequentialDownload: isSequentialDownload,
            resumeData: resumeData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<bool> isPaused = const Value.absent(),
            Value<bool> isStopped = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> magnetUri = const Value.absent(),
            Value<String?> torrentFilePath = const Value.absent(),
            required String savePath,
            required String name,
            Value<int> totalSize = const Value.absent(),
            Value<int> downloadedBytes = const Value.absent(),
            Value<double> progress = const Value.absent(),
            Value<String> state = const Value.absent(),
            required DateTime addedAt,
            Value<bool> isSequentialDownload = const Value.absent(),
            Value<Uint8List?> resumeData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TorrentsTableCompanion.insert(
            id: id,
            isPaused: isPaused,
            isStopped: isStopped,
            isCompleted: isCompleted,
            magnetUri: magnetUri,
            torrentFilePath: torrentFilePath,
            savePath: savePath,
            name: name,
            totalSize: totalSize,
            downloadedBytes: downloadedBytes,
            progress: progress,
            state: state,
            addedAt: addedAt,
            isSequentialDownload: isSequentialDownload,
            resumeData: resumeData,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TorrentsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TorrentsTableTable,
    TorrentsTableData,
    $$TorrentsTableTableFilterComposer,
    $$TorrentsTableTableOrderingComposer,
    $$TorrentsTableTableAnnotationComposer,
    $$TorrentsTableTableCreateCompanionBuilder,
    $$TorrentsTableTableUpdateCompanionBuilder,
    (
      TorrentsTableData,
      BaseReferences<_$AppDatabase, $TorrentsTableTable, TorrentsTableData>
    ),
    TorrentsTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TorrentsTableTableTableManager get torrentsTable =>
      $$TorrentsTableTableTableManager(_db, _db.torrentsTable);
}
