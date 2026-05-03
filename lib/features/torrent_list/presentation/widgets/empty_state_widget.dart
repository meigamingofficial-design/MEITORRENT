import 'package:flutter/material.dart';

/// Shown when there are no torrents yet.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_rounded, color: Color(0xFF6C63FF), size: 44),
          ),
          const SizedBox(height: 24),
          const Text(
            'No torrents yet',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Add Torrent" to paste a\nmagnet link or open a .torrent file',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, height: 1.5),
          ),
        ],
      ),
    );
  }
}
