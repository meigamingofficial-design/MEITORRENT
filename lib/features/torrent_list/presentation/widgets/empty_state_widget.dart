import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/torrent_notifier.dart';

/// Animated empty state shown when there are no torrents for the current filter.
class EmptyStateWidget extends StatefulWidget {
  const EmptyStateWidget({super.key, required this.filter});

  final TorrentFilter filter;

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnim;
  late final Animation<double> _pulseInner;
  late final Animation<double> _pulseOuter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    unawaited(_controller.repeat(reverse: true));

    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    // Inner ring — tighter pulse
    _pulseInner = Tween<double>(begin: 0.08, end: 0.20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    // Outer ring — wider, softer pulse (offset phase via reversed interval)
    _pulseOuter = Tween<double>(begin: 0.03, end: 0.10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.filter) {
      case TorrentFilter.all:
        return 'No torrents yet';
      case TorrentFilter.downloading:
        return 'No active downloads';
      case TorrentFilter.completed:
        return 'No completed torrents';
    }
  }

  String get _subtitle {
    switch (widget.filter) {
      case TorrentFilter.all:
        return 'Paste a magnet link or open a\n.torrent file to get started';
      case TorrentFilter.downloading:
        return 'Active downloading torrents will\nappear here';
      case TorrentFilter.completed:
        return 'Finished downloads will\nappear here';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Double-layer breathing glow ring + floating icon ──────────
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer soft glow ring
                    Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.downloading.withValues(
                              alpha: _pulseOuter.value,
                            ),
                            blurRadius: 56,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    // Inner sharper glow ring
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.downloading.withValues(
                          alpha: _pulseInner.value,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.downloading.withValues(
                              alpha: _pulseInner.value * 0.8,
                            ),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: AppColors.downloading,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1.0, 1.0),
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                ).fadeIn(duration: 400.ms),

            const SizedBox(height: 36),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              _title,
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                color: AppColors.text(context),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 500.ms)
                .slideY(
                  begin: 0.3,
                  end: 0,
                  delay: 100.ms,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),

            const SizedBox(height: 10),

            // ── Subtitle ──────────────────────────────────────────────────
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                height: 1.65,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 500.ms)
                .slideY(
                  begin: 0.3,
                  end: 0,
                  delay: 200.ms,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),

            const SizedBox(height: 28),

            // ── Breathing arrow toward FAB ─────────────────────────────────
            if (widget.filter == TorrentFilter.all)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => Opacity(
                  opacity: 0.3 + 0.5 * _controller.value,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.downloading,
                    size: 30,
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
