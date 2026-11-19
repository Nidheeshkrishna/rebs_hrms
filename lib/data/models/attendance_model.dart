enum DailyAttendanceStatus {
  notCheckedIn,
  checkedIn,
  checkedOut;

  String get label {
    switch (this) {
      case DailyAttendanceStatus.notCheckedIn:
        return 'Not Checked In';
      case DailyAttendanceStatus.checkedIn:
        return 'Checked In';
      case DailyAttendanceStatus.checkedOut:
        return 'Checked Out';
    }
  }
}

enum SyncStatus {
  pendingSync,
  synced,
  rejected;

  String get label {
    switch (this) {
      case SyncStatus.pendingSync:
        return 'Pending Sync';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.rejected:
        return 'Rejected';
    }
  }
}

enum AttendanceEventType {
  checkIn,
  checkOut;

  String get label => this == AttendanceEventType.checkIn ? 'Check In' : 'Check Out';
}

/// Represents a single discrete attendance action (check-in or check-out)
/// Sent across the wire and persisted in the sync queue.
class AttendanceEvent {
  final String eventId; // UUIDv4 idempotency key
  final String employeeId;
  final AttendanceEventType eventType;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String date; // YYYY-MM-DD
  final SyncStatus syncStatus;
  final String? rejectionReason;
  final DateTime createdAt;

  const AttendanceEvent({
    required this.eventId,
    required this.employeeId,
    required this.eventType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.date,
    this.syncStatus = SyncStatus.pendingSync,
    this.rejectionReason,
    required this.createdAt,
  });

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    return AttendanceEvent(
      eventId: json['eventId'] as String,
      employeeId: json['employeeId'] as String,
      eventType: json['eventType'] == 'checkOut'
          ? AttendanceEventType.checkOut
          : AttendanceEventType.checkIn,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] as String,
      syncStatus: _parseSyncStatus(json['syncStatus'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'employeeId': employeeId,
      'eventType': eventType.name,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'date': date,
      'syncStatus': syncStatus.name,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AttendanceEvent copyWith({
    String? eventId,
    String? employeeId,
    AttendanceEventType? eventType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    String? date,
    SyncStatus? syncStatus,
    String? rejectionReason,
    DateTime? createdAt,
  }) {
    return AttendanceEvent(
      eventId: eventId ?? this.eventId,
      employeeId: employeeId ?? this.employeeId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      date: date ?? this.date,
      syncStatus: syncStatus ?? this.syncStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static SyncStatus _parseSyncStatus(String? str) {
    switch (str) {
      case 'synced':
        return SyncStatus.synced;
      case 'rejected':
        return SyncStatus.rejected;
      case 'pendingSync':
      default:
        return SyncStatus.pendingSync;
    }
  }
}

/// Represents a consolidated daily attendance record (for dashboard history)
class AttendanceRecord {
  final String id;
  final String employeeId;
  final String date; // YYYY-MM-DD
  final DateTime? checkInTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final DateTime? checkOutTime;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final SyncStatus syncStatus;
  final String? rejectionReason;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutTime,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.syncStatus = SyncStatus.synced,
    this.rejectionReason,
  });

  DailyAttendanceStatus get dailyStatus {
    if (checkOutTime != null) {
      return DailyAttendanceStatus.checkedOut;
    }
    if (checkInTime != null) {
      return DailyAttendanceStatus.checkedIn;
    }
    return DailyAttendanceStatus.notCheckedIn;
  }

  Duration get workingDuration {
    if (checkInTime == null) return Duration.zero;
    final end = checkOutTime ?? DateTime.now();
    final diff = end.difference(checkInTime!);
    return diff.isNegative ? Duration.zero : diff;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      date: json['date'] as String,
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'] as String)
          : null,
      checkInLatitude: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] as num?)?.toDouble(),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      checkOutLatitude: (json['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['checkOutLongitude'] as num?)?.toDouble(),
      syncStatus: _parseSyncStatus(json['syncStatus'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date,
      'checkInTime': checkInTime?.toIso8601String(),
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkOutTime': checkOutTime?.toIso8601String(),
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
      'syncStatus': syncStatus.name,
      'rejectionReason': rejectionReason,
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? employeeId,
    String? date,
    DateTime? checkInTime,
    double? checkInLatitude,
    double? checkInLongitude,
    DateTime? checkOutTime,
    double? checkOutLatitude,
    double? checkOutLongitude,
    SyncStatus? syncStatus,
    String? rejectionReason,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      syncStatus: syncStatus ?? this.syncStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
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
}
