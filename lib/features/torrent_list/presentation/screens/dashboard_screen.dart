import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/speed_formatter.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../controllers/torrent_notifier.dart';
import '../widgets/add_torrent_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/torrent_list_item.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _newlyAddedId;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    final torrentsAsync = ref.watch(torrentNotifierProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation(context);
      },
      child: Scaffold(
        extendBody: true,
        appBar: _buildAppBar(context, ref, torrentsAsync),
        body: torrentsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 2,
            ),
          ),
          error: (e, _) => _ErrorBody(error: e.toString()),
          data: (torrents) {
            if (torrents.isEmpty) return const EmptyStateWidget();
            
            return ListView.builder(
              itemCount: torrents.length,
              padding: const EdgeInsets.only(top: 8, bottom: 110),
              itemBuilder: (_, i) {
                final torrent = torrents[i];
                return TorrentListItem(
                  torrentId: torrent.id,
                  isNew: torrent.id == _newlyAddedId,
                );
              },
            );
          },
        ),
      floatingActionButton: _GradientFAB(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddTorrentDialog(
            onMagnetAdded: (uri, path) {
              ref
                  .read(torrentNotifierProvider.notifier)
                  .addMagnet(uri, savePath: path);
            },
            onFileAdded: (file, path) {
              ref
                  .read(torrentNotifierProvider.notifier)
                  .addTorrentFile(file, savePath: path);
            },
          ),
        ),
      ),
    ),
  );
}

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TorrentStatus>> async,
  ) {
    final selectedIds = ref.watch(selectedTorrentsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;
    final torrents = async.valueOrNull ?? [];

    if (isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => ref.read(selectedTorrentsProvider.notifier).clear(),
        ),
        title: Text('${selectedIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: 'Resume Selected',
            onPressed: () {
              final notifier = ref.read(torrentNotifierProvider.notifier);
              for (final id in selectedIds) {
                notifier.resumeTorrent(id);
              }
              ref.read(selectedTorrentsProvider.notifier).clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.pause_rounded),
            tooltip: 'Pause Selected',
            onPressed: () {
              final notifier = ref.read(torrentNotifierProvider.notifier);
              for (final id in selectedIds) {
                notifier.pauseTorrent(id);
              }
              ref.read(selectedTorrentsProvider.notifier).clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.stop_rounded),
            tooltip: 'Stop Selected',
            onPressed: () {
              final notifier = ref.read(torrentNotifierProvider.notifier);
              for (final id in selectedIds) {
                notifier.stopTorrent(id);
              }
              ref.read(selectedTorrentsProvider.notifier).clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5555)),
            tooltip: 'Delete Selected',
            onPressed: () => _confirmDeleteMultiple(context, ref, selectedIds.toList()),
          ),
        ],
      );
    }

    final totalDown = torrents.fold<int>(0, (s, t) => s + t.downloadSpeed);
    final totalUp = torrents.fold<int>(0, (s, t) => s + t.uploadSpeed);
    final active =
        torrents.where((t) => t.state == TorrentState.downloading).length;

    return AppBar(
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meitorrent'),
          if (active > 0)
            AnimatedOpacity(
              opacity: active > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        size: 10, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 2),
                    Text(
                      SpeedFormatter.format(totalDown),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_upward_rounded,
                        size: 10, color: Color(0xFF50FA7B)),
                    const SizedBox(width: 2),
                    Text(
                      SpeedFormatter.format(totalUp),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF50FA7B),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$active active',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                          fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          color: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            final notifier = ref.read(torrentNotifierProvider.notifier);
            switch (v) {
              case 'select_all':
                ref.read(selectedTorrentsProvider.notifier).selectAll(torrents.map((t) => t.id).toList());
                break;
              case 'resume_all':
                notifier.resumeAll();
                break;
              case 'pause_all':
                notifier.pauseAll();
                break;
              case 'stop_all':
                notifier.stopAll();
                break;
              case 'delete_all':
                _confirmDeleteMultiple(context, ref, torrents.map((t) => t.id).toList(), isAll: true);
                break;
              case 'exit_app':
                _showExitConfirmation(context);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'select_all',
              child: _MenuItem(icon: Icons.select_all_rounded, label: 'Select All'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'resume_all',
              child: _MenuItem(icon: Icons.play_circle_outline, label: 'Resume All'),
            ),
            const PopupMenuItem(
              value: 'pause_all',
              child: _MenuItem(icon: Icons.pause_circle_outline, label: 'Pause All'),
            ),
            const PopupMenuItem(
              value: 'stop_all',
              child: _MenuItem(icon: Icons.stop_circle_outlined, label: 'Stop All'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'delete_all',
              child: _MenuItem(
                icon: Icons.delete_sweep_outlined,
                label: 'Delete All',
                color: Color(0xFFFF5555),
              ),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'exit_app',
              child: _MenuItem(
                icon: Icons.exit_to_app_rounded,
                label: 'Exit App',
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFF6C63FF), size: 22),
            SizedBox(width: 10),
            Text('Exit Meitorrent?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to close the app? Active downloads will stop.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // 🛡️ Emergency save before hard exit
              ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
              exit(0);
            },
            child: const Text('Exit Now'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMultiple(BuildContext context, WidgetRef ref, List<String> ids, {bool isAll = false}) {
    if (ids.isEmpty) return;
    
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(isAll ? 'Delete All Torrents?' : 'Delete Selected?'),
        content: Text('Are you sure you want to remove ${ids.length} torrents?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref.read(torrentNotifierProvider.notifier).deleteMultiple(ids);
              ref.read(selectedTorrentsProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5555))),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color ?? Colors.white70, size: 20),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: color ?? Colors.white70)),
    ]);
  }
}

// ─── Gradient FAB ────────────────────────────────────────────────────────────

class _GradientFAB extends StatefulWidget {
  const _GradientFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GradientFAB> createState() => _GradientFABState();
}

class _GradientFABState extends State<_GradientFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onPressed();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Add Torrent',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Error body ──────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF5555), size: 52),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
