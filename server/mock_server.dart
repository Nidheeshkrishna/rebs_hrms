import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('=====================================================');
  print('  REBS HRMS Mock HTTP Server running on port $port');
  print('  URL: http://localhost:$port');
  print('=====================================================');
  print('Supported Endpoints:');
  print('  GET  /employee/me');
  print('  GET  /attendance?month=YYYY-MM');
  print('  POST /attendance/events');
  print('  GET  /leave/balance');
  print('  GET  /leave/requests');
  print('  POST /leave/requests');
  print('-----------------------------------------------------');
  print('Simulate Scenarios via Header `X-Mock-Scenario`:');
  print('  - "slow"       : 10-second delay / timeout');
  print('  - "error"      : 500 Internal Server Error');
  print('  - "conflict"   : 409 Attendance Conflict');
  print('  - "rejection"  : 422 Leave Policy Rejection');
  print('=====================================================\n');

  final processedEvents = <String>{};
  final attendanceRecords = <String, Map<String, dynamic>>{};
  final leaveRequests = <Map<String, dynamic>>[];
  int casualBalance = 12;
  int sickBalance = 8;

  // Seed sample data
  final now = DateTime.now();
  for (int i = 1; i <= 5; i++) {
    final d = now.subtract(Duration(days: i));
    final dateStr = d.toIso8601String().split('T').first;
    attendanceRecords[dateStr] = {
      'id': 'rec_server_$i',
      'employeeId': 'EMP-1042',
      'date': dateStr,
      'checkInTime': DateTime(d.year, d.month, d.day, 9, 10 + i).toIso8601String(),
      'checkInLatitude': 10.0159,
      'checkInLongitude': 76.3419,
      'checkOutTime': DateTime(d.year, d.month, d.day, 18, 5 + i).toIso8601String(),
      'checkOutLatitude': 10.0160,
      'checkOutLongitude': 76.3420,
      'syncStatus': 'synced',
    };
  }

  await for (HttpRequest request in server) {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-Idempotency-Key, X-Mock-Scenario');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    final path = request.uri.path;
    final method = request.method;
    final scenarioHeader = request.headers.value('x-mock-scenario')?.toLowerCase();

    print('[${DateTime.now().toIso8601String()}] $method $path');

    // Scenario: Slow response / Timeout
    if (scenarioHeader == 'slow') {
      print('  -> Simulating slow response (10s delay)');
      await Future.delayed(const Duration(seconds: 10));
    }

    // Scenario: Server error
    if (scenarioHeader == 'error') {
      print('  -> Simulating 500 Internal Server Error');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'InternalServerError', 'message': 'Database offline'}));
      await request.response.close();
      continue;
    }

    try {
      if (method == 'GET' && path == '/employee/me') {
        _json(request.response, {
          'id': 'EMP-1042',
          'name': 'Alexander Wright',
          'department': 'Core Business Automation',
          'role': 'Senior Software Engineer',
          'officeLatitude': 10.0159,
          'officeLongitude': 76.3419,
          'geofenceRadiusMeters': 200.0,
          'timezone': 'Asia/Kolkata (UTC+05:30)',
        });
      } else if (method == 'GET' && path == '/attendance') {
        _json(request.response, attendanceRecords.values.toList());
      } else if (method == 'POST' && path == '/attendance/events') {
        if (scenarioHeader == 'conflict') {
          _json(request.response, {
            'error': 'Conflict',
            'message': 'Attendance conflict simulated by reviewer',
          }, status: 409);
          continue;
        }

        final body = await utf8.decodeStream(request);
        final json = jsonDecode(body) as Map<String, dynamic>;
        final eventId = json['eventId'] as String;
        final eventType = json['eventType'] as String;
        final date = json['date'] as String;
        final timestamp = json['timestamp'] as String;

        // Idempotency check:
        if (processedEvents.contains(eventId)) {
          print('  -> Idempotent duplicate event detected: $eventId. Returning 200.');
          _json(request.response, {
            'status': 'success',
            'message': 'Idempotent replay processed',
            'record': attendanceRecords[date],
          });
          continue;
        }

        final existing = attendanceRecords[date];
        if (eventType == 'checkIn') {
          if (existing != null && existing['checkInTime'] != null) {
            _json(request.response, {
              'error': 'Conflict',
              'message': 'Check-in already completed for $date',
            }, status: 409);
            continue;
          }
          final record = {
            'id': 'att_${DateTime.now().millisecondsSinceEpoch}',
            'employeeId': json['employeeId'],
            'date': date,
            'checkInTime': timestamp,
            'checkInLatitude': json['latitude'],
            'checkInLongitude': json['longitude'],
            'checkOutTime': null,
            'checkOutLatitude': null,
            'checkOutLongitude': null,
            'syncStatus': 'synced',
          };
          attendanceRecords[date] = record;
          processedEvents.add(eventId);
          _json(request.response, record, status: 201);
        } else if (eventType == 'checkOut') {
          if (existing == null || existing['checkInTime'] == null) {
            _json(request.response, {
              'error': 'BadRequest',
              'message': 'Cannot check-out without prior check-in',
            }, status: 400);
            continue;
          }
          existing['checkOutTime'] = timestamp;
          existing['checkOutLatitude'] = json['latitude'];
          existing['checkOutLongitude'] = json['longitude'];
          existing['syncStatus'] = 'synced';
          processedEvents.add(eventId);
          _json(request.response, existing, status: 200);
        }
      } else if (method == 'GET' && path == '/leave/balance') {
        _json(request.response, {
          'casual': casualBalance,
          'sick': sickBalance,
          'total': casualBalance + sickBalance,
        });
      } else if (method == 'GET' && path == '/leave/requests') {
        _json(request.response, leaveRequests);
      } else if (method == 'POST' && path == '/leave/requests') {
        if (scenarioHeader == 'rejection') {
          _json(request.response, {
            'error': 'ValidationError',
            'message': 'Leave rejection simulated by reviewer policy check',
          }, status: 422);
          continue;
        }

        final body = await utf8.decodeStream(request);
        final json = jsonDecode(body) as Map<String, dynamic>;
        final type = json['type'] as String;
        final days = json['daysCount'] as int;

        final newReq = {
          'id': 'leave_${DateTime.now().millisecondsSinceEpoch}',
          'employeeId': json['employeeId'] ?? 'EMP-1042',
          'type': type,
          'startDate': json['startDate'],
          'endDate': json['endDate'],
          'daysCount': days,
          'reason': json['reason'],
          'status': 'pending',
          'appliedAt': DateTime.now().toIso8601String(),
        };
        leaveRequests.insert(0, newReq);
        if (type == 'casual') {
          casualBalance -= days;
        } else {
          sickBalance -= days;
        }
        _json(request.response, newReq, status: 201);
      } else {
        _json(request.response, {'error': 'Not found'}, status: 404);
      }
    } catch (e) {
      _json(request.response, {'error': e.toString()}, status: 500);
    }
  }
}

void _json(HttpResponse response, dynamic data, {int status = 200}) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  response.close();
}
