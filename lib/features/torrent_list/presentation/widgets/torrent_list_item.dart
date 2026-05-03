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
            child: InkWell(
              onTap: () => _showOptions(context, ref, status),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showOptions(context, ref, status);
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              highlightColor: const Color(0xFF6C63FF).withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            status.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: isFinished ? 0.82 : 1.0,
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AnimatedStateBadge(state: status.state),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Progress section ─────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Large percentage
                        _GradientPercentText(
                          progress: status.progress,
                          state: status.state,
                        ),
                        const SizedBox(width: 12),
                        // Progress bar
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _GradientProgressBar(
                              progress: status.progress,
                              state: status.state,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Info row ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _InfoRow(status: status),
                        ),
                        const SizedBox(width: 8),
                        // ── Action buttons ───────────────────────────────
                        _ActionButtons(status: status),
                      ],
                    ),

                    // ── Error message ────────────────────────────────────
                    if (hasError && status.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: status.errorMessage!),
                    ],

                    const SizedBox(height: 6),

                    // ── Footer: size progress ────────────────────────────
                    Text(
                      '${SizeFormatter.format(status.downloadedBytes)} / '
                      '${SizeFormatter.format(status.totalSize)}',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: isFinished ? 0.30 : 0.38,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // ── UX: completed call-to-action banner ─────────────
                    if (isFinished) ...[
                      const SizedBox(height: 8),
                      _CompletedBanner(
                        onOpenFolder: () => _openFolder(status),
                      ),
                    ],
                  ],
                ),
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

  /// Opens the torrent's folder, preferring the per-torrent subfolder when it
  /// exists, or the concrete downloaded file for single-file torrents.
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF5555),
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

// ─── Glassmorphism Card Shell ────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.isActive,
    required this.hasError,
    required this.isNew,
  });

  final Widget child;
  final bool isActive;
  final bool hasError;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? const Color(0x80FF5555)
        : isActive
            ? const Color(0x806C63FF)
            : const Color(0x1AFFFFFF);

    final borderWidth = isActive ? 1.5 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: hasError
              ? [const Color(0x1AFF5555), const Color(0x0DFF5555)]
              : [const Color(0x1A6C63FF), const Color(0x0D48B0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: child,
        ),
      ),
    );
  }
}

// ─── Gradient Percent Text ────────────────────────────────────────────────────

class _GradientPercentText extends StatelessWidget {
  const _GradientPercentText({required this.progress, required this.state});
  final double progress;
  final TorrentState state;

  LinearGradient get _gradient {
    switch (state) {
      case TorrentState.seeding:
        return AppGradients.seeding;
      case TorrentState.error:
        return AppGradients.error;
      case TorrentState.paused:
        return AppGradients.paused;
      default:
        return AppGradients.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (_, value, __) {
          return Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white, // overridden by ShaderMask
            ),
          );
        },
      ),
    );
  }
}

// ─── Gradient Progress Bar ───────────────────────────────────────────────────

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.progress, required this.state});
  final double progress;
  final TorrentState state;

  LinearGradient get _gradient {
    switch (state) {
      case TorrentState.seeding:
        return AppGradients.seeding;
      case TorrentState.error:
        return AppGradients.error;
      case TorrentState.paused:
        return AppGradients.paused;
      default:
        return AppGradients.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, value, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Track
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.status});
  final TorrentStatus status;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        if (status.downloadSpeed > 0)
          _InfoChip(
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF6C63FF),
            label: SpeedFormatter.format(status.downloadSpeed),
          ),
        if (status.uploadSpeed > 0)
          _InfoChip(
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFF50FA7B),
            label: SpeedFormatter.format(status.uploadSpeed),
          ),
        _InfoChip(
          icon: Icons.people_outline_rounded,
          iconColor: Colors.white38,
          label: '${status.seeds}S / ${status.peers}P',
        ),
        if (status.etaSeconds != null &&
            status.state == TorrentState.downloading)
          _InfoChip(
            icon: Icons.timer_outlined,
            iconColor: Colors.white38,
            label: SpeedFormatter.formatEta(status.etaSeconds),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: iconColor),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Animated State Badge ────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.45), width: 1),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(
          color: _color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        child: Text(state.displayName.toUpperCase()),
      ),
    );
  }
}

// ─── Action Buttons ──────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.status});
  final TorrentStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final state = status.state;
    final messenger = ScaffoldMessenger.of(context);

    final isPaused = state == TorrentState.paused;
    final isDone = status.isEffectivelyComplete;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Play / Pause toggle ────────────────────────────────────────
        if (isPaused)
          _CircleIconButton(
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF6C63FF),
            onTap: () async {
              try {
                await notifier.resumeTorrent(status.id);
              } catch (e) {
                _showError(messenger, 'Failed to resume: $e');
              }
            },
            tooltip: 'Resume',
          )
        else
          _CircleIconButton(
            icon: Icons.pause_rounded,
            color: Colors.white70,
            onTap: () async {
              try {
                await notifier.pauseTorrent(status.id);
              } catch (e) {
                _showError(messenger, 'Failed to pause: $e');
              }
            },
            tooltip: 'Pause',
          ),
        // ── Open completed target ──────────────────────────────────────
        if (isDone)
          _CircleIconButton(
            icon: Icons.folder_open_rounded,
            color: const Color(0xFF50FA7B),
            onTap: () async {
              try {
                await FolderService.instance.openDownloadTarget(
                  savePath: status.savePath,
                  name: status.name,
                );
              } catch (e) {
                _showError(messenger, 'Failed to open download: $e');
              }
            },
            tooltip: 'Open download',
          ),
        const SizedBox(width: 4),
        _CircleIconButton(
          icon: Icons.delete_outline_rounded,
          color: Colors.white30,
          onTap: () => _confirmDelete(context, ref),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF5555),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteDialog(torrentName: status.name),
    );
    if (result == _DeleteChoice.removeOnly) {
      try {
        await notifier.deleteTorrent(status.id);
      } catch (e) {
        _showError(messenger, 'Failed to delete: $e');
      }
    } else if (result == _DeleteChoice.removeWithFiles) {
      try {
        await notifier.deleteTorrent(status.id, deleteFiles: true);
      } catch (e) {
        _showError(messenger, 'Failed to delete: $e');
      }
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

// ─── Delete Dialog ───────────────────────────────────────────────────────────

enum _DeleteChoice { removeOnly, removeWithFiles }

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.torrentName});
  final String torrentName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFF5555), size: 22),
          SizedBox(width: 10),
          Text('Remove Torrent',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ],
      ),
      content: Text(
        '"$torrentName"',
        style: const TextStyle(color: Colors.white60, fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DeleteChoice.removeOnly),
          child: const Text('Remove', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5555),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () =>
              Navigator.pop(context, _DeleteChoice.removeWithFiles),
          child: const Text('Remove + Files'),
        ),
      ],
    );
  }
}

// ─── Error Banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5555).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFFFF5555).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF5555), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFF8888), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Completed Banner ─────────────────────────────────────────────────────────

/// UX call-to-action strip shown on finished/seeding cards.
/// Tapping opens the download folder directly from the card body.
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
          color: const Color(0xFF50FA7B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF50FA7B).withValues(alpha: 0.28)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF50FA7B), size: 13),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Download complete  ·  Tap to open',
                style: TextStyle(
                  color: Color(0xFF50FA7B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Color(0xFF50FA7B), size: 15),
          ],
        ),
      ),
    );
  }
}

// ─── Torrent Options Sheet ────────────────────────────────────────────────────

class _TorrentOptionsSheet extends StatelessWidget {
  const _TorrentOptionsSheet({required this.status, required this.ref});
  final TorrentStatus status;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isPaused = status.state == TorrentState.paused;
    final isDownloading = status.state == TorrentState.downloading;
    final isFinished = status.isEffectivelyComplete;
    final isActive =
        isDownloading || status.state == TorrentState.downloadingMetadata;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Torrent name header
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
                      color: Colors.white, size: 16),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(status.progress * 100).toStringAsFixed(1)}%'
                        ' · ${SizeFormatter.format(status.downloadedBytes)}'
                        ' / ${SizeFormatter.format(status.totalSize)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 24),
          // ── Actions ────────────────────────────────────────────────
          if (isPaused)
            _OptionTile(
              icon: Icons.play_arrow_rounded,
              iconColor: const Color(0xFF6C63FF),
              label: 'Resume Download',
              onTap: () async {
                navigator.pop();
                try {
                  await notifier.resumeTorrent(status.id);
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to resume: $e');
                }
              },
            ),
          if (isActive)
            _OptionTile(
              icon: Icons.pause_rounded,
              iconColor: Colors.white70,
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
          if (isFinished)
            _OptionTile(
              icon: Icons.folder_open_rounded,
              iconColor: const Color(0xFF50FA7B),
              label: 'Open Download',
              onTap: () async {
                navigator.pop();
                try {
                  await FolderService.instance.openDownloadTarget(
                    savePath: status.savePath,
                    name: status.name,
                  );
                } catch (e) {
                  _showErrorSnackBar(messenger, 'Failed to open download: $e');
                }
              },
            ),
          _OptionTile(
            icon: Icons.refresh_rounded,
            iconColor: Colors.white54,
            label: 'Force Recheck',
            onTap: () async {
              navigator.pop();
              try {
                await ref
                    .read(torrentRepositoryProvider)
                    .recheckTorrent(status.id);
              } catch (e) {
                _showErrorSnackBar(messenger, 'Failed to recheck: $e');
              }
            },
          ),
          _OptionTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.white54,
            label: 'Properties',
            onTap: () async {
              navigator.pop();
              _showProperties(context);
            },
          ),
          const Divider(color: Colors.white12, height: 8),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            iconColor: const Color(0xFFFF5555),
            label: 'Remove Torrent',
            onTap: () async {
              navigator.pop();
              _confirmDelete(context);
            },
          ),
          _OptionTile(
            icon: Icons.delete_forever_rounded,
            iconColor: const Color(0xFFFF5555),
            label: 'Remove + Delete Files',
            onTap: () async {
              navigator.pop();
              try {
                await notifier.deleteTorrent(status.id, deleteFiles: true);
              } catch (e) {
                _showErrorSnackBar(messenger, 'Failed to delete: $e');
              }
            },
          ),
          SizedBox(height: 12 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final notifier = ref.read(torrentNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => _DeleteDialog(torrentName: status.name),
    ).then((result) async {
      if (result == _DeleteChoice.removeOnly) {
        try {
          await notifier.deleteTorrent(status.id);
        } catch (e) {
          _showErrorSnackBar(messenger, 'Failed to delete: $e');
        }
      } else if (result == _DeleteChoice.removeWithFiles) {
        try {
          await notifier.deleteTorrent(status.id, deleteFiles: true);
        } catch (e) {
          _showErrorSnackBar(messenger, 'Failed to delete: $e');
        }
      }
    });
  }

  void _showErrorSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF5555),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showProperties(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Properties',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PropRow('Name', status.name),
            _PropRow('State', status.state.displayName),
            _PropRow(
                'Progress', '${(status.progress * 100).toStringAsFixed(2)}%'),
            _PropRow('Size', SizeFormatter.format(status.totalSize)),
            _PropRow(
                'Downloaded', SizeFormatter.format(status.downloadedBytes)),
            _PropRow('Upload', SizeFormatter.format(status.uploadedBytes)),
            _PropRow('Ratio', status.ratio.toStringAsFixed(2)),
            _PropRow('Seeds / Peers', '${status.seeds} / ${status.peers}'),
            _PropRow('Save Path', status.savePath),
            _PropRow(
                'Added', status.addedAt.toLocal().toString().substring(0, 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
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
                color: Colors.white,
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

class _PropRow extends StatelessWidget {
  const _PropRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
