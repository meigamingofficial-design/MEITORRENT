import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/folder_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/size_formatter.dart';
import '../../../../core/utils/speed_formatter.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../controllers/torrent_notifier.dart';

/// Shared placeholder used by both the list item and action buttons
/// while the real torrent data is still loading.
TorrentStatus _placeholder(String id) => TorrentStatus(
  id: id,
  name: '…',
  progress: 0,
  downloadSpeed: 0,
  uploadSpeed: 0,
  peers: 0,
  seeds: 0,
  state: TorrentState.unknown,
  totalSize: 0,
  downloadedBytes: 0,
  uploadedBytes: 0,
  savePath: '',
  addedAt: DateTime.now(),
  lastActivityAt: DateTime.now(),
  ratio: 0,
);

/// Premium glassmorphism torrent card.
/// Uses `.select()` — only rebuilds when THIS torrent's data changes.
class TorrentListItem extends ConsumerStatefulWidget {
  const TorrentListItem({
    super.key,
    required this.torrentId,
    this.isNew = false,
  });

  final String torrentId;

  /// When true, a brief highlight glow plays to signal a newly-added torrent.
  final bool isNew;

  @override
  ConsumerState<TorrentListItem> createState() => _TorrentListItemState();
}

class _TorrentListItemState extends ConsumerState<TorrentListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim =
        Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    // Stagger slightly so multiple cards don't all animate at once
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (mounted) unawaited(_entryController.forward());
      }),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      torrentProvider.select(
        (s) => s.value?.firstWhere(
          (t) => t.id == widget.torrentId,
          orElse: () => _placeholder(widget.torrentId),
        ),
      ),
    );

    if (status == null) return const SizedBox.shrink();

    final isEffectivelyComplete = status.isEffectivelyComplete;
    final isActive =
        status.state == TorrentState.downloading ||
        status.state == TorrentState.seeding ||
        isEffectivelyComplete ||
        status.state == TorrentState.checkingFiles ||
        status.state == TorrentState.checkingResume ||
        status.state == TorrentState.downloadingMetadata;
    final isFinished = isEffectivelyComplete;
    final hasError = status.state == TorrentState.error;
    final isDownloading = status.state == TorrentState.downloading;
    final double progressHeight =
        (isFinished || status.isPaused || status.isStopped) ? 2.0 : 5.0;
    final Color accentColor = isFinished
        ? AppColors.finished
        : hasError
        ? AppColors.error
        : isDownloading
        ? AppColors.downloading
        : status.state == TorrentState.seeding
        ? AppColors.seeding
        : status.state == TorrentState.paused
        ? AppColors.paused
        : Colors.transparent;

    final isSelected = ref
        .watch(selectedTorrentsProvider)
        .contains(widget.torrentId);
    final isSelectionMode = ref
        .watch(selectedTorrentsProvider.notifier)
        .isSelectionMode;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _GlassCard(
            isActive: isActive,
            hasError: hasError,
            isNew: widget.isNew,
            isSelected: isSelected,
            child: InkWell(
              onTap: () {
                if (isSelectionMode) {
                  ref
                      .read(selectedTorrentsProvider.notifier)
                      .toggle(widget.torrentId);
                  unawaited(HapticFeedback.lightImpact());
                }
                // When not in selection mode, tap does nothing
                // (actions are in the row buttons below)
              },
              onLongPress: () {
                unawaited(HapticFeedback.mediumImpact());
                // Long-press always enters selection mode and selects this item
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .toggle(widget.torrentId);
              },
              borderRadius: BorderRadius.circular(24),
              splashColor: AppColors.downloading.withValues(alpha: 0.12),
              highlightColor: AppColors.downloading.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  // ── State accent stripe ──────────────────────────────
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: isDownloading
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.45, end: 1.0),
                            duration: const Duration(milliseconds: 1100),
                            curve: Curves.easeInOut,
                            builder: (_, v, _) => Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: v),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                              ),
                            ),
                          ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      isSelectionMode ? 52 : 20,
                      8,
                      12,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Row 1: Title + State Badge ──────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                status.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: AppColors.text(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── Row 2: Progress bar + percent ───────────────
                        Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: progressHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.border(
                                        context,
                                      ).withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: status.progress.clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    child: isFinished
                                        ? Container(
                                            height: progressHeight,
                                            decoration: BoxDecoration(
                                              gradient: AppGradients.seeding,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.seeding
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          )
                                        : AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 600,
                                            ),
                                            height: progressHeight,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  status.state ==
                                                      TorrentState.paused
                                                  ? AppGradients.paused
                                                  : AppGradients.primary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: isActive
                                                  ? [
                                                      BoxShadow(
                                                        color:
                                                            (status.state ==
                                                                        TorrentState
                                                                            .paused
                                                                    ? AppColors
                                                                          .paused
                                                                    : AppColors
                                                                          .downloading)
                                                                .withValues(
                                                                  alpha: 0.35,
                                                                ),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(status.progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ── Row 3: ↓speed ↑speed seeds peers · size ─────
                        Row(
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              color: AppColors.downloading,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              SpeedFormatter.format(
                                status.downloadSpeed.toInt(),
                              ),
                              style: const TextStyle(
                                color: AppColors.downloading,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppColors.seeding,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              SpeedFormatter.format(status.uploadSpeed.toInt()),
                              style: const TextStyle(
                                color: AppColors.seeding,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Icon(
                              Icons.keyboard_double_arrow_up_rounded,
                              color: AppColors.textSecondary(context),
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              status.seeds.toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.people_outline_rounded,
                              color: AppColors.textSecondary(context),
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              status.peers.toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              status.magnetUri != null
                                  ? Icons.link_rounded
                                  : Icons.insert_drive_file_outlined,
                              size: 12,
                              color: AppColors.textSecondary(
                                context,
                              ).withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              SizeFormatter.format(status.totalSize),
                              style: TextStyle(
                                color: AppColors.textSecondary(
                                  context,
                                ).withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // ── Row 4: Actions (right-aligned) ──────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _ActionButtons(torrentId: widget.torrentId),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelectionMode)
                    Positioned(
                      top: 14,
                      left: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.downloading
                              : AppColors.border(
                                  context,
                                ).withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.downloading
                                : AppColors.border(context),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.downloading.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.check,
                          color: isSelected ? Colors.white : Colors.transparent,
                          size: 14,
                        ),
                      ),
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.isActive,
    required this.hasError,
    required this.isNew,
    required this.isSelected,
  });

  final Widget child;
  final bool isActive;
  final bool hasError;
  final bool isNew;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = isSelected
        ? primaryColor
        : hasError
        ? AppColors.error.withValues(alpha: 0.5)
        : isActive
        ? primaryColor.withValues(alpha: 0.45)
        : AppColors.inkFaded;

    final borderWidth = isSelected || isActive ? 1.5 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isSelected ? primaryColor.withValues(alpha: 0.10) : null,
        gradient: isSelected
            ? null
            : LinearGradient(
                colors: hasError
                    ? [
                        AppColors.error.withValues(alpha: 0.08),
                        AppColors.error.withValues(alpha: 0.04),
                      ]
                    : [
                        AppColors.surface(context),
                        AppColors.background(context),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child,
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.torrentId});
  final String torrentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider directly so we always get the latest optimistic state.
    final status = ref.watch(
      torrentProvider.select(
        (s) => s.value?.firstWhere(
          (t) => t.id == torrentId,
          orElse: () => _placeholder(torrentId),
        ),
      ),
    );
    if (status == null) return const SizedBox.shrink();

    final notifier = ref.read(torrentProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final isDone = status.progress >= 1.0;
    final isSeeding = status.state == TorrentState.seeding;
    final isPaused = status.isPaused;
    final isStopped = status.isStopped;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDone) ...[
          if (isSeeding) ...[
            // COMPLETED + SEEDING: Pause (Stop Seeding), Folder, Delete
            _CircleIconButton(
              icon: Icons.pause_rounded,
              color: AppColors.textSecondary(context),
              onTap: () async {
                try {
                  await notifier.pauseTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to pause seeding: $e');
                }
              },
              tooltip: 'Pause Seeding',
            ),
          ] else ...[
            // COMPLETED + NOT SEEDING: Completed checkmark icon (non-clickable / informative), Folder, Delete
            Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: AppColors.finished.withValues(alpha: 0.8),
              ),
            ),
          ],
        ] else ...[
          // DOWNLOADING or PAUSED
          if (isPaused || isStopped) ...[
            // PAUSED: Resume, Stop, Folder, Delete
            _CircleIconButton(
              icon: Icons.play_arrow_rounded,
              color: AppColors.seeding,
              onTap: () async {
                final granted = await PermissionService.isStorageGranted();
                if (!granted) {
                  if (context.mounted) {
                    final retry = await PermissionService.showStorageRationale(
                      context,
                    );
                    if (retry) {
                      await Permission.manageExternalStorage.request();
                    }
                  }
                  return;
                }
                try {
                  await notifier.resumeTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to resume: $e');
                }
              },
              tooltip: 'Resume',
            ),
          ] else ...[
            // DOWNLOADING: Pause, Stop, Folder, Delete
            _CircleIconButton(
              icon: Icons.pause_rounded,
              color: AppColors.textSecondary(context),
              onTap: () async {
                try {
                  await notifier.pauseTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to pause: $e');
                }
              },
              tooltip: 'Pause',
            ),
          ],
          if (!isStopped)
            _CircleIconButton(
              icon: Icons.stop_rounded,
              color: AppColors.textSecondary(context),
              onTap: () async {
                try {
                  await notifier.stopTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to stop: $e');
                }
              },
              tooltip: 'Stop',
            ),
        ],
        _CircleIconButton(
          icon: Icons.folder_open_rounded,
          color: isDone ? AppColors.finished : AppColors.textSecondary(context),
          onTap: () async {
            final granted = await PermissionService.isStorageGranted();
            if (!granted) {
              if (context.mounted) {
                final retry = await PermissionService.showStorageRationale(
                  context,
                );
                if (retry) {
                  await Permission.manageExternalStorage.request();
                }
              }
              return;
            }
            try {
              await FolderService.instance.openDownloadTarget(
                savePath: status.savePath,
                name: status.name,
              );
            } catch (e) {
              _showErrorSnackBar(messenger, 'Failed to open folder: $e');
            }
          },
          tooltip: 'Open folder',
        ),
        const SizedBox(width: 4),
        _CircleIconButton(
          icon: Icons.delete_outline_rounded,
          color: AppColors.error,
          onTap: () => _confirmDelete(context, ref, status),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  void _showErrorSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TorrentStatus status,
  ) async {
    final notifier = ref.read(torrentProvider.notifier);
    final result = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteDialog(torrentName: status.name),
    );
    if (result == _DeleteChoice.removeOnly) {
      await notifier.deleteTorrent(status.id);
    } else if (result == _DeleteChoice.removeWithFiles) {
      await notifier.deleteTorrent(status.id, deleteFiles: true);
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

enum _DeleteChoice { removeOnly, removeWithFiles }

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.torrentName});
  final String torrentName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Text(
            'Remove Torrent',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Text(
        '"$torrentName"',
        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DeleteChoice.removeOnly),
          child: const Text('Remove'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () =>
              Navigator.pop(context, _DeleteChoice.removeWithFiles),
          child: const Text('Remove + Files'),
        ),
      ],
    );
  }
}
