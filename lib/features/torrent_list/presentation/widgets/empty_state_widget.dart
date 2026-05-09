import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
                color: AppColors.downloading.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.downloading.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.download_rounded, 
                               color: AppColors.downloading, size: 48),
            ),
            const SizedBox(height: 32),
            Text(
              'No torrents yet',
              style: GoogleFonts.shipporiMincho(
                color: AppColors.text(context),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap "Add Torrent" to paste a magnet link\nor open a .torrent file to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
