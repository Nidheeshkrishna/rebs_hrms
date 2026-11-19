import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/network/api_client.dart';
import 'package:rebs_hrms/core/network/mock_http_client.dart';
import 'package:rebs_hrms/core/network/network_info.dart';
import 'package:rebs_hrms/core/storage/database_helper.dart';
import 'package:rebs_hrms/data/models/attendance_model.dart';
import 'package:rebs_hrms/data/models/employee_model.dart';
import 'package:rebs_hrms/data/repositories/attendance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SwitchableNetworkInfo implements NetworkInfo {
  bool isOnline;
  SwitchableNetworkInfo({required this.isOnline});

  @override
  Future<bool> get isConnected async => isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(isOnline);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late MockHttpClient mockHttp;
  late ApiClient apiClient;
  late SwitchableNetworkInfo networkInfo;
  late AttendanceRepository repository;
  late Employee employee;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);

    await db.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        date TEXT NOT NULL UNIQUE,
        check_in_time TEXT,
        check_in_lat REAL,
        check_in_lng REAL,
        check_out_time TEXT,
        check_out_lat REAL,
        check_out_lng REAL,
        sync_status TEXT NOT NULL,
        rejection_reason TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE attendance_events_queue (
        event_id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        distance_meters REAL NOT NULL,
        date TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        rejection_reason TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    employee = Employee.preconfigured();
    mockHttp = MockHttpClient();
    apiClient = ApiClient(client: mockHttp);
    networkInfo = SwitchableNetworkInfo(isOnline: false); // Start offline

    repository = AttendanceRepository(
      apiClient: apiClient,
      dbHelper: dbHelper,
      networkInfo: networkInfo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Required Test 2 & 3: Persistence, FIFO Sync, and Idempotency', () {
    test('Pending attendance survives persistence and is saved as pendingSync when offline', () async {
      final now = DateTime(2026, 3, 20, 9, 30);

      // Perform check-in while offline
      final record = await repository.checkIn(
        employee: employee,
        timestamp: now,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 10.0,
      );

      expect(record.syncStatus, SyncStatus.pendingSync);

      // Verify it is preserved in SQLite database
      final pendingEvents = await dbHelper.getPendingEvents();
      expect(pendingEvents.length, 1);
      expect(pendingEvents.first.eventType, AttendanceEventType.checkIn);
      expect(pendingEvents.first.syncStatus, SyncStatus.pendingSync);

      final dbRecord = await dbHelper.getAttendanceForDate(employee.id, '2026-03-20');
      expect(dbRecord, isNotNull);
      expect(dbRecord!.syncStatus, SyncStatus.pendingSync);
    });

    test('Pending attendance survives simulated app restart and synchronizes in order', () async {
      final checkInTime = DateTime(2026, 3, 20, 9, 0);
      final checkOutTime = DateTime(2026, 3, 20, 18, 0);

      // 1. Employee checks in and checks out while offline
      networkInfo.isOnline = false;
      await repository.checkIn(
        employee: employee,
        timestamp: checkInTime,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 5.0,
      );
      await repository.checkOut(
        employee: employee,
        timestamp: checkOutTime,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 8.0,
      );

      // Check queue has 2 pending events in FIFO order
      final queueBeforeRestart = await dbHelper.getPendingEvents();
      expect(queueBeforeRestart.length, 2);
      expect(queueBeforeRestart[0].eventType, AttendanceEventType.checkIn);
      expect(queueBeforeRestart[1].eventType, AttendanceEventType.checkOut);

      // 2. Simulate App Restart: Create fresh repository instance with same database
      final freshRepository = AttendanceRepository(
        apiClient: apiClient,
        dbHelper: dbHelper,
        networkInfo: networkInfo,
      );

      final pendingAfterRestart = await freshRepository.dbHelper.getPendingEvents();
      expect(pendingAfterRestart.length, 2);

      // 3. Reconnect to network and trigger synchronization
      networkInfo.isOnline = true;
      final syncResult = await freshRepository.synchronizePendingEvents();

      expect(syncResult.isSuccess, isTrue);
      expect(syncResult.total, 2);
      expect(syncResult.synced, 2);
      expect(syncResult.failed, 0);

      // 4. Verify all queue items and records are now Synced
      final remainingPending = await dbHelper.getPendingEvents();
      expect(remainingPending.isEmpty, isTrue);

      final finalRecord = await dbHelper.getAttendanceForDate(employee.id, '2026-03-20');
      expect(finalRecord, isNotNull);
      expect(finalRecord!.syncStatus, SyncStatus.synced);
      expect(finalRecord.checkInTime, isNotNull);
      expect(finalRecord.checkOutTime, isNotNull);
    });

    test('Repeated submission or retry does not create duplicate attendance (Idempotency Key)', () async {
      networkInfo.isOnline = true;
      final now = DateTime(2026, 3, 21, 9, 15);

      final record = await repository.checkIn(
        employee: employee,
        timestamp: now,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 10.0,
      );
      expect(record.syncStatus, SyncStatus.synced);

      // Extract the event that was sent
      final allEvents = await dbHelper.getAllEvents();
      final sentEvent = allEvents.first;

      // Simulate a network retry of the exact same event (same eventId)
      final retryResult = await apiClient.submitAttendanceEvent(sentEvent);
      expect(retryResult, isNotNull);
      expect(retryResult!.date, '2026-03-21');

      // Server records count should remain exactly 1 for date 2026-03-21
      final history = await apiClient.getAttendanceHistory('2026-03');
      final matchesForDate = history.where((r) => r.date == '2026-03-21').toList();
      expect(matchesForDate.length, 1);
    });

    test('Conflict response from server marks event as Rejected with reason', () async {
      networkInfo.isOnline = true;
      mockHttp.scenario = MockScenario.duplicateAttendanceConflict;

      final now = DateTime(2026, 3, 22, 9, 0);
      final record = await repository.checkIn(
        employee: employee,
        timestamp: now,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 5.0,
      );

      expect(record.syncStatus, SyncStatus.rejected);
      expect(record.rejectionReason, contains('Attendance record already exists'));

      final dbRecord = await dbHelper.getAttendanceForDate(employee.id, '2026-03-22');
      expect(dbRecord!.syncStatus, SyncStatus.rejected);
    });
  });
}
