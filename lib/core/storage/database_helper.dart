import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/leave_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  /// For unit testing or injecting a mock/custom database
  factory DatabaseHelper.withDatabase(Database db) {
    final helper = DatabaseHelper._internal();
    _database = db;
    return helper;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'rebs_hrms.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  // ================= Employee Cache ================= //
  Future<void> saveEmployee(Employee emp) async {
    final db = await database;
    await db.insert(
      'employee_cache',
      {
        'id': emp.id,
        'name': emp.name,
        'department': emp.department,
        'role': emp.role,
        'office_lat': emp.officeLatitude,
        'office_lng': emp.officeLongitude,
        'geofence_radius': emp.geofenceRadiusMeters,
        'timezone': emp.timezone,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Employee?> getEmployee(String id) async {
    final db = await database;
    final maps = await db.query('employee_cache', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final row = maps.first;
    return Employee(
      id: row['id'] as String,
      name: row['name'] as String,
      department: row['department'] as String,
      role: row['role'] as String,
      officeLatitude: row['office_lat'] as double,
      officeLongitude: row['office_lng'] as double,
      geofenceRadiusMeters: row['geofence_radius'] as double,
      timezone: row['timezone'] as String,
    );
  }

  // ================= Attendance Records ================= //
  Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    final db = await database;
    await db.insert(
      'attendance_records',
      {
        'id': record.id,
        'employee_id': record.employeeId,
        'date': record.date,
        'check_in_time': record.checkInTime?.toIso8601String(),
        'check_in_lat': record.checkInLatitude,
        'check_in_lng': record.checkInLongitude,
        'check_out_time': record.checkOutTime?.toIso8601String(),
        'check_out_lat': record.checkOutLatitude,
        'check_out_lng': record.checkOutLongitude,
        'sync_status': record.syncStatus.name,
        'rejection_reason': record.rejectionReason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAttendanceRecords(List<AttendanceRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        'attendance_records',
        {
          'id': record.id,
          'employee_id': record.employeeId,
          'date': record.date,
          'check_in_time': record.checkInTime?.toIso8601String(),
          'check_in_lat': record.checkInLatitude,
          'check_in_lng': record.checkInLongitude,
          'check_out_time': record.checkOutTime?.toIso8601String(),
          'check_out_lat': record.checkOutLatitude,
          'check_out_lng': record.checkOutLongitude,
          'sync_status': record.syncStatus.name,
          'rejection_reason': record.rejectionReason,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<AttendanceRecord?> getAttendanceForDate(String employeeId, String date) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    if (maps.isEmpty) return null;
    return _mapToAttendanceRecord(maps.first);
  }

  Future<List<AttendanceRecord>> getAttendanceHistory(String employeeId, {int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map(_mapToAttendanceRecord).toList();
  }

  AttendanceRecord _mapToAttendanceRecord(Map<String, dynamic> row) {
    return AttendanceRecord(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      date: row['date'] as String,
      checkInTime: row['check_in_time'] != null
          ? DateTime.parse(row['check_in_time'] as String)
          : null,
      checkInLatitude: row['check_in_lat'] as double?,
      checkInLongitude: row['check_in_lng'] as double?,
      checkOutTime: row['check_out_time'] != null
          ? DateTime.parse(row['check_out_time'] as String)
          : null,
      checkOutLatitude: row['check_out_lat'] as double?,
      checkOutLongitude: row['check_out_lng'] as double?,
      syncStatus: _parseSyncStatus(row['sync_status'] as String?),
      rejectionReason: row['rejection_reason'] as String?,
    );
  }

  // ================= Attendance Events Queue ================= //
  Future<void> enqueueAttendanceEvent(AttendanceEvent event) async {
    final db = await database;
    await db.insert(
      'attendance_events_queue',
      {
        'event_id': event.eventId,
        'employee_id': event.employeeId,
        'event_type': event.eventType.name,
        'timestamp': event.timestamp.toIso8601String(),
        'latitude': event.latitude,
        'longitude': event.longitude,
        'distance_meters': event.distanceMeters,
        'date': event.date,
        'sync_status': event.syncStatus.name,
        'rejection_reason': event.rejectionReason,
        'created_at': event.createdAt.toIso8601String(),
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AttendanceEvent>> getPendingEvents() async {
    final db = await database;
    final maps = await db.query(
      'attendance_events_queue',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingSync.name],
      orderBy: 'created_at ASC', // FIFO to preserve ordering
    );
    return maps.map(_mapToAttendanceEvent).toList();
  }

  Future<List<AttendanceEvent>> getAllEvents() async {
    final db = await database;
    final maps = await db.query(
      'attendance_events_queue',
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToAttendanceEvent).toList();
  }

  Future<void> updateEventSyncStatus(
    String eventId,
    SyncStatus status, {
    String? rejectionReason,
  }) async {
    final db = await database;
    await db.update(
      'attendance_events_queue',
      {
        'sync_status': status.name,
        'rejection_reason': rejectionReason,
      },
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> incrementEventRetryCount(String eventId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE attendance_events_queue 
      SET retry_count = retry_count + 1 
      WHERE event_id = ?
    ''', [eventId]);
  }

  AttendanceEvent _mapToAttendanceEvent(Map<String, dynamic> row) {
    return AttendanceEvent(
      eventId: row['event_id'] as String,
      employeeId: row['employee_id'] as String,
      eventType: row['event_type'] == 'checkOut'
          ? AttendanceEventType.checkOut
          : AttendanceEventType.checkIn,
      timestamp: DateTime.parse(row['timestamp'] as String),
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      distanceMeters: row['distance_meters'] as double,
      date: row['date'] as String,
      syncStatus: _parseSyncStatus(row['sync_status'] as String?),
      rejectionReason: row['rejection_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ================= Leave Cache ================= //
  Future<void> saveLeaveBalance(LeaveBalance balance) async {
    final db = await database;
    await db.insert(
      'leave_balance_cache',
      {
        'id': 1,
        'casual': balance.casual,
        'sick': balance.sick,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LeaveBalance?> getLeaveBalance() async {
    final db = await database;
    final maps = await db.query('leave_balance_cache', where: 'id = 1');
    if (maps.isEmpty) return null;
    return LeaveBalance(
      casual: maps.first['casual'] as int,
      sick: maps.first['sick'] as int,
    );
  }

  Future<void> saveLeaveRequests(List<LeaveRequest> requests) async {
    final db = await database;
    final batch = db.batch();
    for (final req in requests) {
      batch.insert(
        'leave_requests_cache',
        {
          'id': req.id,
          'employee_id': req.employeeId,
          'type': req.type.name,
          'start_date': req.startDate.toIso8601String().split('T').first,
          'end_date': req.endDate.toIso8601String().split('T').first,
          'days_count': req.daysCount,
          'reason': req.reason,
          'status': req.status.name,
          'applied_at': req.appliedAt.toIso8601String(),
          'rejection_reason': req.rejectionReason,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertLeaveRequest(LeaveRequest req) async {
    final db = await database;
    await db.insert(
      'leave_requests_cache',
      {
        'id': req.id,
        'employee_id': req.employeeId,
        'type': req.type.name,
        'start_date': req.startDate.toIso8601String().split('T').first,
        'end_date': req.endDate.toIso8601String().split('T').first,
        'days_count': req.daysCount,
        'reason': req.reason,
        'status': req.status.name,
        'applied_at': req.appliedAt.toIso8601String(),
        'rejection_reason': req.rejectionReason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LeaveRequest>> getLeaveRequests(String employeeId) async {
    final db = await database;
    final maps = await db.query(
      'leave_requests_cache',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'applied_at DESC',
    );
    return maps.map((row) {
      return LeaveRequest(
        id: row['id'] as String,
        employeeId: row['employee_id'] as String,
        type: row['type'] == 'sick' ? LeaveType.sick : LeaveType.casual,
        startDate: DateTime.parse(row['start_date'] as String),
        endDate: DateTime.parse(row['end_date'] as String),
        daysCount: row['days_count'] as int,
        reason: row['reason'] as String,
        status: _parseLeaveStatus(row['status'] as String?),
        appliedAt: DateTime.parse(row['applied_at'] as String),
        rejectionReason: row['rejection_reason'] as String?,
      );
    }).toList();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('employee_cache');
    await db.delete('attendance_records');
    await db.delete('attendance_events_queue');
    await db.delete('leave_balance_cache');
    await db.delete('leave_requests_cache');
  }

  Future<void> resetAttendanceRecords() async {
    final db = await database;
    await db.delete('attendance_records');
    await db.delete('attendance_events_queue');
  }

  static SyncStatus _parseSyncStatus(String? str) {
    switch (str) {
      case 'pendingSync':
        return SyncStatus.pendingSync;
      case 'rejected':
        return SyncStatus.rejected;
      case 'synced':
      default:
        return SyncStatus.synced;
    }
  }

  static LeaveStatus _parseLeaveStatus(String? str) {
    switch (str) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'pending':
      default:
        return LeaveStatus.pending;
    }
  }
}
