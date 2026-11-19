enum LeaveType {
  casual,
  sick;

  String get label => this == LeaveType.casual ? 'Casual Leave' : 'Sick Leave';
  String get shortLabel => this == LeaveType.casual ? 'Casual' : 'Sick';
}

enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }
}

class LeaveBalance {
  final int casual;
  final int sick;

  const LeaveBalance({
    required this.casual,
    required this.sick,
  });

  int get total => casual + sick;

  int getBalanceFor(LeaveType type) {
    return type == LeaveType.casual ? casual : sick;
  }

  factory LeaveBalance.initial() {
    return const LeaveBalance(casual: 12, sick: 8);
  }

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      casual: json['casual'] as int? ?? 12,
      sick: json['sick'] as int? ?? 8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'casual': casual,
      'sick': sick,
      'total': total,
    };
  }
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final int daysCount;
  final String reason;
  final LeaveStatus status;
  final DateTime appliedAt;
  final String? rejectionReason;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.reason,
    required this.status,
    required this.appliedAt,
    this.rejectionReason,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      type: json['type'] == 'sick' ? LeaveType.sick : LeaveType.casual,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      daysCount: json['daysCount'] as int,
      reason: json['reason'] as String,
      status: _parseStatus(json['status'] as String?),
      appliedAt: DateTime.parse(json['appliedAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'type': type.name,
      'startDate': startDate.toIso8601String().split('T').first,
      'endDate': endDate.toIso8601String().split('T').first,
      'daysCount': daysCount,
      'reason': reason,
      'status': status.name,
      'appliedAt': appliedAt.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }

  static LeaveStatus _parseStatus(String? str) {
    switch (str?.toLowerCase()) {
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
