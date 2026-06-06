import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/speed_formatter.dart';
import '../../../../domain/entities/torrent_status.dart';
import '../controllers/torrent_notifier.dart';
import 'quick_action_sheet.dart';
import '../../../settings/presentation/controllers/settings_notifier.dart';
import '../../../../core/services/folder_service.dart';

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
      key: const Key('torrent_list_item'),
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
            isFinished: isFinished,
            child: InkWell(
              onTap: () {
                if (isSelectionMode) {
                  ref
                      .read(selectedTorrentsProvider.notifier)
                      .toggle(widget.torrentId);
                  unawaited(HapticFeedback.lightImpact());
                } else {
                  unawaited(HapticFeedback.mediumImpact());
                  unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: false,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          QuickActionSheet(torrentId: widget.torrentId),
                    ),
                  );
                }
              },
              onLongPress: () {
                unawaited(HapticFeedback.mediumImpact());
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
                      14,
                      16,
                      14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Title ──
                              Text(
                                status.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.text(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: -0.1,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              // ── Progress bar + percent ───────────────
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
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                                    gradient:
                                                        AppGradients.seeding,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.seeding
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
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
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    boxShadow: isActive
                                                        ? [
                                                            BoxShadow(
                                                              color:
                                                                  (status.state ==
                                                                              TorrentState.paused
                                                                          ? AppColors.paused
                                                                          : AppColors.downloading)
                                                                      .withValues(
                                                                        alpha:
                                                                            0.35,
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
                                      fontFamily: 'Outfit',
                                      color: isFinished
                                          ? AppColors.finished.withValues(
                                              alpha: 0.8,
                                            )
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary.withValues(
                                              alpha: 0.8,
                                            ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // ── Telemetry (State & Download Speed only) ────
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    status.state.displayName.toUpperCase(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  if ((isDownloading ||
                                          status.state ==
                                              TorrentState
                                                  .downloadingMetadata) &&
                                      status.downloadSpeed > 0) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.arrow_downward_rounded,
                                          color: AppColors.downloading,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          SpeedFormatter.format(
                                            status.downloadSpeed.toInt(),
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.downloading,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (status.uploadSpeed > 0) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.arrow_upward_rounded,
                                          color: AppColors.seeding,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          SpeedFormatter.format(
                                            status.uploadSpeed.toInt(),
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.seeding,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isSelectionMode) ...[
                          const SizedBox(width: 16),
                          _HankoActionButton(torrentId: widget.torrentId),
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
    this.isFinished = false,
  });

  final Widget child;
  final bool isActive;
  final bool hasError;
  final bool isNew;
  final bool isSelected;
  final bool isFinished;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = isSelected
        ? primaryColor
        : hasError
        ? AppColors.error.withValues(alpha: 0.5)
        : isFinished
        ? AppColors.finished.withValues(alpha: 0.45)
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
                  color: (isFinished ? AppColors.finished : primaryColor)
                      .withValues(alpha: 0.18),
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
        child: child,
      ),
    );
  }
}

class _HankoActionButton extends ConsumerStatefulWidget {
  const _HankoActionButton({required this.torrentId});
  final String torrentId;

  @override
  ConsumerState<_HankoActionButton> createState() => _HankoActionButtonState();
}

class _HankoActionButtonState extends ConsumerState<_HankoActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scale;

  // Pulse ring for seeding state
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true); // ignore: discarded_futures
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    _pulseController.dispose();
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


    final config = ref.watch(settingsProvider);

    final isPaused =
        status.isPaused ||
        status.isStopped ||
        status.state == TorrentState.paused ||
        status.state == TorrentState.stopped;
    final isDone = status.isCompleted;
    final isSeeding = status.state == TorrentState.seeding || (isDone && !isPaused);

    // ── Dynamic Button Resolution ────────────────────────────────────────────
    final bool showOpenFolder;
    final bool showPause;
    final bool showPlay;

    if (isDone) {
      if (isSeeding) {
        showOpenFolder = false;
        showPause = true;
        showPlay = false;
      } else {
        if (config.stopSeedingWhenFinished) {
          showOpenFolder = true;
          showPause = false;
          showPlay = false;
        } else {
          showOpenFolder = false;
          showPause = false;
          showPlay = true;
        }
      }
    } else {
      if (isPaused) {
        showOpenFolder = false;
        showPause = false;
        showPlay = true;
      } else {
        showOpenFolder = false;
        showPause = true;
        showPlay = false;
      }
    }

    // (showSeed removed — folder icon covers the done+paused case)

    final IconData iconData;
    final String tooltipMessage;
    final VoidCallback onTapAction;

    if (showOpenFolder) {
      iconData = Icons.folder_open_rounded;
      tooltipMessage = 'Open Folder';
      onTapAction = () async {
        try {
          await FolderService.instance.openDownloadTarget(
            savePath: status.savePath,
            name: status.name,
          );
        } catch (_) {}
      };
    } else if (showPause) {
      iconData = Icons.pause_rounded;
      tooltipMessage = isSeeding ? 'Stop Seeding' : 'Pause';
      onTapAction = () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(torrentProvider.notifier).pauseTorrent(status.id);
        } catch (e) {
          _showErrorSnackBar(
            messenger,
            isSeeding ? 'Failed to stop seeding: $e' : 'Failed to pause: $e',
          );
        }
      };
    } else if (showPlay) {
      iconData = Icons.play_arrow_rounded;
      tooltipMessage = isDone ? 'Start Seeding' : 'Resume';
      onTapAction = () async {
        final messenger = ScaffoldMessenger.of(context);
        final granted = await PermissionService.isStorageGranted();
        if (!context.mounted) return;
        if (!granted) {
          final retry = await PermissionService.showStorageRationale(context);
          if (retry && mounted) {
            await Permission.manageExternalStorage.request();
          }
          return;
        }
        try {
          await ref.read(torrentProvider.notifier).resumeTorrent(status.id);
        } catch (e) {
          _showErrorSnackBar(messenger, 'Failed to resume: $e');
        }
      };
    } else {
      // Fallback: nothing matched — show folder (safe default for any done state)
      iconData = Icons.folder_open_rounded;
      tooltipMessage = 'Open Folder';
      onTapAction = () async {
        try {
          await FolderService.instance.openDownloadTarget(
            savePath: status.savePath,
            name: status.name,
          );
        } catch (_) {}
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sealColor = isDark
        ? const Color(0xFFE53935)
        : const Color(0xFFC82127);

    // Green for folder/seeding actions (completed/seeding), Crimson for downloading/resuming
    final bool isFolderAction = showOpenFolder || (!showPause && !showPlay);
    final Color buttonColor = (isFolderAction || (showPause && isSeeding) || (showPlay && isDone))
        ? AppColors.seeding
        : sealColor;

    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: () async {
          unawaited(HapticFeedback.lightImpact());
          await _tapController.forward();
          await _tapController.reverse();
          if (!mounted) return;
          onTapAction();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_scale, _pulseAnim]),
          builder: (_, child) => Transform.scale(
            scale: _scale.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring — only visible when actively seeding
                if (showPause && isSeeding)
                  Container(
                    width: 48 + (_pulseAnim.value * 14),
                    height: 48 + (_pulseAnim.value * 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.seeding.withValues(
                          alpha: (0.45 * (1 - _pulseAnim.value)),
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                child!,
              ],
            ),
          ),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonColor.withValues(alpha: 0.10),
              border: Border.all(
                color: buttonColor.withValues(
                  alpha: (showPause && isSeeding)
                      ? 0.25 + (_pulseAnim.value * 0.20)
                      : 0.15,
                ),
                width: 1.4,
              ),
            ),
            child: Center(
              child: Icon(
                iconData,
                size: 24,
                color: buttonColor,
              ),
            ),
          ),
        ),
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
