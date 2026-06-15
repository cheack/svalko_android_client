import 'package:flutter/material.dart';

String formatMediaBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

class MediaLoadBadge extends StatelessWidget {
  const MediaLoadBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
