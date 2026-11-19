import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/leave_model.dart';
import '../providers/leave_provider.dart';
import '../providers/sync_provider.dart';
import 'leave_apply_screen.dart';

class LeaveScreen extends StatelessWidget {
  final Employee employee;

  const LeaveScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final requests = leaveProvider.requests;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => leaveProvider.loadLeaveData(employee.id, forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LeaveApplyScreen(employee: employee),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
      body: Column(
        children: [
          if (!syncProvider.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1565C0),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Working offline: Showing cached requests. You can apply for leave offline anytime.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: leaveProvider.isLoading && requests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.beach_access_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No leave requests found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the button below to submit a leave application.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => leaveProvider.loadLeaveData(employee.id, forceRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            return _buildLeaveRequestCard(req);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest req) {
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    switch (req.status) {
      case LeaveStatus.approved:
        statusBg = const Color(0xFFE8F5E9);
        statusFg = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case LeaveStatus.rejected:
        statusBg = const Color(0xFFFFEBEE);
        statusFg = const Color(0xFFC62828);
        statusIcon = Icons.cancel_outlined;
        break;
      case LeaveStatus.pending:
      default:
        statusBg = const Color(0xFFFFF8E1);
        statusFg = const Color(0xFFF57F17);
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: req.type == LeaveType.casual
                            ? Colors.blue.shade50
                            : Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        req.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: req.type == LeaveType.casual
                              ? Colors.blue.shade800
                              : Colors.teal.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${req.daysCount} ${req.daysCount == 1 ? "day" : "days"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusFg.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusFg),
                      const SizedBox(width: 4),
                      Text(
                        req.status.label,
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${AppDateUtils.formatDisplayDate(req.startDate)} → ${AppDateUtils.formatDisplayDate(req.endDate)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              req.reason,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            if (req.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Rejection reason: ${req.rejectionReason}',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Applied: ${AppDateUtils.formatDateTime(req.appliedAt)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
