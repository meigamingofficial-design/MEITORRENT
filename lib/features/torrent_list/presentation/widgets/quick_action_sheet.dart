import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/folder_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../controllers/torrent_notifier.dart';
import 'torrent_detail_bottom_sheet.dart';

/// Lightweight quick-action sheet that appears on single card tap.
///
/// Shows: torrent name + state chip, Resume/Pause, Open Folder,
/// Delete, and a "More Info →" button that opens the full detail sheet.
class QuickActionSheet extends ConsumerWidget {
  const QuickActionSheet({super.key, required this.torrentId});
  final String torrentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrent = ref.watch(
      torrentProvider.select(
        (asyncValue) => asyncValue.value?.firstWhere(
          (t) => t.id == torrentId,
          orElse: () => _placeholder(torrentId),
        ) ??
            _placeholder(torrentId),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1B1F) : const Color(0xFFFFFDF9);
    final border = isDark ? const Color(0xFF2C2D33) : const Color(0xFFE5DDD0);
    final primaryRed = isDark ? const Color(0xFFE53935) : const Color(0xFFC82127);
    final textPrimary = isDark ? const Color(0xFFECE9E2) : const Color(0xFF1C1C1C);
    final textSecondary = isDark ? const Color(0xFFA39F97) : const Color(0xFF5C5850);

    final stateColor = _stateColor(torrent.state);
    final stateLabel = _stateLabel(torrent.state);

    final bool isActive = torrent.state == TorrentState.downloading ||
        torrent.state == TorrentState.downloadingMetadata;
    final bool isSeeding = torrent.state == TorrentState.seeding;
    final bool isPaused = torrent.state == TorrentState.paused || torrent.isPaused;
    final bool isStopped = torrent.state == TorrentState.stopped;
    final bool isDone = torrent.progress >= 1.0;

    final bool canResume = isPaused || isStopped;
    final bool canPause = isActive || isSeeding;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header: name + state chip ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    torrent.name,
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: stateColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: stateColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar (if downloading / partial) ──────────────────────
          if (isActive || (torrent.progress > 0 && torrent.progress < 1))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: torrent.progress,
                      minHeight: 5,
                      backgroundColor: border,
                      valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(torrent.progress * 100).toStringAsFixed(1)}% complete',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(height: 1, color: border),

          // ── Actions ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resume / Start Seeding
                if (canResume)
                  _ActionTile(
                    icon: isDone ? Icons.upload_rounded : Icons.play_arrow_rounded,
                    label: isDone ? 'Start Seeding' : 'Resume',
                    color: AppColors.seeding,
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        ref
                            .read(torrentProvider.notifier)
                            .resumeTorrent(torrentId),
                      );
                    },
                  ),
                // Pause / Stop Seeding
                if (canPause)
                  _ActionTile(
                    icon: Icons.pause_rounded,
                    label: isDone ? 'Stop Seeding' : 'Pause',
                    color: AppColors.paused,
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        ref
                            .read(torrentProvider.notifier)
                            .pauseTorrent(torrentId),
                      );
                    },
                  ),

                // Open Folder
                _ActionTile(
                  icon: Icons.folder_open_rounded,
                  label: 'Open Folder',
                  color: textSecondary,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await FolderService.instance.openDownloadTarget(
                        savePath: torrent.savePath,
                        name: torrent.name,
                      );
                    } catch (_) {}
                  },
                ),

                // More Info →
                _ActionTile(
                  icon: Icons.info_outline_rounded,
                  label: 'More Info',
                  color: AppColors.downloading,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            TorrentDetailBottomSheet(torrentId: torrentId),
                      ),
                    );
                  },
                ),

                Divider(height: 8, color: border),

                // Delete
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Torrent',
                  color: primaryRed,
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmDelete(
                        context, ref, torrent.name, isDark, primaryRed, border);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool isDark,
    Color primaryRed,
    Color border,
  ) async {
    bool deleteFiles = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1E2023) : const Color(0xFFFFFDF9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border, width: 1.2),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: primaryRed, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Remove Torrent',
                style: TextStyle(
                  fontFamily: 'ShipporiMincho',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$name"',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFFECE9E2)
                      : const Color(0xFF1C1C1C),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setS(() => deleteFiles = !deleteFiles),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Checkbox(
                      value: deleteFiles,
                      onChanged: (v) => setS(() => deleteFiles = v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      activeColor: primaryRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Also delete downloaded files',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFFECE9E2)
                              : const Color(0xFF1C1C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFA39F97)
                      : const Color(0xFF5C5850),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      unawaited(
        ref
            .read(torrentProvider.notifier)
            .deleteTorrent(torrentId, deleteFiles: deleteFiles),
      );
    }
  }
}

// ─── Action Tile ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFECE9E2)
                      : const Color(0xFF1C1C1C),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

Color _stateColor(TorrentState state) {
  switch (state) {
    case TorrentState.downloading:
    case TorrentState.downloadingMetadata:
      return AppColors.downloading;
    case TorrentState.seeding:
      return AppColors.seeding;
    case TorrentState.finished:
      return AppColors.finished;
    case TorrentState.paused:
      return AppColors.paused;
    case TorrentState.stopped:
    case TorrentState.unknown:
    case TorrentState.allocating:
      return AppColors.unknown;
    case TorrentState.checkingFiles:
    case TorrentState.checkingResume:
      return AppColors.checking;
    case TorrentState.error:
      return AppColors.error;
  }
}

String _stateLabel(TorrentState state) {
  switch (state) {
    case TorrentState.downloading:
      return 'DOWNLOADING';
    case TorrentState.downloadingMetadata:
      return 'METADATA';
    case TorrentState.seeding:
      return 'SEEDING';
    case TorrentState.finished:
      return 'FINISHED';
    case TorrentState.paused:
      return 'PAUSED';
    case TorrentState.stopped:
      return 'STOPPED';
    case TorrentState.allocating:
      return 'ALLOCATING';
    case TorrentState.checkingFiles:
    case TorrentState.checkingResume:
      return 'CHECKING';
    case TorrentState.error:
      return 'ERROR';
    case TorrentState.unknown:
      return 'UNKNOWN';
  }
}
