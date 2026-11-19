import '../../core/constants/app_constants.dart';

class Employee {
  final String id;
  final String name;
  final String department;
  final String role;
  final double officeLatitude;
  final double officeLongitude;
  final double geofenceRadiusMeters;
  final String timezone;

  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.role,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.geofenceRadiusMeters,
    required this.timezone,
  });

  factory Employee.preconfigured() {
    return const Employee(
      id: AppConstants.defaultEmployeeId,
      name: AppConstants.defaultEmployeeName,
      department: AppConstants.defaultEmployeeDepartment,
      role: AppConstants.defaultEmployeeRole,
      officeLatitude: AppConstants.defaultOfficeLatitude,
      officeLongitude: AppConstants.defaultOfficeLongitude,
      geofenceRadiusMeters: AppConstants.geofenceRadiusMeters,
      timezone: AppConstants.defaultTimezone,
    );
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String? ?? AppConstants.defaultEmployeeId,
      name: json['name'] as String? ?? AppConstants.defaultEmployeeName,
      department: json['department'] as String? ?? AppConstants.defaultEmployeeDepartment,
      role: json['role'] as String? ?? AppConstants.defaultEmployeeRole,
      officeLatitude: (json['officeLatitude'] as num?)?.toDouble() ?? AppConstants.defaultOfficeLatitude,
      officeLongitude: (json['officeLongitude'] as num?)?.toDouble() ?? AppConstants.defaultOfficeLongitude,
      geofenceRadiusMeters: (json['geofenceRadiusMeters'] as num?)?.toDouble() ?? AppConstants.geofenceRadiusMeters,
      timezone: json['timezone'] as String? ?? AppConstants.defaultTimezone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'role': role,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'geofenceRadiusMeters': geofenceRadiusMeters,
      'timezone': timezone,
    };
  }

  Employee copyWith({
    String? id,
    String? name,
    String? department,
    String? role,
    double? officeLatitude,
    double? officeLongitude,
    double? geofenceRadiusMeters,
    String? timezone,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      role: role ?? this.role,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      timezone: timezone ?? this.timezone,
    );
  }
}
