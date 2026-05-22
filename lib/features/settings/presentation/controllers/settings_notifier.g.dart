// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persists and applies engine configuration settings.

@ProviderFor(SettingsNotifier)
final settingsProvider = SettingsNotifierProvider._();

/// Persists and applies engine configuration settings.
final class SettingsNotifierProvider
    extends $NotifierProvider<SettingsNotifier, EngineConfig> {
  /// Persists and applies engine configuration settings.
  SettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsNotifierHash();

  @$internal
  @override
  SettingsNotifier create() => SettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EngineConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EngineConfig>(value),
    );
  }
}

String _$settingsNotifierHash() => r'f5332cd314f50b88a56268d600a6b857e4dae7f6';

/// Persists and applies engine configuration settings.

abstract class _$SettingsNotifier extends $Notifier<EngineConfig> {
  EngineConfig build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<EngineConfig, EngineConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EngineConfig, EngineConfig>,
              EngineConfig,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
