import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final VoidCallback? onSyncTap;

  const OfflineBanner({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    if (!isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF424242),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pendingCount > 0
                    ? 'Working Offline • $pendingCount action(s) pending sync'
                    : 'Working Offline • Changes are cached locally',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Online but has pending events
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$pendingCount attendance action(s) ready to sync',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onSyncTap != null)
            GestureDetector(
              onTap: onSyncTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  'SYNC NOW',
                  style: TextStyle(
                    color: Color(0xFFBF360C),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
