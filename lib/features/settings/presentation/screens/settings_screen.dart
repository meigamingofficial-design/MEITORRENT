import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      title: const Text('Meitorrent', style: TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: const Text('v1.0.0 · Fast. Private. Reliable.',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
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
Meitorrent is designed with privacy in mind. We do not collect, store, or share any personal information on any central servers.

• Data Collection: We do not collect names, emails, or account information.
• P2P Networking: As a BitTorrent client, your IP address is visible to other peers in the swarm. This is a technical requirement of the protocol.
• Third-Party Services: We use Google Fonts, which may fetch assets from Google servers.
• Storage: Accessed only to manage the files you choose to download.

For full details, visit our hosted policy at meigaming.github.io/meitorrent/PRIVACY_POLICY
''';

const _termsAndConditions = '''
By using Meitorrent, you agree to the following:

• Proper Use: You are solely responsible for the content you download or share.
• Copyright: You must not use this app for illegal distribution of copyrighted material.
• Tool Only: Meitorrent is a tool for P2P transfer; we do not host or provide any content.
• Liability: The developer is not responsible for any misuse or legal consequences.

The app is provided "AS IS" without warranties of any kind.
''';

const _licenses = '''
Meitorrent is built using several open-source components.

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

The full text of the GPLv3 and other licenses are available in the root of our repository.
''';
