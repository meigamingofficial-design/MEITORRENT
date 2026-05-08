import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Shown when there are no torrents yet.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.downloading.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.downloading.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.download_rounded, color: AppColors.downloading, size: 48),
            ),
            const SizedBox(height: 32),
            const Text(
              'No torrents yet',
              style: TextStyle(
                color: AppColors.inkBlack,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap "Add Torrent" to paste a magnet link\nor open a .torrent file to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkGrey,
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
