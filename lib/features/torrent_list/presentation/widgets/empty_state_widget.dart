import 'package:flutter/material.dart';

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
                color: const Color(0xFF00B894).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00B894).withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.download_rounded, color: Color(0xFF00B894), size: 48),
            ),
            const SizedBox(height: 32),
            const Text(
              'No torrents yet',
              style: TextStyle(
                color: Colors.white,
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
                color: Colors.white38,
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 60), // Optical offset
          ],
        ),
      ),
    );
  }
}
