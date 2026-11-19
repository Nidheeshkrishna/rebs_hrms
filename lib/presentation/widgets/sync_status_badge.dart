import 'package:flutter/material.dart';
import '../../data/models/attendance_model.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  final String? rejectionReason;
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.status,
    this.rejectionReason,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case SyncStatus.synced:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        label = 'Synced';
        break;
      case SyncStatus.pendingSync:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        icon = Icons.access_time_filled_rounded;
        label = 'Pending Sync';
        break;
      case SyncStatus.rejected:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        icon = Icons.error_rounded;
        label = 'Rejected';
        break;
    }

    if (compact) {
      return Tooltip(
        message: rejectionReason ?? label,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: fg),
        ),
      );
    }

    return Tooltip(
      message: rejectionReason ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
