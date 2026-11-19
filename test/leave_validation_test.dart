import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/core/network/api_client.dart';
import 'package:rebs_hrms/core/network/mock_http_client.dart';
import 'package:rebs_hrms/core/network/network_info.dart';
import 'package:rebs_hrms/core/storage/database_helper.dart';
import 'package:rebs_hrms/core/utils/date_utils.dart';
import 'package:rebs_hrms/data/models/leave_model.dart';
import 'package:rebs_hrms/data/repositories/leave_repository.dart';
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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late LeaveRepository repository;
  late DateTime companyDate;
  const balance = LeaveBalance(casual: 5, sick: 3);

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);

    await db.execute('''
      CREATE TABLE leave_balance_cache (
        id INTEGER PRIMARY KEY,
        casual INTEGER NOT NULL,
        sick INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE leave_requests_cache (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        days_count INTEGER NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        applied_at TEXT NOT NULL,
        rejection_reason TEXT
      )
    ''');

    companyDate = DateTime(2026, 4, 10);
    final mockHttp = MockHttpClient();
    final apiClient = ApiClient(client: mockHttp);
    final networkInfo = MockNetworkInfo(online: true);

    repository = LeaveRepository(
      apiClient: apiClient,
      dbHelper: dbHelper,
      networkInfo: networkInfo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Required Test 4: Leave Application Validations', () {
    test('Overlapping leave dates are rejected', () {
      final existingRequests = [
        LeaveRequest(
          id: 'ex_1',
          employeeId: 'EMP-1042',
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 15),
          endDate: DateTime(2026, 4, 18),
          daysCount: 4,
          reason: 'Family wedding event',
          status: LeaveStatus.approved,
          appliedAt: DateTime(2026, 4, 1),
        ),
      ];

      // Overlap case 1: Same start date
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 15),
          endDate: DateTime(2026, 4, 16),
          reason: 'Doctor consultation',
          balance: balance,
          existingRequests: existingRequests,
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('overlap'),
        )),
      );

      // Overlap case 2: Span across existing window
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 14),
          endDate: DateTime(2026, 4, 19),
          reason: 'Extended vacation trip',
          balance: balance,
          existingRequests: existingRequests,
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('overlap'),
        )),
      );

      // Non-overlapping dates succeed
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 20),
          endDate: DateTime(2026, 4, 22),
          reason: 'House shifting work',
          balance: balance,
          existingRequests: existingRequests,
          companyCurrentDate: companyDate,
        ),
        returnsNormally,
      );
    });

    test('Start date before current company date is rejected', () {
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.sick,
          startDate: DateTime(2026, 4, 9), // Yesterday
          endDate: DateTime(2026, 4, 11),
          reason: 'Fever and viral cough',
          balance: balance,
          existingRequests: [],
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('cannot be before current company date'),
        )),
      );
    });

    test('End date before start date is rejected', () {
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 15),
          endDate: DateTime(2026, 4, 12),
          reason: 'Valid long reason text',
          balance: balance,
          existingRequests: [],
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('End date cannot be before start date'),
        )),
      );
    });

    test('Reason with less than 10 non-whitespace characters is rejected', () {
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 12),
          endDate: DateTime(2026, 4, 12),
          reason: '   sick   ', // Only 4 non-whitespace chars
          balance: balance,
          existingRequests: [],
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('at least 10 non-whitespace characters'),
        )),
      );
    });

    test('Requested days exceeding available balance is rejected', () {
      // Casual balance is 5, request 6 days (April 12 to April 17)
      expect(
        () => repository.validateLeaveRequest(
          type: LeaveType.casual,
          startDate: DateTime(2026, 4, 12),
          endDate: DateTime(2026, 4, 17),
          reason: 'Long family religious festival',
          balance: balance,
          existingRequests: [],
          companyCurrentDate: companyDate,
        ),
        throwsA(isA<LeaveValidationException>().having(
          (e) => e.message,
          'message',
          contains('exceeds available'),
        )),
      );
    });

    test('All calendar days count as leave days (ignores weekends/holidays)', () {
      final start = DateTime(2026, 4, 10); // Friday
      final end = DateTime(2026, 4, 13); // Monday
      // Friday, Saturday, Sunday, Monday = 4 days
      final days = AppDateUtils.calculateLeaveDays(start, end);
      expect(days, 4);
    });
  });
}
