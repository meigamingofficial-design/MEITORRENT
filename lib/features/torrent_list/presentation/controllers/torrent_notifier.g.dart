// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(torrentRepository)
final torrentRepositoryProvider = TorrentRepositoryProvider._();

final class TorrentRepositoryProvider
    extends
        $FunctionalProvider<
          TorrentRepository,
          TorrentRepository,
          TorrentRepository
        >
    with $Provider<TorrentRepository> {
  TorrentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'torrentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$torrentRepositoryHash();

  @$internal
  @override
  $ProviderElement<TorrentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TorrentRepository create(Ref ref) {
    return torrentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TorrentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TorrentRepository>(value),
    );
  }
}

String _$torrentRepositoryHash() => r'a4e31813a5cbead4beb06d70d01cc0c942339c2b';

@ProviderFor(ActiveFilter)
final activeFilterProvider = ActiveFilterProvider._();

final class ActiveFilterProvider
    extends $NotifierProvider<ActiveFilter, TorrentFilter> {
  ActiveFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeFilterHash();

  @$internal
  @override
  ActiveFilter create() => ActiveFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TorrentFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TorrentFilter>(value),
    );
  }
}

String _$activeFilterHash() => r'c4b7cd1d564a83ba6fcbef2c594a69c80b4ba587';

abstract class _$ActiveFilter extends $Notifier<TorrentFilter> {
  TorrentFilter build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TorrentFilter, TorrentFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TorrentFilter, TorrentFilter>,
              TorrentFilter,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(filteredTorrents)
final filteredTorrentsProvider = FilteredTorrentsProvider._();

final class FilteredTorrentsProvider
    extends
        $FunctionalProvider<
          List<TorrentStatus>,
          List<TorrentStatus>,
          List<TorrentStatus>
        >
    with $Provider<List<TorrentStatus>> {
  FilteredTorrentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredTorrentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredTorrentsHash();

  @$internal
  @override
  $ProviderElement<List<TorrentStatus>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TorrentStatus> create(Ref ref) {
    return filteredTorrents(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TorrentStatus> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TorrentStatus>>(value),
    );
  }
}

String _$filteredTorrentsHash() => r'38e71ed1d463b638a7b0d4305abaedeeab42845c';

/// Central state manager for all torrent operations.
///
/// Responsibilities:
/// - Subscribes to the live engine stream
/// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
/// - Pushes foreground service notification updates on each state change (Hardening #5)
/// - Delegates write operations to [TorrentRepository]

@ProviderFor(TorrentNotifier)
final torrentProvider = TorrentNotifierProvider._();

/// Central state manager for all torrent operations.
///
/// Responsibilities:
/// - Subscribes to the live engine stream
/// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
/// - Pushes foreground service notification updates on each state change (Hardening #5)
/// - Delegates write operations to [TorrentRepository]
final class TorrentNotifierProvider
    extends $AsyncNotifierProvider<TorrentNotifier, List<TorrentStatus>> {
  /// Central state manager for all torrent operations.
  ///
  /// Responsibilities:
  /// - Subscribes to the live engine stream
  /// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
  /// - Pushes foreground service notification updates on each state change (Hardening #5)
  /// - Delegates write operations to [TorrentRepository]
  TorrentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'torrentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$torrentNotifierHash();

  @$internal
  @override
  TorrentNotifier create() => TorrentNotifier();
}

String _$torrentNotifierHash() => r'0785df94fee84101a360314bd56ef1835e82cf01';

/// Central state manager for all torrent operations.
///
/// Responsibilities:
/// - Subscribes to the live engine stream
/// - Exposes [AsyncValue<List<TorrentStatus>>] to the UI
/// - Pushes foreground service notification updates on each state change (Hardening #5)
/// - Delegates write operations to [TorrentRepository]

abstract class _$TorrentNotifier extends $AsyncNotifier<List<TorrentStatus>> {
  FutureOr<List<TorrentStatus>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<TorrentStatus>>, List<TorrentStatus>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TorrentStatus>>, List<TorrentStatus>>,
              AsyncValue<List<TorrentStatus>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(SelectedTorrents)
final selectedTorrentsProvider = SelectedTorrentsProvider._();

final class SelectedTorrentsProvider
    extends $NotifierProvider<SelectedTorrents, Set<String>> {
  SelectedTorrentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTorrentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTorrentsHash();

  @$internal
  @override
  SelectedTorrents create() => SelectedTorrents();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$selectedTorrentsHash() => r'5d80df8a2f9d976d00ab0ec7cf3644ce75921ec9';

abstract class _$SelectedTorrents extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
