import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/oem_battery_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../controllers/torrent_notifier.dart';
import '../widgets/add_torrent_dialog.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/torrent_list_item.dart';
import '../../../../core/utils/speed_formatter.dart';
import '../../../../core/services/deep_link_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _newlyAddedId;
  int _zeroSpeedTicks = 0;
  bool _hasPromptedSpeedWarning = false;

  @override
  void initState() {
    super.initState();
    // Cold-start deep links: handle preloaded torrents once DashboardScreen is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialLink = DeepLinkService.instance.pendingInitialLink;
      if (initialLink != null) {
        DeepLinkService.instance.pendingInitialLink = null; // Consume
        _addDirectly(initialLink);
      }
    });
  }

  void _addDirectly(String linkOrPath) async {
    if (!mounted) return;

    final isMagnet = linkOrPath.startsWith('magnet:');
    try {
      if (isMagnet) {
        await ref
            .read(torrentNotifierProvider.notifier)
            .addMagnet(linkOrPath);
        if (mounted) {
          _showToast('Magnet link added successfully');
        }
      } else {
        await ref
            .read(torrentNotifierProvider.notifier)
            .addTorrentFile(linkOrPath);
        if (mounted) {
          _showToast('Torrent file added successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to add torrent: $e', isError: true);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? AppColors.error : const Color(0xFF2ECC71),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppColors.text(context)),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddTorrentDialog(BuildContext context, [String? prefilledLinkOrPath]) {
    final isMagnet = prefilledLinkOrPath != null && prefilledLinkOrPath.startsWith('magnet:');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTorrentDialog(
        initialMagnetUri: isMagnet ? prefilledLinkOrPath : null,
        initialTorrentFilePath: isMagnet ? null : prefilledLinkOrPath,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<TorrentStatus>>>(torrentNotifierProvider,
        (prev, next) {
      final prevTorrents = prev?.valueOrNull ?? [];
      final nextTorrents = next.valueOrNull ?? [];

      // 1. Event-Driven Contextual Trigger on First Active Torrent Added
      if (prevTorrents.isEmpty && nextTorrents.isNotEmpty) {
        OemBatteryGuard.instance.promptIfNeeded(context);
      }

      // 2. Failure Detection Loop (Agonistic Speed Throttling)
      final activeDownloading = nextTorrents
          .where((t) => t.state.isActive && !t.state.isFinished)
          .toList();
      if (activeDownloading.isNotEmpty) {
        final totalSpeed =
            activeDownloading.fold<int>(0, (s, t) => s + t.downloadSpeed);
        if (totalSpeed == 0) {
          _zeroSpeedTicks++;
          if (_zeroSpeedTicks >= 15) {
            _zeroSpeedTicks = 0;
            if (!_hasPromptedSpeedWarning) {
              _hasPromptedSpeedWarning = true;
              _showBackgroundWarningPrompt(context);
            }
          }
        } else {
          _zeroSpeedTicks = 0;
        }
      } else {
        _zeroSpeedTicks = 0;
      }
    });

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
              color: AppColors.downloading,
              strokeWidth: 2,
            ),
          ),
          error: (e, _) => _ErrorBody(error: e.toString()),
          data: (torrents) {
            if (torrents.isEmpty) {
              return const SafeArea(child: EmptyStateWidget());
            }

            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildHeader(context, torrents),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final torrent = torrents[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: TorrentListItem(
                            torrentId: torrent.id,
                            isNew: torrent.id == _newlyAddedId,
                          ),
                        );
                      },
                      childCount: torrents.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              ),
            );
          },
        ),
        floatingActionButton: _GradientFAB(
          onPressed: () => _showAddTorrentDialog(context),
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

    if (isSelectionMode) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 50),
        child: SafeArea(
          bottom: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.downloading.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.downloading.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary(context)),
                    onPressed: () =>
                        ref.read(selectedTorrentsProvider.notifier).clear(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${selectedIds.length} Selected',
                      style: GoogleFonts.shipporiMincho(
                        color: AppColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SelectionAction(
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Resume',
                    onPressed: () async {
                      final notifier = ref.read(torrentNotifierProvider.notifier);
                      final ids = selectedIds.toList();
                      ref.read(selectedTorrentsProvider.notifier).clear();
                      await Future.wait(
                          ids.map((id) => notifier.resumeTorrent(id)));
                    },
                  ),
                  _SelectionAction(
                    icon: Icons.pause_rounded,
                    tooltip: 'Pause',
                    onPressed: () async {
                      final notifier = ref.read(torrentNotifierProvider.notifier);
                      final ids = selectedIds.toList();
                      ref.read(selectedTorrentsProvider.notifier).clear();
                      await Future.wait(
                          ids.map((id) => notifier.pauseTorrent(id)));
                    },
                  ),
                  _SelectionAction(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop',
                    onPressed: () async {
                      final notifier = ref.read(torrentNotifierProvider.notifier);
                      final ids = selectedIds.toList();
                      ref.read(selectedTorrentsProvider.notifier).clear();
                      await Future.wait(
                          ids.map((id) => notifier.stopTorrent(id)));
                    },
                  ),
                  _SelectionAction(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    tooltip: 'Delete',
                    onPressed: () => _confirmDeleteMultiple(
                        context, ref, selectedIds.toList()),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'Meitorrent',
        style: GoogleFonts.shipporiMincho(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            final torrents = async.valueOrNull ?? [];
            switch (v) {
              case 'select':
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .enterSelectionMode();
                break;
              case 'select_all':
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .selectAll(torrents.map((t) => t.id).toList());
                break;
              case 'exit_app':
                _showExitConfirmation(context);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'select',
              child: _MenuItem(
                  icon: Icons.check_circle_outline_rounded, label: 'Select'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'select_all',
              child: _MenuItem(
                  icon: Icons.select_all_rounded, label: 'Select All'),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'exit_app',
              child: _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Exit App',
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, List<TorrentStatus> torrents) {
    final downTotal = torrents.fold<double>(0, (p, c) => p + c.downloadSpeed);
    final upTotal = torrents.fold<double>(0, (p, c) => p + c.uploadSpeed);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Row(
        children: [
          _CompactSpeedTile(
            icon: Icons.arrow_downward_rounded,
            value: SpeedFormatter.format(downTotal.toInt()),
            label: 'Total Down',
            color: AppColors.downloading,
          ),
          const SizedBox(width: 12),
          _CompactSpeedTile(
            icon: Icons.arrow_upward_rounded,
            value: SpeedFormatter.format(upTotal.toInt()),
            label: 'Total Up',
            color: AppColors.seeding,
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Exit Meitorrent?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text(
          'This will stop all active downloads and completely close the application.',
          style:
              TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
              exit(0);
            },
            child: const Text('Exit Now'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMultiple(
      BuildContext context, WidgetRef ref, List<String> ids,
      {bool isAll = false}) {
    if (ids.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined,
                color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Text(isAll ? 'Delete All Torrents?' : 'Delete Selected?',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          isAll
              ? 'This will remove all torrents from your list.'
              : 'Remove ${ids.length} selected torrents?',
          style:
              TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(torrentNotifierProvider.notifier).deleteMultiple(ids);
              ref.read(selectedTorrentsProvider.notifier).clear();
            },
            child: const Text('Remove Only'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(torrentNotifierProvider.notifier)
                  .deleteMultiple(ids, deleteFiles: true);
              ref.read(selectedTorrentsProvider.notifier).clear();
            },
            child: const Text('Remove + Files'),
          ),
        ],
      ),
    );
  }

  void _showBackgroundWarningPrompt(BuildContext context) async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyDismissed = prefs.getBool('meitorrent_speed_warning_dismissed') ?? false;
      if (alreadyDismissed) return;
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.paused.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paused.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: AppColors.paused, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sluggish Download Speeds?',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your downloads may be throttled or paused by system battery limits. Whitelisting Meitorrent helps keep transfers active when the screen is locked.',
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                  height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('meitorrent_speed_warning_dismissed', true);
                      } catch (_) {}
                    },
                    child: const Text('Not Now',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.downloading,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('meitorrent_speed_warning_dismissed', true);
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen()),
                        );
                      }
                    },
                    child: const Text('Optimize Speed',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              child:
                  Icon(icon, color: color ?? AppColors.text(context), size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSpeedTile extends StatelessWidget {
  const _CompactSpeedTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Color.alphaBlend(color.withValues(alpha: 0.15), AppColors.surface(context))
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final c = color ?? AppColors.text(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c.withValues(alpha: 0.75), size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

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
            borderRadius: BorderRadius.circular(12), // Hanko stamp shape
            boxShadow: [
              BoxShadow(
                color: AppColors.downloading.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Add Torrent',
                  style: GoogleFonts.shipporiMincho(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
                color: AppColors.error, size: 52),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
