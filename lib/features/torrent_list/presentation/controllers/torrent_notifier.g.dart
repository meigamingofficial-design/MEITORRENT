// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
String _$torrentRepositoryHash() => r'a4e31813a5cbead4beb06d70d01cc0c942339c2b';

/// See also [torrentRepository].
@ProviderFor(torrentRepository)
final torrentRepositoryProvider = Provider<TorrentRepository>.internal(
  torrentRepository,
  name: r'torrentRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$torrentRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TorrentRepositoryRef = ProviderRef<TorrentRepository>;
String _$torrentNotifierHash() => r'acd641319cbc1348bd1d012c01aadd6bf32a0a83';

/// Central state manager for all torrent operations.
///
/// Responsibilities:
/// - Subscribes to the live engine stream
/// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
/// - Pushes foreground service notification updates on each state change (Hardening #5)
/// - Delegates write operations to [TorrentRepository]
///
/// Copied from [TorrentNotifier].
@ProviderFor(TorrentNotifier)
final torrentNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TorrentNotifier, List<TorrentStatus>>.internal(
  TorrentNotifier.new,
  name: r'torrentNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$torrentNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TorrentNotifier = AutoDisposeAsyncNotifier<List<TorrentStatus>>;
String _$selectedTorrentsHash() => r'9f52d7b70cb21b2d12dba54c59b51fd523ad7227';

/// See also [SelectedTorrents].
@ProviderFor(SelectedTorrents)
final selectedTorrentsProvider =
    AutoDisposeNotifierProvider<SelectedTorrents, Set<String>>.internal(
  SelectedTorrents.new,
  name: r'selectedTorrentsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedTorrentsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedTorrents = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
