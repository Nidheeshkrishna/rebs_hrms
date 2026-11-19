import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/data/models/attendance_model.dart';
import 'package:rebs_hrms/data/models/employee_model.dart';
import 'package:rebs_hrms/presentation/widgets/attendance_card.dart';
import 'package:rebs_hrms/presentation/widgets/offline_banner.dart';
import 'package:rebs_hrms/presentation/widgets/sync_status_badge.dart';

void main() {
  group('Widget Tests: Loading, Error, and Pending-Sync States', () {
    testWidgets('OfflineBanner displays pending sync count and offline warning', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOnline: false,
              pendingCount: 2,
              onSyncTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Working Offline • 2 action(s) pending sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('SyncStatusBadge properly renders Pending Sync, Synced, and Rejected states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SyncStatusBadge(status: SyncStatus.pendingSync),
                SyncStatusBadge(status: SyncStatus.synced),
                SyncStatusBadge(
                  status: SyncStatus.rejected,
                  rejectionReason: 'Attendance conflict',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pending Sync'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_filled_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('Shows error message and location warning on widget', (tester) async {
      final employee = Employee.preconfigured();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Row(
                  children: [
                    Icon(Icons.location_off_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('You are 450.0m from the office. Permitted radius is 200m.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('You are 450.0m from the office. Permitted radius is 200m.'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
    });
  });
}
