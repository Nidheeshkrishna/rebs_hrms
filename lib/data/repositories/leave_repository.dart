import '../../core/network/api_client.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/database_helper.dart';
import '../../core/utils/date_utils.dart';
import '../models/leave_model.dart';

class LeaveValidationException implements Exception {
  final String message;
  LeaveValidationException(this.message);

  @override
  String toString() => message;
}

class LeaveRepository {
  final ApiClient apiClient;
  final DatabaseHelper dbHelper;
  final NetworkInfo networkInfo;

  LeaveRepository({
    required this.apiClient,
    required this.dbHelper,
    required this.networkInfo,
  });

  /// Loads available leave balance from cache or remote
  Future<LeaveBalance> getLeaveBalance({bool forceRefresh = false}) async {
    final cached = await dbHelper.getLeaveBalance();
    final isOnline = await networkInfo.isConnected;

    if (cached != null && !forceRefresh && !isOnline) {
      return cached;
    }

    if (isOnline) {
      try {
        final remote = await apiClient.getLeaveBalance();
        await dbHelper.saveLeaveBalance(remote);
        return remote;
      } catch (_) {
        if (cached != null) return cached;
      }
    }

    if (cached != null) return cached;

    const initial = LeaveBalance(casual: 12, sick: 8);
    await dbHelper.saveLeaveBalance(initial);
    return initial;
  }

  /// Loads leave requests from cache or remote
  Future<List<LeaveRequest>> getLeaveRequests(
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    final cached = await dbHelper.getLeaveRequests(employeeId);
    final isOnline = await networkInfo.isConnected;

    if (cached.isNotEmpty && !forceRefresh && !isOnline) {
      return cached;
    }

    if (isOnline) {
      try {
        final remote = await apiClient.getLeaveRequests();
        await dbHelper.saveLeaveRequests(remote);
        return remote;
      } catch (_) {
        if (cached.isNotEmpty) return cached;
      }
    }

    return cached;
  }

  /// Validates business rules for a proposed leave application
  void validateLeaveRequest({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required LeaveBalance balance,
    required List<LeaveRequest> existingRequests,
    required DateTime companyCurrentDate,
  }) {
    // 1. Start date cannot be before the current company date
    final today = DateTime(
      companyCurrentDate.year,
      companyCurrentDate.month,
      companyCurrentDate.day,
    );
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (start.isBefore(today)) {
      throw LeaveValidationException(
        'Start date cannot be before current company date (${AppDateUtils.formatDisplayDate(today)}).',
      );
    }

    // 2. End date cannot be before the start date
    if (end.isBefore(start)) {
      throw LeaveValidationException(
        'End date cannot be before start date.',
      );
    }

    // 3. Reason must contain at least 10 non-whitespace characters
    final nonWhitespaceChars = reason.replaceAll(RegExp(r'\s+'), '');
    if (nonWhitespaceChars.length < 10) {
      throw LeaveValidationException(
        'Reason must contain at least 10 non-whitespace characters (currently ${nonWhitespaceChars.length}).',
      );
    }

    // 4. Dates cannot overlap an existing Pending or Approved request
    for (final existing in existingRequests) {
      if (existing.status == LeaveStatus.pending || existing.status == LeaveStatus.approved) {
        if (AppDateUtils.areRangesOverlapping(
          start,
          end,
          existing.startDate,
          existing.endDate,
        )) {
          final rangeStr =
              '${AppDateUtils.formatDisplayDate(existing.startDate)} to ${AppDateUtils.formatDisplayDate(existing.endDate)}';
          throw LeaveValidationException(
            'Selected dates overlap with an existing ${existing.status.label} leave request ($rangeStr).',
          );
        }
      }
    }

    // 5. Requested days cannot exceed available balance
    final requestedDays = AppDateUtils.calculateLeaveDays(start, end);
    final available = balance.getBalanceFor(type);
    if (requestedDays > available) {
      throw LeaveValidationException(
        'Requested duration ($requestedDays ${requestedDays == 1 ? "day" : "days"}) exceeds available ${type.label} balance ($available ${available == 1 ? "day" : "days"}).',
      );
    }
  }

  /// Submits a leave application.
  /// Works completely offline: validates rules locally, updates local SQLite database and balance,
  /// and synchronizes with server when online.
  Future<LeaveRequest> submitLeaveRequest({
    required String employeeId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required DateTime companyCurrentDate,
  }) async {
    final balance = await getLeaveBalance();
    final existingList = await getLeaveRequests(employeeId);

    // Run client-side validations
    validateLeaveRequest(
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      balance: balance,
      existingRequests: existingList,
      companyCurrentDate: companyCurrentDate,
    );

    final daysCount = AppDateUtils.calculateLeaveDays(startDate, endDate);
    final newRequest = LeaveRequest(
      id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
      employeeId: employeeId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      daysCount: daysCount,
      reason: reason,
      status: LeaveStatus.pending,
      appliedAt: DateTime.now(),
    );

    // 1. Save locally in persistent SQLite (offline capability)
    await dbHelper.insertLeaveRequest(newRequest);

    // 2. Update local cached balance so subsequent offline checks are accurate
    final updatedBalance = type == LeaveType.casual
        ? LeaveBalance(casual: balance.casual - daysCount, sick: balance.sick)
        : LeaveBalance(casual: balance.casual, sick: balance.sick - daysCount);
    await dbHelper.saveLeaveBalance(updatedBalance);

    // 3. Attempt immediate sync if online
    final isOnline = await networkInfo.isConnected;
    if (isOnline) {
      try {
        final created = await apiClient.submitLeaveRequest(newRequest);
        await dbHelper.insertLeaveRequest(created);
        return created;
      } on ValidationException catch (e) {
        throw LeaveValidationException('Server rejection: ${e.message}');
      } catch (_) {
        // Network connection failed: request is already saved locally and will auto-sync
      }
    }

    return newRequest;
  }

  /// Synchronizes all offline pending leave requests with the remote server
  Future<int> synchronizePendingLeaves(String employeeId) async {
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) return 0;

    int syncedCount = 0;
    try {
      final localRequests = await dbHelper.getLeaveRequests(employeeId);
      for (final req in localRequests) {
        if (req.status == LeaveStatus.pending) {
          try {
            final remote = await apiClient.submitLeaveRequest(req);
            await dbHelper.insertLeaveRequest(remote);
            syncedCount++;
          } catch (_) {
            // Keep pending to retry later
          }
        }
      }

      // Refresh balance and remote list
      try {
        final remoteBalance = await apiClient.getLeaveBalance();
        await dbHelper.saveLeaveBalance(remoteBalance);
        final remoteList = await apiClient.getLeaveRequests();
        await dbHelper.saveLeaveRequests(remoteList);
      } catch (_) {}
    } catch (_) {}

    return syncedCount;
  }
}
