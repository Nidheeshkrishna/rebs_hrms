import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/leave_model.dart';

enum MockScenario {
  normal,
  slowTimeout,
  serverError,
  duplicateAttendanceConflict,
  leaveValidationRejection,
}

/// An in-process mock HTTP Client extending `http.BaseClient`.
/// It allows the Flutter app to execute genuine HTTP client calls (GET, POST, JSON encoding/decoding,
/// headers, status codes, timeouts) without needing an external process running, while perfectly
/// simulating all scenarios requested in the assignment.
class MockHttpClient extends http.BaseClient {
  MockScenario scenario = MockScenario.normal;
  final Set<String> _processedEventIds = {}; // Idempotency tracker
  final Map<String, AttendanceRecord> _serverAttendance = {}; // Date -> Record
  final List<LeaveRequest> _serverLeaves = [];
  LeaveBalance _serverLeaveBalance = const LeaveBalance(casual: 12, sick: 8);

  MockHttpClient() {
    _seedInitialData();
  }

  void _seedInitialData() {
    // Seed some historical attendance
    final now = DateTime.now();
    for (int i = 1; i <= 5; i++) {
      final pastDate = now.subtract(Duration(days: i));
      final dateStr = pastDate.toIso8601String().split('T').first;
      final checkIn = DateTime(pastDate.year, pastDate.month, pastDate.day, 9, 15 + i);
      final checkOut = DateTime(pastDate.year, pastDate.month, pastDate.day, 18, 00 + i);
      _serverAttendance[dateStr] = AttendanceRecord(
        id: 'rec_hist_$i',
        employeeId: 'EMP-1042',
        date: dateStr,
        checkInTime: checkIn,
        checkInLatitude: 10.0159,
        checkInLongitude: 76.3419,
        checkOutTime: checkOut,
        checkOutLatitude: 10.0160,
        checkOutLongitude: 76.3420,
        syncStatus: SyncStatus.synced,
      );
    }

    // Seed historical leave requests
    _serverLeaves.add(LeaveRequest(
      id: 'leave_101',
      employeeId: 'EMP-1042',
      type: LeaveType.casual,
      startDate: now.subtract(const Duration(days: 14)),
      endDate: now.subtract(const Duration(days: 13)),
      daysCount: 2,
      reason: 'Personal family event',
      status: LeaveStatus.approved,
      appliedAt: now.subtract(const Duration(days: 18)),
    ));
    _serverLeaves.add(LeaveRequest(
      id: 'leave_102',
      employeeId: 'EMP-1042',
      type: LeaveType.sick,
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now.subtract(const Duration(days: 7)),
      daysCount: 1,
      reason: 'Severe headache and doctor visit',
      status: LeaveStatus.approved,
      appliedAt: now.subtract(const Duration(days: 8)),
    ));
  }

  void reset() {
    _processedEventIds.clear();
    _serverAttendance.clear();
    _serverLeaves.clear();
    _serverLeaveBalance = const LeaveBalance(casual: 12, sick: 8);
    scenario = MockScenario.normal;
    _seedInitialData();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final path = uri.path;
    final method = request.method.toUpperCase();

    // 1. Simulate Slow Response / Timeout scenario
    if (scenario == MockScenario.slowTimeout) {
      await Future.delayed(const Duration(seconds: 10));
      return _jsonResponse({'error': 'Gateway Timeout'}, status: 504);
    }

    // 2. Simulate 500 Server Error scenario
    if (scenario == MockScenario.serverError) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _jsonResponse({
        'error': 'InternalServerError',
        'message': 'Database cluster connection failed unexpectedly',
      }, status: 500);
    }

    // Normal network latency simulation
    await Future.delayed(const Duration(milliseconds: 350));

    // ROUTING
    // ---------------- GET /employee/me ----------------
    if (method == 'GET' && path.endsWith('/employee/me')) {
      final emp = Employee.preconfigured();
      return _jsonResponse(emp.toJson());
    }

    // ---------------- GET /attendance ----------------
    if (method == 'GET' && path.endsWith('/attendance')) {
      final records = _serverAttendance.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return _jsonResponse(records.map((r) => r.toJson()).toList());
    }

    // ---------------- POST /attendance/events ----------------
    if (method == 'POST' && path.endsWith('/attendance/events')) {
      final bodyString = await _extractRequestBody(request);
      final json = jsonDecode(bodyString) as Map<String, dynamic>;
      final eventId = json['eventId'] as String;
      final eventType = json['eventType'] as String;
      final date = json['date'] as String;
      final timestamp = DateTime.parse(json['timestamp'] as String);
      final lat = (json['latitude'] as num).toDouble();
      final lng = (json['longitude'] as num).toDouble();

      // Check Duplicate Attendance Conflict Scenario
      if (scenario == MockScenario.duplicateAttendanceConflict &&
          eventType == 'checkIn') {
        return _jsonResponse({
          'error': 'AttendanceConflict',
          'message': 'Attendance record already exists for date $date',
        }, status: 409);
      }

      // Check Idempotency: if eventId has already been processed by server, return 200 OK without re-processing!
      if (_processedEventIds.contains(eventId)) {
        return _jsonResponse({
          'status': 'success',
          'message': 'Event previously processed (idempotent duplicate request)',
          'eventId': eventId,
          'record': _serverAttendance[date]?.toJson(),
        }, status: 200);
      }

      // Check if attendance already exists for today on server (conflict validation)
      final existingRecord = _serverAttendance[date];
      if (eventType == 'checkIn') {
        if (existingRecord != null && existingRecord.checkInTime != null) {
          return _jsonResponse({
            'error': 'Conflict',
            'message': 'Check-in already completed for $date',
          }, status: 409);
        }

        final newRecord = AttendanceRecord(
          id: 'att_${DateTime.now().millisecondsSinceEpoch}',
          employeeId: json['employeeId'] as String,
          date: date,
          checkInTime: timestamp,
          checkInLatitude: lat,
          checkInLongitude: lng,
          syncStatus: SyncStatus.synced,
        );
        _serverAttendance[date] = newRecord;
        _processedEventIds.add(eventId);
        return _jsonResponse(newRecord.toJson(), status: 201);
      } else if (eventType == 'checkOut') {
        if (existingRecord == null || existingRecord.checkInTime == null) {
          return _jsonResponse({
            'error': 'BadRequest',
            'message': 'Cannot check-out without prior check-in for date $date',
          }, status: 400);
        }
        if (existingRecord.checkOutTime != null) {
          return _jsonResponse({
            'error': 'Conflict',
            'message': 'Check-out already completed for date $date',
          }, status: 409);
        }

        final updatedRecord = existingRecord.copyWith(
          checkOutTime: timestamp,
          checkOutLatitude: lat,
          checkOutLongitude: lng,
          syncStatus: SyncStatus.synced,
        );
        _serverAttendance[date] = updatedRecord;
        _processedEventIds.add(eventId);
        return _jsonResponse(updatedRecord.toJson(), status: 200);
      }
    }

    // ---------------- GET /leave/balance ----------------
    if (method == 'GET' && path.endsWith('/leave/balance')) {
      return _jsonResponse(_serverLeaveBalance.toJson());
    }

    // ---------------- GET /leave/requests ----------------
    if (method == 'GET' && path.endsWith('/leave/requests')) {
      final list = _serverLeaves.map((l) => l.toJson()).toList();
      return _jsonResponse(list);
    }

    // ---------------- POST /leave/requests ----------------
    if (method == 'POST' && path.endsWith('/leave/requests')) {
      // Check Leave Validation Rejection Scenario
      if (scenario == MockScenario.leaveValidationRejection) {
        return _jsonResponse({
          'error': 'ValidationError',
          'message': 'Server policy rejection: Leave blackout period active or unverified document',
        }, status: 422);
      }

      final bodyString = await _extractRequestBody(request);
      final json = jsonDecode(bodyString) as Map<String, dynamic>;
      final type = json['type'] == 'sick' ? LeaveType.sick : LeaveType.casual;
      final startDate = DateTime.parse(json['startDate'] as String);
      final endDate = DateTime.parse(json['endDate'] as String);
      final daysCount = json['daysCount'] as int;
      final reason = json['reason'] as String;

      // Server-side validations
      if (reason.trim().length < 10) {
        return _jsonResponse({
          'error': 'ValidationError',
          'message': 'Reason must contain at least 10 non-whitespace characters',
        }, status: 422);
      }

      final available = _serverLeaveBalance.getBalanceFor(type);
      if (daysCount > available) {
        return _jsonResponse({
          'error': 'ValidationError',
          'message': 'Requested $daysCount days exceeds available balance of $available days',
        }, status: 422);
      }

      // Check overlap with existing pending or approved requests
      for (final existing in _serverLeaves) {
        if (existing.status == LeaveStatus.pending || existing.status == LeaveStatus.approved) {
          final sA = DateTime(startDate.year, startDate.month, startDate.day);
          final eA = DateTime(endDate.year, endDate.month, endDate.day);
          final sB = DateTime(existing.startDate.year, existing.startDate.month, existing.startDate.day);
          final eB = DateTime(existing.endDate.year, existing.endDate.month, existing.endDate.day);

          final overlap = !(eA.isBefore(sB) || sA.isAfter(eB));
          if (overlap) {
            return _jsonResponse({
              'error': 'ValidationError',
              'message': 'Dates overlap with an existing ${existing.status.label} leave request (${existing.startDate.toIso8601String().split('T').first} to ${existing.endDate.toIso8601String().split('T').first})',
            }, status: 422);
          }
        }
      }

      // Accept leave request
      final newLeave = LeaveRequest(
        id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
        employeeId: json['employeeId'] as String? ?? 'EMP-1042',
        type: type,
        startDate: startDate,
        endDate: endDate,
        daysCount: daysCount,
        reason: reason,
        status: LeaveStatus.pending,
        appliedAt: DateTime.now(),
      );
      _serverLeaves.insert(0, newLeave);

      // Deduct balance
      if (type == LeaveType.casual) {
        _serverLeaveBalance = LeaveBalance(
          casual: _serverLeaveBalance.casual - daysCount,
          sick: _serverLeaveBalance.sick,
        );
      } else {
        _serverLeaveBalance = LeaveBalance(
          casual: _serverLeaveBalance.casual,
          sick: _serverLeaveBalance.sick - daysCount,
        );
      }

      return _jsonResponse(newLeave.toJson(), status: 201);
    }

    return _jsonResponse({'error': 'Not Found', 'path': path}, status: 404);
  }

  Future<String> _extractRequestBody(http.BaseRequest request) async {
    if (request is http.Request) {
      return request.body;
    }
    final bytes = await request.finalize().toBytes();
    return utf8.decode(bytes);
  }

  http.StreamedResponse _jsonResponse(dynamic data, {int status = 200}) {
    final body = jsonEncode(data);
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'content-length': bytes.length.toString(),
      },
    );
  }
}
