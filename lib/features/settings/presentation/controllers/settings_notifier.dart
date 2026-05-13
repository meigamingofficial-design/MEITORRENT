import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/shared_preferences_provider.dart';
import '../../../../domain/repositories/torrent_repository.dart';
import '../../../torrent_list/presentation/controllers/torrent_notifier.dart';

part 'settings_notifier.g.dart';

/// Persists and applies engine configuration settings.
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  EngineConfig build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final config = EngineConfig(
      downloadLimit: prefs.getInt('meitorrent_download_limit') ?? 0,
      uploadLimit: prefs.getInt('meitorrent_upload_limit') ?? 0,
      wifiOnlyMode: prefs.getBool('meitorrent_wifi_only') ?? false,
      stopSeedingWhenFinished: prefs.getBool('meitorrent_stop_seeding') ?? true,
      dhtEnabled: prefs.getBool('meitorrent_dht') ?? true,
      pexEnabled: prefs.getBool('meitorrent_pex') ?? true,
      maxGlobalConnections: prefs.getInt('meitorrent_max_connections') ?? 500,
    );

    // Apply the saved settings to the engine upon startup
    Future.microtask(() {
      ref.read(torrentRepositoryProvider).applyEngineConfig(config);
    });

    return config;
  }

  Future<void> setDownloadLimit(int bps) async {
    state = state.copyWith(downloadLimit: bps);
    await _apply();
  }

  Future<void> setUploadLimit(int bps) async {
    state = state.copyWith(uploadLimit: bps);
    await _apply();
  }

  Future<void> setWifiOnly(bool enabled) async {
    state = state.copyWith(wifiOnlyMode: enabled);
    await _apply();
  }

  Future<void> setStopSeeding(bool enabled) async {
    state = state.copyWith(stopSeedingWhenFinished: enabled);
    await _apply();
  }

  Future<void> setDht(bool enabled) async {
    state = state.copyWith(dhtEnabled: enabled);
    await _apply();
  }

  Future<void> setPex(bool enabled) async {
    state = state.copyWith(pexEnabled: enabled);
    await _apply();
  }

  Future<void> setMaxConnections(int n) async {
    state = state.copyWith(maxGlobalConnections: n);
    await _apply();
  }

  Future<void> _apply() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('meitorrent_download_limit', state.downloadLimit);
    await prefs.setInt('meitorrent_upload_limit', state.uploadLimit);
    await prefs.setBool('meitorrent_wifi_only', state.wifiOnlyMode);
    await prefs.setBool(
        'meitorrent_stop_seeding', state.stopSeedingWhenFinished);
    await prefs.setBool('meitorrent_dht', state.dhtEnabled);
    await prefs.setBool('meitorrent_pex', state.pexEnabled);
    await prefs.setInt(
        'meitorrent_max_connections', state.maxGlobalConnections);

    await ref.read(torrentRepositoryProvider).applyEngineConfig(state);
  }
}
