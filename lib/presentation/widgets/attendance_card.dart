import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../providers/attendance_provider.dart';
import 'sync_status_badge.dart';

class AttendanceCard extends StatelessWidget {
  final Employee employee;
  final AttendanceProvider attendanceProvider;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback? onReset;

  const AttendanceCard({
    super.key,
    required this.employee,
    required this.attendanceProvider,
    required this.onCheckIn,
    required this.onCheckOut,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayRecord = attendanceProvider.todayRecord;
    final status = attendanceProvider.todayStatus;
    final elapsed = attendanceProvider.elapsedDuration;
    final isBusy = attendanceProvider.isActionInProgress;

    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (status) {
      case DailyAttendanceStatus.checkedIn:
        statusColor = const Color(0xFF1976D2); // Primary Blue
        statusTitle = 'Checked In';
        statusIcon = Icons.fingerprint_rounded;
        break;
      case DailyAttendanceStatus.checkedOut:
        statusColor = const Color(0xFF2E7D32); // Success Green
        statusTitle = 'Checked Out';
        statusIcon = Icons.done_all_rounded;
        break;
      case DailyAttendanceStatus.notCheckedIn:
        statusColor = const Color(0xFF757575); // Neutral Grey
        statusTitle = 'Not Checked In';
        statusIcon = Icons.schedule_rounded;
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Attendance",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (todayRecord != null)
                  SyncStatusBadge(
                    status: todayRecord.syncStatus,
                    rejectionReason: todayRecord.rejectionReason,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Time and Duration Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Check-in Time
                  Expanded(
                    child: _buildTimeMetric(
                      label: 'Check In',
                      value: todayRecord?.checkInTime != null
                          ? AppDateUtils.formatTime(todayRecord!.checkInTime!)
                          : '--:--',
                      icon: Icons.login_rounded,
                      color: Colors.indigo,
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  // Check-out Time
                  Expanded(
                    child: _buildTimeMetric(
                      label: 'Check Out',
                      value: todayRecord?.checkOutTime != null
                          ? AppDateUtils.formatTime(todayRecord!.checkOutTime!)
                          : '--:--',
                      icon: Icons.logout_rounded,
                      color: Colors.deepOrange,
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  // Elapsed Working Duration
                  Expanded(
                    child: _buildTimeMetric(
                      label: 'Elapsed',
                      value: status == DailyAttendanceStatus.notCheckedIn
                          ? '0h 00m'
                          : AppDateUtils.formatDuration(elapsed, includeSeconds: false),
                      icon: Icons.timer_outlined,
                      color: Colors.teal,
                      isHighlighted: status == DailyAttendanceStatus.checkedIn,
                    ),
                  ),
                ],
              ),
            ),

            // Location Warning Banner if outside geofence
            if (attendanceProvider.locationWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attendanceProvider.locationWarning!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: _buildActionButton(
                status: status,
                isBusy: isBusy,
                onCheckIn: onCheckIn,
                onCheckOut: onCheckOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? Colors.teal.shade800 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required DailyAttendanceStatus status,
    required bool isBusy,
    required VoidCallback onCheckIn,
    required VoidCallback onCheckOut,
  }) {
    if (isBusy) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case DailyAttendanceStatus.notCheckedIn:
        return ElevatedButton.icon(
          onPressed: onCheckIn,
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Check In Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case DailyAttendanceStatus.checkedIn:
        return ElevatedButton.icon(
          onPressed: onCheckOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Check Out'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case DailyAttendanceStatus.checkedOut:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null, // Disabled: only 1 session per day allowed
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                label: const Text('Session Completed'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (onReset != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Reset Attendance Session',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: onReset,
              ),
            ],
          ],
        );
    }
  }
}
