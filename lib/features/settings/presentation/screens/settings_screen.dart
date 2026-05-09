import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/oem_battery_guard.dart';

import '../../../../core/utils/speed_formatter.dart';
import '../controllers/settings_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_service.dart';

/// Settings screen — engine configuration, speed limits, protocol toggles.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final isDark = ref.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Appearance ────────────────────────────────────────────
            const _SectionHeader(title: 'Appearance'),
            _SwitchTile(
              icon: Icons.dark_mode_outlined,
              label: 'Dark Mode',
              subtitle: 'Use a darker sumi-e aesthetic',
              value: isDark,
              onChanged: (_) async =>
                  ref.read(themeServiceProvider.notifier).toggle(),
            ),

            // ── Speed Limits ──────────────────────────────────────────
            const _SectionHeader(title: 'Speed Limits'),
            _SpeedLimitTile(
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.downloading,
              label: 'Download Limit',
              currentBps: config.downloadLimit,
              onChanged: notifier.setDownloadLimit,
            ),
            _SpeedLimitTile(
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.seeding,
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
              assetPath: 'PRIVACY_POLICY.md',
            ),
            const _LegalTile(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              assetPath: 'TERMS.md',
            ),
            const _LegalTile(
              icon: Icons.gavel_outlined,
              label: 'Open Source Licenses',
              assetPath: 'LICENSES.md',
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
          color: AppColors.downloading,
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
  static const _presetLabels = [
    'Unlimited',
    '256 KB/s',
    '512 KB/s',
    '1 MB/s',
    '2 MB/s',
    '5 MB/s',
    '10 MB/s'
  ];

  @override
  Widget build(BuildContext context) {
    final displayLabel =
        currentBps == 0 ? 'Unlimited' : SpeedFormatter.format(currentBps);

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
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text(context))),
      subtitle: Text(displayLabel,
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary(context), size: 18),
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
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            ...List.generate(_presets.length, (i) {
              final bps = _presets[i] * 1024;
              final selected = currentBps == bps;
              return ListTile(
                title: Text(_presetLabels[i],
                    style: TextStyle(
                        color: selected
                            ? AppColors.downloading
                            : AppColors.textSecondary(context),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal)),
                trailing: selected
                    ? const Icon(Icons.check,
                        color: AppColors.downloading, size: 18)
                    : null,
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
          color: AppColors.border(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary(context), size: 20),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text(context))),
      subtitle: Text(subtitle,
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
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
          color: AppColors.border(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.people_outline,
            color: AppColors.textSecondary(context), size: 20),
      ),
      title: Text('Max Connections', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text(context))),
      subtitle: Text('$current peers',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary(context), size: 18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Max Global Connections',
                    style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              ..._options.map((n) {
                final selected = current == n;
                return ListTile(
                  title: Text('$n peers',
                      style: TextStyle(
                          color: selected
                              ? AppColors.downloading
                              : AppColors.textSecondary(context),
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal)),
                  trailing: selected
                      ? const Icon(Icons.check,
                          color: AppColors.downloading, size: 18)
                      : null,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border(context).withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text(
        'Meitorrent',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text(context),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Text(
            'v1.0.0 · Fast. Private. Reliable.',
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
          ),
          const SizedBox(height: 1),
          const Text(
            'Designed & Developed by MeiGamingOfficial',
            style: TextStyle(
              color: AppColors.downloading,
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
  const _LegalTile({
    required this.icon,
    required this.label,
    required this.assetPath,
  });
  final IconData icon;
  final String label;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.border(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary(context), size: 20),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text(context))),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary(context), size: 18),
      onTap: () async {
        try {
          final content =
              await DefaultAssetBundle.of(context).loadString(assetPath);
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    _LegalDetailScreen(title: label, content: content),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading $label: $e')),
            );
          }
        }
      },
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
        title: Text(title,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SelectableText(
          content,
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 14,
            height: 1.8,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─── Battery Optimization Tile ───────────────────────────────────────────────

class _BatteryOptimizationTile extends StatefulWidget {
  const _BatteryOptimizationTile();

  @override
  State<_BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<_BatteryOptimizationTile>
    with WidgetsBindingObserver {
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
        'xiaomi': 'Xiaomi',
        'redmi': 'Redmi',
        'poco': 'POCO',
        'oppo': 'Oppo',
        'realme': 'Realme',
        'oneplus': 'OnePlus',
        'vivo': 'Vivo',
        'huawei': 'Huawei',
        'honor': 'Honor',
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
              color: AppColors.border(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isIgnored
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_alert_rounded,
              color: _isIgnored ? AppColors.seeding : AppColors.paused,
              size: 20,
            ),
          ),
          title: Text('Ignore Battery Optimizations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text(context))),
          subtitle: Text(
            _isIgnored
                ? 'Battery optimizations are disabled'
                : 'Helps keep torrent downloads active when the app is in the background or screen is off',
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
          ),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.downloading),
                )
              : Switch(
                  value: _isIgnored,
                  onChanged: (value) async {
                    setState(() => _isLoading = true);
                    if (value) {
                      await FlutterForegroundTask
                          .requestIgnoreBatteryOptimization();
                    } else {
                      await FlutterForegroundTask
                          .openIgnoreBatteryOptimizationSettings();
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
                color: AppColors.paused.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.paused.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.paused, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Detected $_oemName Device',
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your device enforces custom battery restrictions. For stable downloads, please set Meitorrent to "Unrestricted" and enable "Auto-start".',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => OemBatteryGuard.instance
                        .promptIfNeeded(context, force: true),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Configure OEM Settings',
                            style: TextStyle(
                              color: AppColors.downloading,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              color: AppColors.downloading, size: 12),
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
