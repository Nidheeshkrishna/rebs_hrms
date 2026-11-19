import 'package:uuid/uuid.dart';
import '../../core/network/api_client.dart';
import '../../core/network/mock_http_client.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/database_helper.dart';
import '../../core/utils/date_utils.dart';
import '../models/attendance_model.dart';
import '../models/employee_model.dart';

class AttendanceValidationException implements Exception {
  final String message;
  AttendanceValidationException(this.message);

  @override
  String toString() => message;
}

class AttendanceRepository {
  final ApiClient apiClient;
  final DatabaseHelper dbHelper;
  final NetworkInfo networkInfo;
  final _uuid = const Uuid();

  AttendanceRepository({
    required this.apiClient,
    required this.dbHelper,
    required this.networkInfo,
  });

  /// Returns today's attendance record for the employee
  Future<AttendanceRecord?> getTodayAttendance(String employeeId, DateTime now) async {
    final todayIso = AppDateUtils.formatDateIso(now);
    return await dbHelper.getAttendanceForDate(employeeId, todayIso);
  }

  /// Returns cached recent attendance history (latest 5 or specified limit)
  Future<List<AttendanceRecord>> getAttendanceHistory(
    String employeeId, {
    int limit = 5,
    bool fetchRemoteIfOnline = true,
  }) async {
    final cached = await dbHelper.getAttendanceHistory(employeeId, limit: limit);
    final isOnline = await networkInfo.isConnected;

    if (fetchRemoteIfOnline && isOnline) {
      try {
        final currentMonth = AppDateUtils.formatDateIso(DateTime.now()).substring(0, 7);
        final remoteRecords = await apiClient.getAttendanceHistory(currentMonth);
        await dbHelper.saveAttendanceRecords(remoteRecords);
        return await dbHelper.getAttendanceHistory(employeeId, limit: limit);
      } catch (_) {
        // Fall back cleanly to cached data on network error
      }
    }
    return cached;
  }

  /// Records a check-in event.
  /// Validates rules locally, updates local state, queues event for synchronization.
  Future<AttendanceRecord> checkIn({
    required Employee employee,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double distanceMeters,
  }) async {
    final todayIso = AppDateUtils.formatDateIso(timestamp);
    final existing = await dbHelper.getAttendanceForDate(employee.id, todayIso);

    // Business rule: Check-in only once per working day
    if (existing != null && existing.checkInTime != null) {
      throw AttendanceValidationException(
        'Check-in already completed for today (${AppDateUtils.formatDisplayDate(timestamp)}). Single check-in per day allowed.',
      );
    }

    final eventId = _uuid.v4(); // Unique idempotency key
    final isOnline = await networkInfo.isConnected;

    // Build the attendance event
    final event = AttendanceEvent(
      eventId: eventId,
      employeeId: employee.id,
      eventType: AttendanceEventType.checkIn,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      date: todayIso,
      syncStatus: SyncStatus.pendingSync,
      createdAt: DateTime.now(),
    );

    // Build local attendance record
    final localRecord = AttendanceRecord(
      id: existing?.id ?? 'att_${timestamp.millisecondsSinceEpoch}',
      employeeId: employee.id,
      date: todayIso,
      checkInTime: timestamp,
      checkInLatitude: latitude,
      checkInLongitude: longitude,
      syncStatus: SyncStatus.pendingSync,
    );

    // Save to persistent SQLite storage
    await dbHelper.enqueueAttendanceEvent(event);
    await dbHelper.saveAttendanceRecord(localRecord);

    // Attempt immediate sync if online
    if (isOnline) {
      return await _syncSingleEvent(event, localRecord);
    }

    return localRecord;
  }

  /// Records a check-out event.
  /// Validates rules locally, updates local state, queues event for synchronization.
  Future<AttendanceRecord> checkOut({
    required Employee employee,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double distanceMeters,
  }) async {
    final todayIso = AppDateUtils.formatDateIso(timestamp);
    final existing = await dbHelper.getAttendanceForDate(employee.id, todayIso);

    // Business rule: Check-out permitted only after check-in
    if (existing == null || existing.checkInTime == null) {
      throw AttendanceValidationException(
        'Cannot check out without checking in first for today.',
      );
    }

    // Business rule: Check-out only once per working day
    if (existing.checkOutTime != null) {
      throw AttendanceValidationException(
        'Check-out already completed for today. Only one session per day is permitted.',
      );
    }

    final eventId = _uuid.v4(); // Unique idempotency key
    final isOnline = await networkInfo.isConnected;

    final event = AttendanceEvent(
      eventId: eventId,
      employeeId: employee.id,
      eventType: AttendanceEventType.checkOut,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      date: todayIso,
      syncStatus: SyncStatus.pendingSync,
      createdAt: DateTime.now(),
    );

    final updatedRecord = existing.copyWith(
      checkOutTime: timestamp,
      checkOutLatitude: latitude,
      checkOutLongitude: longitude,
      syncStatus: SyncStatus.pendingSync,
    );

    await dbHelper.enqueueAttendanceEvent(event);
    await dbHelper.saveAttendanceRecord(updatedRecord);

    if (isOnline) {
      return await _syncSingleEvent(event, updatedRecord);
    }

    return updatedRecord;
  }

  /// Synchronizes a single event with the remote API
  Future<AttendanceRecord> _syncSingleEvent(
    AttendanceEvent event,
    AttendanceRecord localRecord,
  ) async {
    try {
      final remoteRecord = await apiClient.submitAttendanceEvent(event);
      await dbHelper.updateEventSyncStatus(event.eventId, SyncStatus.synced);

      final syncedRecord = (remoteRecord ?? localRecord).copyWith(
        syncStatus: SyncStatus.synced,
        rejectionReason: null,
      );
      await dbHelper.saveAttendanceRecord(syncedRecord);
      return syncedRecord;
    } on ConflictException catch (e) {
      // 409 Conflict: Server rejected because attendance already exists
      await dbHelper.updateEventSyncStatus(
        event.eventId,
        SyncStatus.rejected,
        rejectionReason: e.message,
      );
      final rejectedRecord = localRecord.copyWith(
        syncStatus: SyncStatus.rejected,
        rejectionReason: e.message,
      );
      await dbHelper.saveAttendanceRecord(rejectedRecord);
      return rejectedRecord;
    } catch (_) {
      // Network timeout / server error: keep as pendingSync
      await dbHelper.incrementEventRetryCount(event.eventId);
      return localRecord;
    }
  }

  /// Processes all pending events in the queue in strict FIFO order
  Future<SyncResult> synchronizePendingEvents() async {
    final pendingEvents = await dbHelper.getPendingEvents();
    if (pendingEvents.isEmpty) {
      return const SyncResult(total: 0, synced: 0, rejected: 0, failed: 0);
    }

    final isOnline = await networkInfo.isConnected;
    if (!isOnline) {
      return SyncResult(
        total: pendingEvents.length,
        synced: 0,
        rejected: 0,
        failed: pendingEvents.length,
        errorMessage: 'Cannot sync: Device is offline',
      );
    }

    int syncedCount = 0;
    int rejectedCount = 0;
    int failedCount = 0;

    // FIFO processing to preserve check-in before check-out ordering
    for (final event in pendingEvents) {
      try {
        final existingRecord = await dbHelper.getAttendanceForDate(
          event.employeeId,
          event.date,
        );

        final resultRecord = await apiClient.submitAttendanceEvent(event);
        await dbHelper.updateEventSyncStatus(event.eventId, SyncStatus.synced);

        if (existingRecord != null) {
          final updated = (resultRecord ?? existingRecord).copyWith(
            syncStatus: SyncStatus.synced,
            rejectionReason: null,
          );
          await dbHelper.saveAttendanceRecord(updated);
        }
        syncedCount++;
      } on ConflictException catch (e) {
        // Attendance already exists on server
        await dbHelper.updateEventSyncStatus(
          event.eventId,
          SyncStatus.rejected,
          rejectionReason: e.message,
        );
        final existingRecord = await dbHelper.getAttendanceForDate(
          event.employeeId,
          event.date,
        );
        if (existingRecord != null) {
          final updated = existingRecord.copyWith(
            syncStatus: SyncStatus.rejected,
            rejectionReason: e.message,
          );
          await dbHelper.saveAttendanceRecord(updated);
        }
        rejectedCount++;
      } catch (e) {
        // Network failure, timeout, 500 error: preserve in queue
        await dbHelper.incrementEventRetryCount(event.eventId);
        failedCount++;
      }
    }

    return SyncResult(
      total: pendingEvents.length,
      synced: syncedCount,
      rejected: rejectedCount,
      failed: failedCount,
    );
  }

  Future<List<AttendanceEvent>> getAllQueuedEvents() async {
    return await dbHelper.getAllEvents();
  }

  /// Resets all attendance records and offline queues to start marking fresh
  Future<void> resetAttendance() async {
    await dbHelper.resetAttendanceRecords();
    if (apiClient.client is MockHttpClient) {
      (apiClient.client as MockHttpClient).reset();
    }
  }
}

class SyncResult {
  final int total;
  final int synced;
  final int rejected;
  final int failed;
  final String? errorMessage;

  const SyncResult({
    required this.total,
    required this.synced,
    required this.rejected,
    required this.failed,
    this.errorMessage,
  });

  bool get isSuccess => failed == 0;
}
