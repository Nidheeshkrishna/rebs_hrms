import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/network/api_client.dart';
import 'package:rebs_hrms/core/network/mock_http_client.dart';
import 'package:rebs_hrms/core/network/network_info.dart';
import 'package:rebs_hrms/core/storage/database_helper.dart';
import 'package:rebs_hrms/core/utils/geofence_utils.dart';
import 'package:rebs_hrms/data/models/attendance_model.dart';
import 'package:rebs_hrms/data/models/employee_model.dart';
import 'package:rebs_hrms/data/repositories/attendance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockNetworkInfo implements NetworkInfo {
  final bool online;
  MockNetworkInfo({this.online = true});

  @override
  Future<bool> get isConnected async => online;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(online);
}

void main() {
  // Initialize ffi for sqlite in dart tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late AttendanceRepository repository;
  late Employee employee;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);

    // Create tables
    await db.execute('''
      CREATE TABLE employee_cache (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        role TEXT NOT NULL,
        office_lat REAL NOT NULL,
        office_lng REAL NOT NULL,
        geofence_radius REAL NOT NULL,
        timezone TEXT NOT NULL
      )
    ''');
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
    final mockHttp = MockHttpClient();
    final apiClient = ApiClient(client: mockHttp);
    final networkInfo = MockNetworkInfo(online: true);

    repository = AttendanceRepository(
      apiClient: apiClient,
      dbHelper: dbHelper,
      networkInfo: networkInfo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Required Test 1: Attendance Check-In & Check-Out Rules', () {
    test('Check-out without check-in is rejected', () async {
      final now = DateTime(2026, 3, 15, 17, 30);

      expect(
        () => repository.checkOut(
          employee: employee,
          timestamp: now,
          latitude: employee.officeLatitude,
          longitude: employee.officeLongitude,
          distanceMeters: 10.0,
        ),
        throwsA(isA<AttendanceValidationException>().having(
          (e) => e.message,
          'message',
          contains('Cannot check out without checking in first'),
        )),
      );
    });

    test('Valid check-in followed by check-out succeeds', () async {
      final inTime = DateTime(2026, 3, 15, 9, 15);
      final outTime = DateTime(2026, 3, 15, 18, 0);

      // Check-in
      final checkInRecord = await repository.checkIn(
        employee: employee,
        timestamp: inTime,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 5.0,
      );

      expect(checkInRecord.dailyStatus, DailyAttendanceStatus.checkedIn);
      expect(checkInRecord.checkInTime, inTime);

      // Check-out
      final checkOutRecord = await repository.checkOut(
        employee: employee,
        timestamp: outTime,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 10.0,
      );

      expect(checkOutRecord.dailyStatus, DailyAttendanceStatus.checkedOut);
      expect(checkOutRecord.checkOutTime, outTime);
    });

    test('Multiple check-ins on the same day are rejected', () async {
      final inTime = DateTime(2026, 3, 15, 9, 0);
      final secondInTime = DateTime(2026, 3, 15, 9, 30);

      await repository.checkIn(
        employee: employee,
        timestamp: inTime,
        latitude: employee.officeLatitude,
        longitude: employee.officeLongitude,
        distanceMeters: 0.0,
      );

      expect(
        () => repository.checkIn(
          employee: employee,
          timestamp: secondInTime,
          latitude: employee.officeLatitude,
          longitude: employee.officeLongitude,
          distanceMeters: 0.0,
        ),
        throwsA(isA<AttendanceValidationException>().having(
          (e) => e.message,
          'message',
          contains('Check-in already completed for today'),
        )),
      );
    });

    test('Geofence validation: under 200m accepted, beyond 200m rejected', () {
      final officeLat = 10.0159;
      final officeLng = 76.3419;

      // 50m north
      final lat50m = officeLat + 0.00045;
      final dist50m = GeofenceUtils.calculateDistanceMeters(lat50m, officeLng, officeLat, officeLng);
      expect(dist50m, lessThan(100.0));
      expect(GeofenceUtils.isWithinGeofence(lat50m, officeLng, officeLat, officeLng), isTrue);

      // 450m north
      final lat450m = officeLat + 0.00405;
      final dist450m = GeofenceUtils.calculateDistanceMeters(lat450m, officeLng, officeLat, officeLng);
      expect(dist450m, greaterThan(200.0));
      expect(GeofenceUtils.isWithinGeofence(lat450m, officeLng, officeLat, officeLng), isFalse);
    });
  });
}
