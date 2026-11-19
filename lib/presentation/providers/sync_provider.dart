import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/network_info.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../domain/services/sync_service.dart';
import 'attendance_provider.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService syncService;
  final NetworkInfo networkInfo;

  bool _isOnline = true;
  bool _isSyncing = false;
  SyncResult? _lastSyncResult;
  String? _syncMessage;
  StreamSubscription<bool>? _netSub;
  StreamSubscription<SyncResult>? _syncSub;

  SyncProvider({
    required this.syncService,
    required this.networkInfo,
  }) {
    _init();
  }

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  SyncResult? get lastSyncResult => _lastSyncResult;
  String? get syncMessage => _syncMessage;

  void _init() {
    // Initial check
    networkInfo.isConnected.then((connected) {
      _isOnline = connected;
      notifyListeners();
    });

    _netSub = networkInfo.onConnectivityChanged.listen((connected) {
      final wasOffline = !_isOnline;
      _isOnline = connected;
      if (wasOffline && connected) {
        _syncMessage = 'Connection restored. Auto-syncing...';
      } else if (!connected) {
        _syncMessage = 'Device is offline. Changes saved locally.';
      }
      notifyListeners();
    });

    _syncSub = syncService.syncResults.listen((result) {
      _lastSyncResult = result;
      _isSyncing = false;
      if (result.isSuccess && result.total > 0) {
        _syncMessage = 'Synced ${result.synced} event(s) successfully.';
      } else if (result.rejected > 0) {
        _syncMessage = '${result.rejected} event(s) rejected by server.';
      } else if (result.failed > 0) {
        _syncMessage = 'Sync pending (${result.failed} event(s) in queue).';
      }
      notifyListeners();
    });
  }

  Future<SyncResult> triggerManualSync({
    required AttendanceProvider attendanceProvider,
    required Employee employee,
  }) async {
    _isSyncing = true;
    _syncMessage = 'Syncing pending events...';
    notifyListeners();

    try {
      final result = await syncService.syncNow(employeeId: employee.id);
      _lastSyncResult = result;
      await attendanceProvider.refreshAfterSync(employee);

      if (result.total == 0) {
        _syncMessage = 'Everything is up to date.';
      } else if (result.isSuccess) {
        _syncMessage = 'Synced ${result.synced} event(s) with server.';
      } else {
        _syncMessage = result.errorMessage ?? 'Sync completed with ${result.failed} pending item(s).';
      }
      return result;
    } catch (e) {
      _syncMessage = 'Sync failed: ${e.toString()}';
      return SyncResult(
        total: 1,
        synced: 0,
        rejected: 0,
        failed: 1,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _netSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }
}
