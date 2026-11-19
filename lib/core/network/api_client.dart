import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/leave_model.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorType;

  ApiException(this.statusCode, this.message, {this.errorType});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

class ConflictException extends ApiException {
  ConflictException(String message) : super(409, message, errorType: 'Conflict');
}

class ValidationException extends ApiException {
  ValidationException(String message) : super(422, message, errorType: 'ValidationError');
}

class ApiClient {
  final http.Client client;
  String baseUrl;
  final Duration timeout;

  ApiClient({
    required this.client,
    this.baseUrl = AppConstants.defaultBaseUrl,
    this.timeout = AppConstants.apiTimeout,
  });

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // 1. GET /employee/me
  Future<Employee> getEmployeeProfile() async {
    final response = await _get('/employee/me');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(json);
  }

  // 2. GET /attendance?month=YYYY-MM
  Future<List<AttendanceRecord>> getAttendanceHistory(String month) async {
    final response = await _get('/attendance?month=$month');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>)).toList();
  }

  // 3. POST /attendance/events
  Future<AttendanceRecord?> submitAttendanceEvent(AttendanceEvent event) async {
    final headers = {
      ..._defaultHeaders,
      'X-Idempotency-Key': event.eventId,
    };
    final response = await _post(
      '/attendance/events',
      body: jsonEncode(event.toJson()),
      headers: headers,
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('record') && json['record'] != null) {
      return AttendanceRecord.fromJson(json['record'] as Map<String, dynamic>);
    }
    if (json.containsKey('id')) {
      return AttendanceRecord.fromJson(json);
    }
    return null;
  }

  // 4. GET /leave/balance
  Future<LeaveBalance> getLeaveBalance() async {
    final response = await _get('/leave/balance');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LeaveBalance.fromJson(json);
  }

  // 5. GET /leave/requests
  Future<List<LeaveRequest>> getLeaveRequests() async {
    final response = await _get('/leave/requests');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) => LeaveRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  // 6. POST /leave/requests
  Future<LeaveRequest> submitLeaveRequest(LeaveRequest request) async {
    final response = await _post(
      '/leave/requests',
      body: jsonEncode(request.toJson()),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LeaveRequest.fromJson(json);
  }

  // ---------------- Private HTTP Helpers ---------------- //
  Future<http.Response> _get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await client.get(uri, headers: _defaultHeaders).timeout(timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw NetworkException('Request timed out. Please check your connection.');
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection error: ${e.message}');
    }
  }

  Future<http.Response> _post(
    String path, {
    String? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await client
          .post(uri, headers: headers ?? _defaultHeaders, body: body)
          .timeout(timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw NetworkException('Request timed out while waiting for server response.');
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('HTTP connection error: ${e.message}');
    }
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String message = 'HTTP ${response.statusCode} error';
    String? errorType;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json.containsKey('message')) {
        message = json['message'] as String;
      } else if (json.containsKey('error')) {
        message = json['error'].toString();
      }
      errorType = json['error']?.toString();
    } catch (_) {}

    if (response.statusCode == 409) {
      throw ConflictException(message);
    } else if (response.statusCode == 422 || response.statusCode == 400) {
      throw ValidationException(message);
    } else {
      throw ApiException(response.statusCode, message, errorType: errorType);
    }
  }
}
