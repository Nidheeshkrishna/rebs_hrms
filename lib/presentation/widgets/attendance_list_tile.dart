import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_model.dart';
import 'sync_status_badge.dart';

class AttendanceListTile extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceListTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    DateTime parsedDate;
    try {
      parsedDate = AppDateUtils.parseDateIso(record.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final duration = record.workingDuration;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Date Box
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  parsedDate.day.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                Text(
                  ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][parsedDate.month - 1],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // In & Out times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      record.checkInTime != null
                          ? AppDateUtils.formatTime(record.checkInTime!)
                          : '--:--',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.logout_rounded, size: 14, color: Colors.deepOrange),
                    const SizedBox(width: 4),
                    Text(
                      record.checkOutTime != null
                          ? AppDateUtils.formatTime(record.checkOutTime!)
                          : '--:--',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${AppDateUtils.formatDuration(duration, includeSeconds: false)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Sync badge
          SyncStatusBadge(
            status: record.syncStatus,
            rejectionReason: record.rejectionReason,
            compact: false,
          ),
        ],
      ),
    );
  }
}
