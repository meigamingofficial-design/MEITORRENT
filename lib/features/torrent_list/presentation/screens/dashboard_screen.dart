import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
import '../widgets/filter_segmented_control.dart';

import '../../../../core/services/permission_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  String? _newlyAddedId;
  int _zeroSpeedTicks = 0;
  bool _hasPromptedSpeedWarning = false;
  bool _isStorageGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkPermission());
    // Cold-start deep links
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialLink = DeepLinkService.instance.pendingInitialLink;
      if (initialLink != null) {
        DeepLinkService.instance.pendingInitialLink = null; // Consume
        _addDirectly(initialLink);
      }
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
      unawaited(_checkPermission());
    }
  }

  Future<void> _checkPermission() async {
    final granted = await PermissionService.isStorageGranted();
    if (mounted && _isStorageGranted != granted) {
      setState(() => _isStorageGranted = granted);
    }
  }

  void _addDirectly(String linkOrPath) async {
    if (!mounted) return;

    if (!_isStorageGranted) {
      final granted = await PermissionService.showStorageRationale(context);
      if (granted) {
        await Permission.manageExternalStorage.request();
        await _checkPermission();
      }
      return;
    }

    final isMagnet = linkOrPath.startsWith('magnet:');
    try {
      if (isMagnet) {
        await ref.read(torrentProvider.notifier).addMagnet(linkOrPath);
        if (mounted) {
          _showToast('Magnet link added successfully');
        }
      } else {
        await ref.read(torrentProvider.notifier).addTorrentFile(linkOrPath);
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
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddTorrentDialog(
    BuildContext context, [
    String? prefilledLinkOrPath,
  ]) async {
    if (!_isStorageGranted) {
      final granted = await PermissionService.showStorageRationale(context);
      if (granted) {
        await Permission.manageExternalStorage.request();
        await _checkPermission();
      }
      return;
    }

    final isMagnet =
        prefilledLinkOrPath != null &&
        prefilledLinkOrPath.startsWith('magnet:');
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTorrentDialog(
          initialMagnetUri: isMagnet ? prefilledLinkOrPath : null,
          initialTorrentFilePath: isMagnet ? null : prefilledLinkOrPath,
          onMagnetAdded: (uri, path) {
            unawaited(
              ref.read(torrentProvider.notifier).addMagnet(uri, savePath: path),
            );
          },
          onFileAdded: (file, path) {
            unawaited(
              ref
                  .read(torrentProvider.notifier)
                  .addTorrentFile(file, savePath: path),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<TorrentStatus>>>(torrentProvider, (
      prev,
      next,
    ) {
      final prevTorrents = prev?.value ?? [];
      final nextTorrents = next.value ?? [];

      // 1. Event-Driven Contextual Trigger on First Active Torrent Added
      if (prevTorrents.isEmpty && nextTorrents.isNotEmpty) {
        unawaited(OemBatteryGuard.instance.promptIfNeeded(context));
      }

      // 2. Failure Detection Loop
      final activeDownloading = nextTorrents
          .where((t) => t.state.isActive && !t.state.isFinished)
          .toList();
      if (activeDownloading.isNotEmpty) {
        final totalSpeed = activeDownloading.fold<int>(
          0,
          (s, t) => s + t.downloadSpeed,
        );
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

    final torrentsAsync = ref.watch(torrentProvider);
    final activeFilter = ref.watch(activeFilterProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final torrents = torrentsAsync.value ?? [];
        final hasActive = torrents.any(
          (t) => t.state.isActive && !t.state.isFinished,
        );

        if (!hasActive) {
          // If nothing is active, just minimize to background silently
          unawaited(
            SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
          );
          return;
        }

        // Check for remembered choice
        final prefs = await SharedPreferences.getInstance();
        final remembered = prefs.getString('meitorrent_exit_preference');

        if (remembered == 'background') {
          // 🚀 Native Pro Minimize: The most stable way for production
          await ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
          await const MethodChannel(
            'com.meigaming.meitorrent/files',
          ).invokeMethod('minimizeApp');
          FlutterForegroundTask.sendDataToTask({'minimize': true});
        } else if (remembered == 'exit') {
          await ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
          exit(0);
        } else {
          if (context.mounted) _showExitConfirmation(context);
        }
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
            final filtered = ref.watch(filteredTorrentsProvider);
            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (!_isStorageGranted)
                    SliverToBoxAdapter(
                      child: _PermissionBanner(
                        onTap: () => _showAddTorrentDialog(context),
                      ),
                    ),
                  if (torrents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(filter: activeFilter),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildHeader(context, torrents),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: EmptyStateWidget(filter: activeFilter),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final torrent = filtered[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: TorrentListItem(
                                torrentId: torrent.id,
                                isNew: torrent.id == _newlyAddedId,
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ],
              ),
            );
          },
        ),
        floatingActionButton: _GradientFAB(
          onPressed: () => _showAddTorrentDialog(context),
          isLocked: !_isStorageGranted,
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
    final isSelectionMode = ref
        .watch(selectedTorrentsProvider.notifier)
        .isSelectionMode;

    if (isSelectionMode) {
      final filtered = ref.watch(filteredTorrentsProvider);
      final allIds = filtered.map((t) => t.id).toList();
      final isAllSelected = allIds.isNotEmpty &&
          allIds.every((id) => selectedIds.contains(id));

      void toggleSelectAll() {
        if (isAllSelected) {
          ref.read(selectedTorrentsProvider.notifier).clear();
        } else {
          ref.read(selectedTorrentsProvider.notifier).selectAll(allIds);
        }
        unawaited(HapticFeedback.lightImpact());
      }

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
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary(context),
                    ),
                    onPressed: () =>
                        ref.read(selectedTorrentsProvider.notifier).clear(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedIds.length} Selected',
                      style: TextStyle(
                        fontFamily: 'ShipporiMincho',
                        color: AppColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SelectionAction(
                    icon: isAllSelected
                        ? Icons.select_all_rounded
                        : Icons.select_all_outlined,
                    color: isAllSelected
                        ? AppColors.downloading
                        : AppColors.textSecondary(context),
                    tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                    onPressed: toggleSelectAll,
                  ),
                  Builder(
                    builder: (ctx) {
                      // Derive state from the real torrent list so this
                      // toggle always syncs with the per-card icons.
                      final allTorrents =
                          ref.watch(torrentProvider).value ?? [];
                      final selected = allTorrents
                          .where((t) => selectedIds.contains(t.id))
                          .toList();

                      // ALL selected are paused/stopped → show Play
                      // ANY selected is actively running → show Pause
                      final allPausedOrStopped =
                          selected.isNotEmpty &&
                          selected.every((t) => t.isPaused || t.isStopped);

                      // Show Stop only when at least one is NOT already stopped
                      final anyNotStopped = selected.any((t) => !t.isStopped);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Play / Pause toggle ──────────────────────
                          if (allPausedOrStopped)
                            _SelectionAction(
                              icon: Icons.play_arrow_rounded,
                              tooltip: 'Resume',
                              onPressed: () async {
                                final notifier = ref.read(
                                  torrentProvider.notifier,
                                );
                                final ids = selectedIds.toList();
                                ref
                                    .read(selectedTorrentsProvider.notifier)
                                    .clear();
                                await notifier.resumeMultiple(ids);
                              },
                            )
                          else
                            _SelectionAction(
                              icon: Icons.pause_rounded,
                              tooltip: 'Pause',
                              onPressed: () async {
                                final notifier = ref.read(
                                  torrentProvider.notifier,
                                );
                                final ids = selectedIds.toList();
                                ref
                                    .read(selectedTorrentsProvider.notifier)
                                    .clear();
                                await notifier.pauseMultiple(ids);
                              },
                            ),
                          // ── Stop (only when something is stoppable) ──
                          if (anyNotStopped)
                            _SelectionAction(
                              icon: Icons.stop_rounded,
                              tooltip: 'Stop',
                              onPressed: () async {
                                final notifier = ref.read(
                                  torrentProvider.notifier,
                                );
                                final ids = selectedIds.toList();
                                ref
                                    .read(selectedTorrentsProvider.notifier)
                                    .clear();
                                await notifier.stopMultiple(ids);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  _SelectionAction(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    tooltip: 'Delete',
                    onPressed: () => _confirmDeleteMultiple(
                      context,
                      ref,
                      selectedIds.toList(),
                    ),
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
      title: const Text(
        'Meitorrent',
        style: TextStyle(
          fontFamily: 'ShipporiMincho',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => const SettingsScreen(),
              transitionsBuilder: (_, animation, _, child) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 220),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (v) {
            final torrents = async.value ?? [];
            switch (v) {
              case 'select':
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .enterSelectionMode();
              case 'select_all':
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .selectAll(torrents.map((t) => t.id).toList());
              case 'exit_app':
                _showExitConfirmation(context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'select',
              child: _MenuItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'Select',
              ),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'select_all',
              child: _MenuItem(
                icon: Icons.select_all_rounded,
                label: 'Select All',
              ),
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
    final activeCount = torrents
        .where((t) => t.state == TorrentState.downloading)
        .length;

    final isCompletedTab =
        ref.watch(activeFilterProvider) == TorrentFilter.completed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          // ── Compact glass stats bar ─────────────────────────────────
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ↓ Download
                const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.downloading,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  SpeedFormatter.format(downTotal.toInt()),
                  style: const TextStyle(
                    color: AppColors.downloading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // ↑ Upload
                const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.seeding,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  SpeedFormatter.format(upTotal.toInt()),
                  style: const TextStyle(
                    color: AppColors.seeding,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isCompletedTab) ...[
                  const Spacer(),
                  // Active count
                  Icon(
                    Icons.download_rounded,
                    color: AppColors.textSecondary(context),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$activeCount Active',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilterSegmentedControl(
            activeFilter: ref.watch(activeFilterProvider),
            onChanged: (filter) {
              ref.read(activeFilterProvider.notifier).setFilter(filter);
              unawaited(HapticFeedback.lightImpact());
            },
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    final torrents = ref.read(torrentProvider).value ?? [];
    final activeCount = torrents
        .where((t) => t.state.isActive && !t.state.isFinished)
        .length;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => _ExitDialog(
          activeCount: activeCount,
          onBackground: () async {
            await ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
            await const MethodChannel(
              'com.meigaming.meitorrent/files',
            ).invokeMethod('minimizeApp');
            FlutterForegroundTask.sendDataToTask({'minimize': true});
          },
          onExit: () async {
            await ref.read(torrentRepositoryProvider).forceSaveAllResumeData();
            exit(0);
          },
        ),
      ),
    );
  }

  void _confirmDeleteMultiple(
    BuildContext context,
    WidgetRef ref,
    List<String> ids, {
    bool isAll = false,
  }) {
    if (ids.isEmpty) return;

    bool deleteFiles = false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: AppColors.surface(context),
              title: Row(
                children: [
                  const Icon(
                    Icons.delete_sweep_outlined,
                    color: AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAll ? 'Delete All Torrents?' : 'Delete Selected?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAll
                        ? 'This will remove all torrents from your list.'
                        : 'Remove ${ids.length} selected torrent${ids.length == 1 ? '' : 's'}?',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setDialogState(() => deleteFiles = !deleteFiles),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: deleteFiles,
                              onChanged: (v) =>
                                  setDialogState(() => deleteFiles = v ?? false),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              activeColor: AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Also delete downloaded files',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Permanently erase files from storage',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(torrentProvider.notifier)
                          .deleteMultiple(ids, deleteFiles: deleteFiles);
                    } catch (_) {}
                    ref.read(selectedTorrentsProvider.notifier).clear();
                  },
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBackgroundWarningPrompt(BuildContext context) async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyDismissed =
          prefs.getBool('meitorrent_speed_warning_dismissed') ?? false;
      if (alreadyDismissed) return;
    } catch (_) {}

    if (!context.mounted) return;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.paused,
                        size: 20,
                      ),
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'meitorrent_speed_warning_dismissed',
                              true,
                            );
                          } catch (_) {}
                        },
                        child: const Text(
                          'Not Now',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.downloading,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'meitorrent_speed_warning_dismissed',
                              true,
                            );
                          } catch (_) {}
                          if (context.mounted) {
                            unawaited(
                              Navigator.push(
                                context,
                                PageRouteBuilder<void>(
                                  pageBuilder: (_, _, _) =>
                                      const SettingsScreen(),
                                  transitionsBuilder: (_, animation, _, child) =>
                                      FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut,
                                        ),
                                        child: child,
                                      ),
                                  transitionDuration: const Duration(
                                    milliseconds: 220,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Optimize Speed',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
              child: Icon(
                icon,
                color: color ?? AppColors.text(context),
                size: 22,
              ),
            ),
          ),
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
  const _GradientFAB({required this.onPressed, this.isLocked = false});
  final VoidCallback onPressed;
  final bool isLocked;

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
    final bgColor = widget.isLocked ? Colors.transparent : null;
    final border = widget.isLocked
        ? Border.all(color: AppColors.border(context))
        : null;
    final shadow = widget.isLocked
        ? null
        : [
            BoxShadow(
              color: AppColors.downloading.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.downloading.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
    final textColor = widget.isLocked
        ? AppColors.textSecondary(context)
        : Colors.white;
    final iconColor = widget.isLocked
        ? AppColors.textSecondary(context)
        : Colors.white;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => unawaited(_ctrl.reverse()),
        onTapUp: (_) {
          unawaited(_ctrl.forward());
          widget.onPressed();
        },
        onTapCancel: () => unawaited(_ctrl.forward()),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.isLocked ? null : AppGradients.primary,
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: shadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.add_rounded,
                  color: iconColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Torrent',
                  style: TextStyle(
                    fontFamily: 'ShipporiMincho',
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paused.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.paused.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.paused,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limited Mode',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Storage access is required to download and manage files.',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitDialog extends StatefulWidget {
  const _ExitDialog({
    required this.onBackground,
    required this.onExit,
    required this.activeCount,
  });

  final Future<void> Function() onBackground;
  final Future<void> Function() onExit;
  final int activeCount;

  @override
  State<_ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<_ExitDialog> {
  bool _remember = false;
  String _selectedOption = 'background'; // Default

  Future<void> _savePreference(String choice) async {
    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('meitorrent_exit_preference', choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exit Meitorrent?',
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.activeCount > 0
                  ? '${widget.activeCount} download${widget.activeCount == 1 ? ' is' : 's are'} currently active.'
                  : 'Choose what you want to do.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Background Option
            _ExitOption(
              icon: Icons.bolt_rounded,
              title: 'Run in Background',
              description: 'Downloads continue with notification support.',
              color: AppColors.downloading,
              isSelected: _selectedOption == 'background',
              onTap: () => setState(() => _selectedOption = 'background'),
            ),
            const SizedBox(height: 12),

            // Exit Option
            _ExitOption(
              icon: Icons.power_settings_new_outlined,
              title: 'Exit Completely',
              description: 'Stop downloads and exit application.',
              color: AppColors.error,
              isSelected: _selectedOption == 'exit',
              onTap: () => setState(() => _selectedOption = 'exit'),
            ),
            const SizedBox(height: 18),

            // Remember choice
            InkWell(
              onTap: () => setState(() => _remember = !_remember),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        activeColor: AppColors.downloading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Remember my choice',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.border(context)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await _savePreference(_selectedOption);
                      if (context.mounted) Navigator.pop(context);
                      if (_selectedOption == 'background') {
                        await widget.onBackground();
                      } else {
                        await widget.onExit();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedOption == 'background'
                          ? AppColors.downloading
                          : AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

class _ExitOption extends StatelessWidget {
  const _ExitOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    required this.isSelected,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.08)
                  : AppColors.border(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? color
                    : AppColors.border(context).withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
