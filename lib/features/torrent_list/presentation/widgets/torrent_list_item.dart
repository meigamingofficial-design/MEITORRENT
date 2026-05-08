import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/folder_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/size_formatter.dart';
import '../../../../core/utils/speed_formatter.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../controllers/torrent_notifier.dart';

/// Premium glassmorphism torrent card.
/// Uses `.select()` — only rebuilds when THIS torrent's data changes.
class TorrentListItem extends ConsumerStatefulWidget {
  const TorrentListItem(
      {super.key, required this.torrentId, this.isNew = false});

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
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    // Stagger slightly so multiple cards don't all animate at once
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      torrentNotifierProvider.select(
        (s) => s.valueOrNull?.firstWhere(
          (t) => t.id == widget.torrentId,
          orElse: () => _placeholder(widget.torrentId),
        ),
      ),
    );

    if (status == null) return const SizedBox.shrink();

    final isEffectivelyComplete = status.isEffectivelyComplete;
    final isActive = status.state == TorrentState.downloading ||
        status.state == TorrentState.seeding ||
        isEffectivelyComplete ||
        status.state == TorrentState.checkingFiles ||
        status.state == TorrentState.checkingResume ||
        status.state == TorrentState.downloadingMetadata;
    final isFinished = isEffectivelyComplete;
    final hasError = status.state == TorrentState.error;

    final isSelected =
        ref.watch(selectedTorrentsProvider).contains(widget.torrentId);
    final isSelectionMode =
        ref.watch(selectedTorrentsProvider.notifier).isSelectionMode;

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
                  HapticFeedback.lightImpact();
                } else {
                  _showOptions(context, ref, status);
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(selectedTorrentsProvider.notifier)
                    .toggle(widget.torrentId);
              },
              borderRadius: BorderRadius.circular(24),
              splashColor: AppColors.downloading.withValues(alpha: 0.12),
              highlightColor: AppColors.downloading.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(isSelectionMode ? 48 : 16, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                status.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.inkBlack,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _AnimatedStateBadge(state: status.state),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded, color: Theme.of(context).colorScheme.primary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              SpeedFormatter.format(status.downloadSpeed.toInt()),
                              style: const TextStyle(color: AppColors.inkGrey, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.people_outline_rounded, color: AppColors.inkGrey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              status.peers.toString(),
                              style: const TextStyle(color: AppColors.inkGrey, fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              '${(status.progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.inkFaded,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: status.progress.clamp(0.0, 1.0),
                              child: isFinished 
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.4, end: 0.8),
                                    duration: const Duration(milliseconds: 1500),
                                    builder: (context, value, child) {
                                      return Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          gradient: AppGradients.primary,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00B894).withValues(alpha: value),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onEnd: () {},
                                  )
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.primary,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: isActive ? [
                                        BoxShadow(
                                          color: const Color(0xFF00B894).withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ] : null,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${SizeFormatter.format(status.downloadedBytes)} / '
                              '${SizeFormatter.format(status.totalSize)}',
                              style: TextStyle(
                                color: AppColors.inkGrey.withValues(
                                  alpha: isFinished ? 0.50 : 0.75,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            _ActionButtons(status: status),
                          ],
                        ),
                        if (isFinished) ...[
                          const SizedBox(height: 12),
                          _CompletedBanner(
                            onOpenFolder: () => _openFolder(status),
                          ),
                        ],
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
                          color: isSelected ? AppColors.downloading : AppColors.inkFaded.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.downloading : AppColors.inkFaded,
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.downloading.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ] : null,
                        ),
                        child: Icon(
                          Icons.check,
                          color: isSelected ? AppColors.paperWhite : Colors.transparent,
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

  void _showOptions(BuildContext context, WidgetRef ref, TorrentStatus status) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TorrentOptionsSheet(status: status, ref: ref),
    );
  }

  void _openFolder(TorrentStatus status) {
    final messenger = ScaffoldMessenger.of(context);
    try {
      FolderService.instance.openDownloadTarget(
        savePath: status.savePath,
        name: status.name,
      );
    } catch (e) {
      _showError(messenger, 'Failed to open folder: $e');
    }
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.paperWhite)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static TorrentStatus _placeholder(String id) => TorrentStatus(
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
        ratio: 0,
      );
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
                    ? [AppColors.error.withValues(alpha: 0.08), AppColors.error.withValues(alpha: 0.04)]
                    : [
                        AppColors.paperWhite,
                        AppColors.parchment,
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

class _AnimatedStateBadge extends StatelessWidget {
  const _AnimatedStateBadge({required this.state});
  final TorrentState state;

  Color get _color {
    switch (state) {
      case TorrentState.downloading:
        return AppColors.downloading;
      case TorrentState.seeding:
        return AppColors.seeding;
      case TorrentState.paused:
        return AppColors.paused;
      case TorrentState.error:
        return AppColors.error;
      case TorrentState.finished:
        return AppColors.finished;
      case TorrentState.downloadingMetadata:
        return AppColors.metadata;
      case TorrentState.checkingFiles:
      case TorrentState.checkingResume:
      case TorrentState.allocating:
        return AppColors.checking;
      default:
        return AppColors.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        state.displayName.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.status});
  final TorrentStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final isPaused = status.isPaused;
    final isStopped = status.isStopped;
    final isDone = status.isEffectivelyComplete;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPaused || isStopped)
          _CircleIconButton(
            icon: Icons.play_arrow_rounded,
            color: AppColors.seeding,
            onTap: () async {
              try {
                await notifier.resumeTorrent(status.id);
              } catch (e) {
                _showErrorSnackBar(messenger, 'Failed to resume: $e');
              }
            },
            tooltip: 'Resume',
          )
        else
          _CircleIconButton(
            icon: isDone ? Icons.check_circle_outline_rounded : Icons.pause_rounded,
            color: isDone ? AppColors.finished : AppColors.inkGrey,
            onTap: () async {
              try {
                await notifier.pauseTorrent(status.id);
              } catch (e) {
                _showErrorSnackBar(messenger, 'Failed to pause: $e');
              }
            },
            tooltip: isDone ? 'Stop Seeding' : 'Pause',
          ),
        if (!isStopped)
          _CircleIconButton(
            icon: Icons.stop_rounded,
            color: AppColors.inkGrey,
            onTap: () async {
              try {
                await notifier.stopTorrent(status.id);
              } catch (e) {
                _showErrorSnackBar(messenger, 'Failed to stop: $e');
              }
            },
            tooltip: 'Stop',
          ),
        if (!isDone)
          _CircleIconButton(
            icon: Icons.folder_open_rounded,
            color: AppColors.inkGrey,
            onTap: () async {
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
          onTap: () => _confirmDelete(context, ref),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  void _showErrorSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.paperWhite)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final result = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteDialog(torrentName: status.name),
    );
    if (result == _DeleteChoice.removeOnly) {
      notifier.deleteTorrent(status.id);
    } else if (result == _DeleteChoice.removeWithFiles) {
      notifier.deleteTorrent(status.id, deleteFiles: true);
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
          Text('Remove Torrent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Text(
        '"$torrentName"',
        style: const TextStyle(color: AppColors.inkGrey, fontSize: 13),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, _DeleteChoice.removeWithFiles),
          child: const Text('Remove + Files'),
        ),
      ],
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.onOpenFolder});
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenFolder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.finished.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.finished.withValues(alpha: 0.28)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.finished, size: 13),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Download complete  ·  Tap to open',
                style: TextStyle(
                  color: AppColors.finished,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.finished, size: 15),
          ],
        ),
      ),
    );
  }
}

class _TorrentOptionsSheet extends StatelessWidget {
  const _TorrentOptionsSheet({required this.status, required this.ref});
  final TorrentStatus status;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isPaused = status.isPaused;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.paperWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inkFaded),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inkFaded,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: AppColors.paperWhite, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkBlack,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(status.progress * 100).toStringAsFixed(1)}%'
                        ' · ${SizeFormatter.format(status.downloadedBytes)}'
                        ' / ${SizeFormatter.format(status.totalSize)}',
                        style: const TextStyle(
                            color: AppColors.inkGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.inkFaded, height: 24),
          if (isPaused)
            _OptionTile(
              icon: Icons.play_arrow_rounded,
              iconColor: AppColors.seeding,
              label: 'Resume Download',
              onTap: () async {
                navigator.pop();
                try {
                  await notifier.resumeTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to resume: $e');
                }
              },
            )
          else
            _OptionTile(
              icon: Icons.pause_rounded,
              iconColor: AppColors.inkGrey,
              label: 'Pause Download',
              onTap: () async {
                navigator.pop();
                try {
                  await notifier.pauseTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to pause: $e');
                }
              },
            ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.error,
            label: 'Remove Torrent',
            onTap: () async {
              navigator.pop();
              final result = await showDialog<_DeleteChoice>(
                context: context,
                builder: (_) => _DeleteDialog(torrentName: status.name),
              );
              if (result == _DeleteChoice.removeOnly) {
                notifier.deleteTorrent(status.id);
              } else if (result == _DeleteChoice.removeWithFiles) {
                notifier.deleteTorrent(status.id, deleteFiles: true);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
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
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.inkBlack,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
