import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../domain/repositories/torrent_repository.dart';
import '../../../torrent_list/presentation/controllers/torrent_notifier.dart';

part 'settings_notifier.g.dart';

/// Persists and applies engine configuration settings.
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  EngineConfig build() {
    // Start with defaults; in a real app these would be loaded from SharedPreferences.
    return const EngineConfig();
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
    await ref.read(torrentRepositoryProvider).applyEngineConfig(state);
  }
}
