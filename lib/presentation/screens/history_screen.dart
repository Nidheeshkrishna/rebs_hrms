import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/attendance_list_tile.dart';
import '../widgets/sync_status_badge.dart';

class HistoryScreen extends StatelessWidget {
  final Employee employee;

  const HistoryScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final records = attendanceProvider.recentRecords;
    final queuedEvents = attendanceProvider.queuedEvents;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance & Sync Queue'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'History Records'),
              Tab(text: 'Offline Sync Queue'),
            ],
          ),
          actions: [
            IconButton(
              icon: syncProvider.isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              onPressed: syncProvider.isSyncing
                  ? null
                  : () => syncProvider.triggerManualSync(
                        attendanceProvider: attendanceProvider,
                        employee: employee,
                      ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Attendance History
            RefreshIndicator(
              onRefresh: () => attendanceProvider.initialize(employee),
              child: records.isEmpty
                  ? const Center(child: Text('No attendance records available'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        return AttendanceListTile(record: records[index]);
                      },
                    ),
            ),

            // Tab 2: Offline Sync Queue
            queuedEvents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          'Sync Queue is Empty',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All attendance actions are synchronized with the server.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: queuedEvents.length,
                    itemBuilder: (context, index) {
                      final ev = queuedEvents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        ev.eventType == AttendanceEventType.checkIn
                                            ? Icons.login_rounded
                                            : Icons.logout_rounded,
                                        size: 18,
                                        color: ev.eventType == AttendanceEventType.checkIn
                                            ? Colors.green
                                            : Colors.deepOrange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ev.eventType.label,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  SyncStatusBadge(
                                    status: ev.syncStatus,
                                    rejectionReason: ev.rejectionReason,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Time: ${AppDateUtils.formatDateTime(ev.timestamp)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'GPS: ${ev.latitude.toStringAsFixed(5)}, ${ev.longitude.toStringAsFixed(5)} (${ev.distanceMeters.toStringAsFixed(1)}m from office)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Idempotency Key: ${ev.eventId}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (ev.rejectionReason != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Rejection: ${ev.rejectionReason}',
                                    style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
