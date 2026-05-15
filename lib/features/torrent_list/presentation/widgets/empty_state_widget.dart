import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulseAnim = Tween<double>(begin: 0.06, end: 0.16).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
        return 'Paused or completed torrents will\nappear in other tabs';
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
            // Floating animated magnet icon
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.downloading
                        .withValues(alpha: _pulseAnim.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.downloading
                            .withValues(alpha: _pulseAnim.value * 0.7),
                        blurRadius: 32,
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
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _title,
              style: GoogleFonts.shipporiMincho(
                color: AppColors.text(context),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            // Subtle breathing arrow pointing toward the FAB
            if (widget.filter == TorrentFilter.all)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Opacity(
                  opacity: 0.35 + 0.45 * _controller.value,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.downloading,
                    size: 28,
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
