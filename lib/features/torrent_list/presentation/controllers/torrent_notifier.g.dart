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
String _$filteredTorrentsHash() => r'3abfd78ed03bac4c826c3019ab6d00d6c723ef5d';

/// See also [filteredTorrents].
@ProviderFor(filteredTorrents)
final filteredTorrentsProvider =
    AutoDisposeProvider<List<TorrentStatus>>.internal(
  filteredTorrents,
  name: r'filteredTorrentsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredTorrentsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FilteredTorrentsRef = AutoDisposeProviderRef<List<TorrentStatus>>;
String _$activeFilterHash() => r'c4b7cd1d564a83ba6fcbef2c594a69c80b4ba587';

/// See also [ActiveFilter].
@ProviderFor(ActiveFilter)
final activeFilterProvider =
    AutoDisposeNotifierProvider<ActiveFilter, TorrentFilter>.internal(
  ActiveFilter.new,
  name: r'activeFilterProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$activeFilterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveFilter = AutoDisposeNotifier<TorrentFilter>;
String _$torrentNotifierHash() => r'e74cc840ba05d451ce96d2b8d9b1fc42dd5216fc';

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
String _$selectedTorrentsHash() => r'8895b358ee0521342cc34aafb78d7be45121e05a';

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
