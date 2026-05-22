import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/torrent_notifier.dart';

class FilterSegmentedControl extends StatelessWidget {
  const FilterSegmentedControl({
    super.key,
    required this.activeFilter,
    required this.onChanged,
  });

  final TorrentFilter activeFilter;
  final ValueChanged<TorrentFilter> onChanged;

  int get _activeIndex {
    switch (activeFilter) {
      case TorrentFilter.all:
        return 0;
      case TorrentFilter.downloading:
        return 1;
      case TorrentFilter.completed:
        return 2;
    }
  }

  static const _labels = ['All', 'Downloading', 'Completed'];
  static const _filters = [
    TorrentFilter.all,
    TorrentFilter.downloading,
    TorrentFilter.completed,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final pillWidth = totalWidth / 3;
        const pillInset = 3.0;

        return Container(
          height: 44,
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
          child: Stack(
            children: [
              // ── Sliding pill ─────────────────────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                left: _activeIndex * pillWidth + pillInset,
                top: pillInset,
                bottom: pillInset,
                width: pillWidth - pillInset * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.downloading,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.downloading.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Label row ────────────────────────────────────────────
              Row(
                children: List.generate(3, (i) {
                  final isActive = i == _activeIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(_filters[i]),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: GoogleFonts.outfit(
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary(context),
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: isActive ? -0.1 : 0,
                          ),
                          child: Text(_labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
