import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

/// Detects OEM-specific battery managers and prompts the user to
/// whitelist Meitorrent in the OEM battery settings (Hardening #2).
class OemBatteryGuard {
  OemBatteryGuard._();
  static final OemBatteryGuard instance = OemBatteryGuard._();

  static const _oemIntents = <String, String>{
    'xiaomi': 'com.miui.securitycenter',
    'redmi': 'com.miui.securitycenter',
    'poco': 'com.miui.securitycenter',
    'oppo': 'com.coloros.oppoguardelf',
    'realme': 'com.coloros.oppoguardelf',
    'vivo': 'com.vivo.abe',
    'huawei': 'com.huawei.systemmanager',
    'honor': 'com.huawei.systemmanager',
    'samsung': 'com.samsung.android.lool',
    'oneplus': 'com.oneplus.security',
  };

  static const _oemNames = <String, String>{
    'xiaomi': 'MIUI',
    'redmi': 'MIUI',
    'poco': 'MIUI',
    'oppo': 'ColorOS',
    'realme': 'ColorOS',
    'vivo': 'VivoOS',
    'huawei': 'EMUI/HarmonyOS',
    'honor': 'EMUI/HarmonyOS',
    'samsung': 'OneUI',
    'oneplus': 'OxygenOS',
  };

  static const _platform = MethodChannel('com.meigaming.meitorrent/oem');

  /// Returns whether a given manufacturer is a known OEM with custom battery savers.
  bool isSupportedOem(String manufacturer) {
    return _oemIntents.containsKey(manufacturer.toLowerCase());
  }

  /// Returns the custom OS name for a given manufacturer.
  String? getOemName(String manufacturer) {
    return _oemNames[manufacturer.toLowerCase()];
  }

  Future<void> promptIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();

    final intent = _oemIntents[manufacturer];
    final oemName = _oemNames[manufacturer];

    if (intent != null && oemName != null) {
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final shown = prefs.getBool('meitorrent_oem_prompt_shown') ?? false;
        if (shown) return;
        await prefs.setBool('meitorrent_oem_prompt_shown', true);
      }

      AppLogger.i('[OemGuard] Detected OEM: $oemName ($manufacturer)');
      if (context.mounted) {
        _showOemBottomSheet(context, oemName, intent);
      }
    }
  }

  void _showOemBottomSheet(
    BuildContext context,
    String oemName,
    String packageName,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) =>
            _OemPromptSheet(oemName: oemName, packageName: packageName),
      ),
    );
  }

  /// Launches the OEM battery management app via platform channel.
  static Future<void> launchOemSettings(String packageName) async {
    try {
      await _platform.invokeMethod('launchOemSettings', {
        'package': packageName,
      });
    } on PlatformException catch (e) {
      AppLogger.w('[OemGuard] Failed to launch OEM settings', error: e);
    }
  }
}

class _OemPromptSheet extends StatelessWidget {
  const _OemPromptSheet({required this.oemName, required this.packageName});

  final String oemName;
  final String packageName;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + mediaQuery.viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.85,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.battery_alert,
                        color: Color(0xFFFFB86C),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enable Background Access ($oemName)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your device\'s battery manager may stop Meitorrent while '
                    'it\'s downloading in the background. To ensure '
                    'uninterrupted downloads:',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const _Step(number: '1', text: 'Open Battery Settings below'),
                  const _Step(
                    number: '2',
                    text: 'Find Meitorrent in the app list',
                  ),
                  const _Step(
                    number: '3',
                    text: 'Set to "No restrictions" or "Unrestricted"',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white54,
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            unawaited(
                              OemBatteryGuard.launchOemSettings(packageName),
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Battery Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B894),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF00B894),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
