import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/oem_battery_guard.dart';

import '../../../../core/utils/speed_formatter.dart';
import '../controllers/settings_notifier.dart';

/// Settings screen — engine configuration, speed limits, protocol toggles.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Speed Limits ──────────────────────────────────────────
            const _SectionHeader(title: 'Speed Limits'),
            _SpeedLimitTile(
              icon: Icons.arrow_downward_rounded,
              iconColor: const Color(0xFF00B894),
              label: 'Download Limit',
              currentBps: config.downloadLimit,
              onChanged: notifier.setDownloadLimit,
            ),
            _SpeedLimitTile(
              icon: Icons.arrow_upward_rounded,
              iconColor: const Color(0xFF2ECC71),
              label: 'Upload Limit',
              currentBps: config.uploadLimit,
              onChanged: notifier.setUploadLimit,
            ),
  
            // ── Network ───────────────────────────────────────────────
            const _SectionHeader(title: 'Network'),
            _SwitchTile(
              icon: Icons.wifi,
              label: 'Wi-Fi Only Mode',
              subtitle: 'Pause downloads on mobile data',
              value: config.wifiOnlyMode,
              onChanged: notifier.setWifiOnly,
            ),
            _SwitchTile(
              icon: Icons.cloud_off_rounded,
              label: 'Stop Seeding',
              subtitle: 'Pause torrent when 100% complete',
              value: config.stopSeedingWhenFinished,
              onChanged: notifier.setStopSeeding,
            ),
            _SwitchTile(
              icon: Icons.hub_outlined,
              label: 'DHT',
              subtitle: 'Distributed peer discovery',
              value: config.dhtEnabled,
              onChanged: notifier.setDht,
            ),
            _SwitchTile(
              icon: Icons.swap_horiz_rounded,
              label: 'PEX',
              subtitle: 'Peer exchange protocol',
              value: config.pexEnabled,
              onChanged: notifier.setPex,
            ),
  
            // ── Connections ───────────────────────────────────────────
            const _SectionHeader(title: 'Connections'),
            _ConnectionsTile(
              current: config.maxGlobalConnections,
              onChanged: notifier.setMaxConnections,
            ),
  
            // ── Performance ───────────────────────────────────────────
            const _SectionHeader(title: 'Performance'),
            const _BatteryOptimizationTile(),
  
            // ── About ─────────────────────────────────────────────────
            const _SectionHeader(title: 'About'),
            _AboutTile(),
            const _LegalTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              content: _privacyPolicy,
            ),
            const _LegalTile(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              content: _termsAndConditions,
            ),
            const _LegalTile(
              icon: Icons.gavel_outlined,
              label: 'Open Source Licenses',
              content: _licenses,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF00B894),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Speed Limit Tile ─────────────────────────────────────────────────────────

class _SpeedLimitTile extends StatelessWidget {
  const _SpeedLimitTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.currentBps,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int currentBps;
  final Future<void> Function(int) onChanged;

  static const _presets = [0, 256, 512, 1024, 2048, 5120, 10240]; // KB/s
  static const _presetLabels = ['Unlimited', '256 KB/s', '512 KB/s', '1 MB/s', '2 MB/s', '5 MB/s', '10 MB/s'];

  @override
  Widget build(BuildContext context) {
    final displayLabel = currentBps == 0
        ? 'Unlimited'
        : SpeedFormatter.format(currentBps);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(displayLabel, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111721),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ...List.generate(_presets.length, (i) {
              final bps = _presets[i] * 1024;
              final selected = currentBps == bps;
              return ListTile(
                title: Text(_presetLabels[i],
                    style: TextStyle(
                        color: selected ? const Color(0xFF00B894) : Colors.white70,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                trailing: selected ? const Icon(Icons.check, color: Color(0xFF00B894), size: 18) : null,
                onTap: () {
                  onChanged(bps);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Switch Tile ──────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white54, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Max Connections Tile ─────────────────────────────────────────────────────

class _ConnectionsTile extends StatelessWidget {
  const _ConnectionsTile({required this.current, required this.onChanged});
  final int current;
  final Future<void> Function(int) onChanged;

  static const _options = [100, 200, 300, 500, 750, 1000];

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.people_outline, color: Colors.white54, size: 20),
      ),
      title: const Text('Max Connections', style: TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text('$current peers', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111721),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Max Global Connections',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ..._options.map((n) {
                final selected = current == n;
                return ListTile(
                  title: Text('$n peers',
                      style: TextStyle(
                          color: selected ? const Color(0xFF00B894) : Colors.white70,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  trailing: selected ? const Icon(Icons.check, color: Color(0xFF00B894), size: 18) : null,
                  onTap: () {
                    onChanged(n);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── About Tile ───────────────────────────────────────────────────────────────

class _AboutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B894), Color(0xFF00A382)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
      ),
      title: const Text(
        'Meitorrent',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 2),
          Text(
            'v1.0.0 · Fast. Private. Reliable.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          SizedBox(height: 1),
          Text(
            'Designed & Developed by MeiGamingOfficial',
            style: TextStyle(
              color: Color(0xFF00B894),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.icon, required this.label, required this.content});
  final IconData icon;
  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white54, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _LegalDetailScreen(title: label, content: content),
        ),
      ),
    );
  }
}

class _LegalDetailScreen extends StatelessWidget {
  const _LegalDetailScreen({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SelectableText(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.8,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

const _privacyPolicy = '''
Meitorrent is built, published, and maintained by MeiGamingOfficial. We respect your privacy completely and designed the app to function without collecting any user data.

• Zero Personal Data: No registration or account is required. We do not collect names, emails, or device identifiers.
• Zero Tracking: We do not track search, download, or usage histories.
• P2P Swarm Visibility: As a BitTorrent client, your IP address is visible to other peers downloading or seeding the same torrent. This is a protocol requirement.
• Permissions Used: Network/Internet (to connect to peers), Storage/Media Access (to save download files), Foreground Service (to keep downloads active in the background), and Notifications (to display real-time download speed in the notification bar).

For full details, visit our hosted policy at:
meigaming.github.io/meitorrent/PRIVACY_POLICY
''';

const _termsAndConditions = '''
By downloading, installing, or using Meitorrent, you agree to the following terms established by MeiGamingOfficial:

• Proper Use: You are solely and fully responsible for all files you choose to download or share.
• Copyright Compliance: You must not use this app to download or share copyrighted materials without legal authorization.
• Utility Tool Only: Meitorrent is a tool for P2P transfer; MeiGamingOfficial does not host, curate, or provide any torrent links or content.
• Liability Limitation: MeiGamingOfficial is not responsible for any misuse, data loss, or legal consequences arising from using this software.

The app is provided "AS IS" without warranties of any kind.
''';

const _licenses = '''
Meitorrent is built using several open-source components:

## libtorrent
This app is powered by libtorrent (BSD 3-clause). The Flutter wrapper and this application are subject to the GNU General Public License v3.0 (GPLv3).

## Other Components
- flutter_foreground_task (MIT)
- drift (MIT)
- flutter_riverpod (MIT)
- google_fonts (Apache 2.0)
- path_provider (BSD 3-clause)
- permission_handler (MIT)
- connectivity_plus (BSD 3-clause)

The full GPLv3 copy is available in the root LICENSE file of our repository.
''';

// ─── Battery Optimization Tile ───────────────────────────────────────────────

class _BatteryOptimizationTile extends StatefulWidget {
  const _BatteryOptimizationTile();

  @override
  State<_BatteryOptimizationTile> createState() => _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<_BatteryOptimizationTile> with WidgetsBindingObserver {
  bool _isIgnored = false;
  bool _isLoading = false;
  bool _showOemPrompt = false;
  String _oemName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
    _checkOem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final status = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (mounted) {
      setState(() {
        _isIgnored = status;
      });
    }
  }

  Future<void> _checkOem() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      
      const oems = {
        'xiaomi': 'Xiaomi', 'redmi': 'Redmi', 'poco': 'POCO',
        'oppo': 'Oppo', 'realme': 'Realme', 'oneplus': 'OnePlus',
        'vivo': 'Vivo', 'huawei': 'Huawei', 'honor': 'Honor',
        'samsung': 'Samsung'
      };
      
      if (oems.containsKey(manufacturer) && mounted) {
        setState(() {
          _showOemPrompt = true;
          _oemName = oems[manufacturer]!;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isIgnored ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
              color: _isIgnored ? const Color(0xFF00B894) : const Color(0xFFFFB86C),
              size: 20,
            ),
          ),
          title: const Text('Ignore Battery Optimizations', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(
            _isIgnored
                ? 'Battery optimizations are disabled'
                : 'Helps keep torrent downloads active when the app is in the background or screen is off',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B894)),
                )
              : Switch(
                  value: _isIgnored,
                  onChanged: (value) async {
                    setState(() => _isLoading = true);
                    if (value) {
                      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                    } else {
                      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
                    }
                    await _checkStatus();
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  },
                ),
        ),
        if (_showOemPrompt)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB86C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB86C).withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFFB86C), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Detected $_oemName Device',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your device enforces custom battery restrictions. For stable downloads, please set Meitorrent to "Unrestricted" and enable "Auto-start".',
                    style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => OemBatteryGuard.instance.promptIfNeeded(context, force: true),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Configure OEM Settings',
                            style: TextStyle(
                              color: Color(0xFF00B894),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Color(0xFF00B894), size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
