import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/employee_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/leave_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/attendance_card.dart';
import '../widgets/attendance_list_tile.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/offline_banner.dart';
import 'history_screen.dart';
import 'leave_apply_screen.dart';
import 'leave_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final empProv = context.read<EmployeeProvider>();
    await empProv.loadEmployee();
    if (empProv.employee != null && mounted) {
      final emp = empProv.employee!;
      context.read<AttendanceProvider>().initialize(emp);
      context.read<LeaveProvider>().loadLeaveData(emp.id);
    }
  }

  Future<void> _handleResetAttendance(BuildContext context, Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Reset Attendance?'),
          ],
        ),
        content: const Text(
          'This will clear today\'s attendance record so you can mark Check In & Check Out fresh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset Now'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<EmployeeProvider>().loadEmployee(forceRefresh: true);
      final refreshedEmp = context.read<EmployeeProvider>().employee ?? employee;
      await context.read<AttendanceProvider>().resetAttendance(refreshedEmp);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance reset. You can now mark Check In fresh!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of REBS HRMS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final employee = employeeProvider.employee;

    // Show error snackbar if any
    if (attendanceProvider.errorMessage != null) {
      final errorMsg = attendanceProvider.errorMessage!;
      final isGeofenceError = errorMsg.contains('away from the office') || errorMsg.contains('permitted radius');
      final lat = attendanceProvider.lastKnownLat;
      final lng = attendanceProvider.lastKnownLng;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 6),
            action: (isGeofenceError && lat != null && lng != null)
                ? SnackBarAction(
                    label: 'Set as Office',
                    textColor: Colors.amber,
                    onPressed: () async {
                      await context.read<EmployeeProvider>().updateOfficeLocation(lat, lng);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Office location updated to your GPS! Tap Check In now.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  )
                : SnackBarAction(
                    label: 'Dismiss',
                    textColor: Colors.white,
                    onPressed: () => attendanceProvider.clearErrorMessage(),
                  ),
          ),
        );
        attendanceProvider.clearErrorMessage();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REBS HRMS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Employee Workspace',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // Manual "Sync Now" button
          IconButton(
            tooltip: 'Sync Now',
            icon: syncProvider.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Badge(
                    isLabelVisible: attendanceProvider.pendingEventsCount > 0,
                    label: Text('${attendanceProvider.pendingEventsCount}'),
                    child: const Icon(Icons.sync_rounded),
                  ),
            onPressed: syncProvider.isSyncing || employee == null
                ? null
                : () async {
                    final res = await syncProvider.triggerManualSync(
                      attendanceProvider: attendanceProvider,
                      employee: employee,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(syncProvider.syncMessage ?? 'Sync completed'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
          ),
          // Reset Attendance Button
          IconButton(
            tooltip: 'Reset Attendance Session',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: employee == null
                ? null
                : () => _handleResetAttendance(context, employee),
          ),
          // Logout Action Button
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline Banner
          OfflineBanner(
            isOnline: syncProvider.isOnline,
            pendingCount: attendanceProvider.pendingEventsCount,
            onSyncTap: employee != null
                ? () => syncProvider.triggerManualSync(
                      attendanceProvider: attendanceProvider,
                      employee: employee,
                    )
                : null,
          ),

          // Main Scrollable Content
          Expanded(
            child: employeeProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : employee == null
                    ? _buildErrorView(employeeProvider.errorMessage)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await employeeProvider.loadEmployee(forceRefresh: true);
                          if (mounted) {
                            await attendanceProvider.initialize(employee);
                            await leaveProvider.loadLeaveData(employee.id, forceRefresh: true);
                          }
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          children: [
                            // 1. Employee Profile Header Card
                            _buildEmployeeHeaderCard(employee),

                            const SizedBox(height: 12),

                            // 2. Attendance Action & Today Status Card
                            AttendanceCard(
                              employee: employee,
                              attendanceProvider: attendanceProvider,
                              onCheckIn: () => attendanceProvider.handleCheckIn(employee),
                              onCheckOut: () => attendanceProvider.handleCheckOut(employee),
                              onReset: () => _handleResetAttendance(context, employee),
                            ),

                            const SizedBox(height: 12),

                            // 3. Leave Balance Card
                            LeaveBalanceCard(
                              balance: leaveProvider.balance,
                              isLoading: leaveProvider.isLoading,
                              onApplyLeave: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LeaveApplyScreen(employee: employee),
                                  ),
                                );
                              },
                              onViewHistory: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LeaveScreen(employee: employee),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // 4. Latest 5 Attendance Records Section
                            _buildRecentAttendanceSection(context, attendanceProvider, employee),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeaderCard(dynamic employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              employee.name.split(' ').map((e) => e[0]).take(2).join(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee.id} • ${employee.department}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.role,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendanceSection(
    BuildContext context,
    AttendanceProvider provider,
    dynamic employee,
  ) {
    final records = provider.recentRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Attendance (Latest 5)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(employee: employee),
                  ),
                );
              },
              child: const Text('View Queue'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (provider.isLoading && records.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (records.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 36, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No attendance records found yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ...records.take(5).map((record) => AttendanceListTile(record: record)),
      ],
    );
  }

  Widget _buildErrorView(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Failed to load employee workspace',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
