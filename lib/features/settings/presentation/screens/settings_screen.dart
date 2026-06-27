import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/package_info_provider.dart';
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
    final config = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = ref.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
            fontSize: 28,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Appearance ────────────────────────────────────────────
            const _SectionHeader(title: 'Appearance'),
            _SettingsGroupCard(
              children: [
                _SwitchTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  subtitle: 'Use a darker sumi-e aesthetic',
                  value: isDark,
                  onChanged: (_) async =>
                      ref.read(themeServiceProvider.notifier).toggle(),
                ),
              ],
            ),

            // ── Speed Limits ──────────────────────────────────────────
            const _SectionHeader(title: 'Speed Limits'),
            _SettingsGroupCard(
              children: [
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
              ],
            ),

            // ── Network ───────────────────────────────────────────────
            const _SectionHeader(title: 'Network'),
            _SettingsGroupCard(
              children: [
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
              ],
            ),

            // ── Connections ───────────────────────────────────────────
            const _SectionHeader(title: 'Connections'),
            _SettingsGroupCard(
              children: [
                _ConnectionsTile(
                  current: config.maxGlobalConnections,
                  onChanged: notifier.setMaxConnections,
                ),
              ],
            ),

            // ── Performance ───────────────────────────────────────────
            const _SectionHeader(title: 'Performance'),
            const _SettingsGroupCard(
              children: [
                _BatteryOptimizationTile(),
                _NotificationSettingsTile(),
              ],
            ),

            // ── Maintenance ──────────────────────────────────────────
            if (kDebugMode) ...[
              const _SectionHeader(title: 'Maintenance'),
              _SettingsGroupCard(
                children: [
                  _SwitchTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Detailed Logging',
                    subtitle: 'Send non-fatal errors to Crashlytics',
                    value: true, // Always on for now
                    onChanged: (_) async {},
                  ),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.paused.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.paused.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: AppColors.paused,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Test Crash',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    subtitle: Text(
                      'Force a crash to test Firebase integration',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      AppLogger.wtf('User triggered a manual test crash');
                      throw Exception('Meitorrent Crash Test: ${DateTime.now()}');
                    },
                  ),
                ],
              ),
            ],

            // ── About ─────────────────────────────────────────────────
            const _SectionHeader(title: 'About'),
            const _AboutCard(),
            _SettingsGroupCard(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 16,
                  ),
                  onTap: () => _launchUrl('https://meigamingofficial-design.github.io/MEITORRENT/privacy-policy.html'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 16,
                  ),
                  onTap: () => _launchUrl('https://meigamingofficial-design.github.io/MEITORRENT/terms.html'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.gavel_outlined,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Open Source Licenses',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 18,
                  ),
                  onTap: () => showLicensePage(context: context),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.language_outlined,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Official Website',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 16,
                  ),
                  onTap: () => _launchUrl('https://meigamingofficial-design.github.io/MEITORRENT/'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.copyright_outlined,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'GNU GPL v3.0 License',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 16,
                  ),
                  onTap: () => _launchUrl('https://www.gnu.org/licenses/gpl-3.0.en.html'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.downloading.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.downloading.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.downloading,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Contact Support',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                  subtitle: Text(
                    'meigaming.official@gmail.com',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.7),
                    size: 18,
                  ),
                  onTap: () => _launchUrl('mailto:meigaming.official@gmail.com'),
                ),
              ],
            ),
            const SizedBox(height: 60),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    '10 MB/s',
  ];

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
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary(context),
        size: 18,
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...List.generate(_presets.length, (i) {
                  final bps = _presets[i] * 1024;
                  final selected = currentBps == bps;
                  return ListTile(
                    title: Text(
                      _presetLabels[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? AppColors.downloading
                            : AppColors.textSecondary(context),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.downloading,
                            size: 18,
                          )
                        : null,
                    onTap: () {
                      unawaited(onChanged(bps));
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
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
    final iconBgColor = AppColors.textSecondary(context).withValues(alpha: 0.08);
    final iconColor = AppColors.textSecondary(context).withValues(alpha: 0.8);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconBgColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final iconBgColor = AppColors.textSecondary(context).withValues(alpha: 0.08);
    final iconColor = AppColors.textSecondary(context).withValues(alpha: 0.8);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconBgColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.people_outline,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Max Connections',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$current peers',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary(context),
        size: 18,
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                  child: Text(
                    'Max Global Connections',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ..._options.map((n) {
                  final selected = current == n;
                  return ListTile(
                    title: Text(
                      '$n peers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? AppColors.downloading
                            : AppColors.textSecondary(context),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.downloading,
                            size: 18,
                          )
                        : null,
                    onTap: () {
                      unawaited(onChanged(n));
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Settings Group Card ─────────────────────────────────────────────────────

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: AppColors.surface(context),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (context, index) => Divider(
              color: AppColors.border(context).withValues(alpha: 0.6),
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ),
    );
  }
}

// ─── About Card ──────────────────────────────────────────────────────────────

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border(context),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Meitorrent',
            style: TextStyle(
              fontFamily: 'ShipporiMincho',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            versionAsync.when(
              data: (v) => 'Version $v',
              loading: () => 'Version Loading...',
              error: (_, _) => 'Version 1.0.7+8',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.downloading.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Designed & Developed by MeiGamingOfficial',
              style: TextStyle(
                color: AppColors.downloading,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A premium, hand-crafted Android torrent client powered by a native C++ Core, styled with a traditional Sumi-e Parchment aesthetic.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchUrl(String urlString) async {
  try {
    final uri = Uri.parse(urlString);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not launch $urlString: $e');
  }
}




// The previous local Markdown viewer classes were removed as privacy policy,
// terms and conditions are now opened via web URL, and licenses via showLicensePage.

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
    // Defer heavy async platform-channel calls to after the first frame
    // so they never block the navigation transition animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkStatus());
      unawaited(_checkOem());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkStatus());
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
      final manufacturer = (androidInfo.manufacturer).toLowerCase();
      debugPrint('Detected manufacturer: $manufacturer');

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
        'samsung': 'Samsung',
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
    final statusColor = _isIgnored ? AppColors.seeding : AppColors.paused;
    final iconBgColor = statusColor.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconBgColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              _isIgnored
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_alert_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ignore Battery Optimizations',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Helps keep torrent downloads active when the app is in the background or screen is off',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.downloading,
                  ),
                )
              : _isIgnored
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.seeding,
                      size: 20,
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary(context),
                      size: 18,
                    ),
          onTap: _isLoading || _isIgnored
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    final ignored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
                    if (!ignored) {
                      final success = await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                      if (!success) {
                        await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
                      }
                    }
                  } catch (_) {
                    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
                  }
                  await _checkStatus();
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                },
        ),
        if (_showOemPrompt)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paused.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.paused.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.paused,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Detected $_oemName Device',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => OemBatteryGuard.instance.promptIfNeeded(
                      context,
                      force: true,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Configure OEM Settings',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.downloading,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.downloading,
                            size: 12,
                          ),
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

// ─── Notification Settings Tile ──────────────────────────────────────────────

class _NotificationSettingsTile extends StatefulWidget {
  const _NotificationSettingsTile();

  @override
  State<_NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<_NotificationSettingsTile>
    with WidgetsBindingObserver {
  bool _isGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkStatus());
    }
  }

  Future<void> _checkStatus() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (mounted) {
      setState(() {
        _isGranted = status == NotificationPermission.granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isGranted ? AppColors.seeding : AppColors.paused;
    final iconBgColor = statusColor.withValues(alpha: 0.08);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconBgColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(
          _isGranted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Download Notifications',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isGranted
                ? 'Show progress and transfer speeds in status bar'
                : 'Notifications are disabled. Tap to enable in settings.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary(context),
        size: 18,
      ),
      onTap: () async {
        await OemBatteryGuard.openNotificationSettings();
      },
    );
  }
}
