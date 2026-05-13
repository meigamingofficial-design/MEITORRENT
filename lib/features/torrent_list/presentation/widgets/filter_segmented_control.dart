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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _FilterItem(
            label: 'All',
            isActive: activeFilter == TorrentFilter.all,
            onTap: () => onChanged(TorrentFilter.all),
          ),
          _FilterItem(
            label: 'Downloading',
            isActive: activeFilter == TorrentFilter.downloading,
            onTap: () => onChanged(TorrentFilter.downloading),
          ),
          _FilterItem(
            label: 'Completed',
            isActive: activeFilter == TorrentFilter.completed,
            onTap: () => onChanged(TorrentFilter.completed),
          ),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.downloading.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.shipporiMincho(
              color: isActive
                  ? AppColors.downloading
                  : AppColors.textSecondary(context),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
