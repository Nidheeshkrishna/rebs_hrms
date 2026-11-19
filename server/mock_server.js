const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 8080;

const processedEvents = new Set();
const attendanceRecords = {};
const leaveRequests = [];
let casualBalance = 12;
let sickBalance = 8;

// Seed initial history
const now = new Date();
for (let i = 1; i <= 5; i++) {
  const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
  const dateStr = d.toISOString().split('T')[0];
  attendanceRecords[dateStr] = {
    id: `rec_server_${i}`,
    employeeId: 'EMP-1042',
    date: dateStr,
    checkInTime: new Date(d.setHours(9, 10 + i, 0)).toISOString(),
    checkInLatitude: 28.6139,
    checkInLongitude: 77.2090,
    checkOutTime: new Date(d.setHours(18, 5 + i, 0)).toISOString(),
    checkOutLatitude: 28.6140,
    checkOutLongitude: 77.2091,
    syncStatus: 'synced',
  };
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Idempotency-Key, X-Mock-Scenario');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const scenario = (req.headers['x-mock-scenario'] || '').toLowerCase();

  console.log(`[${new Date().toISOString()}] ${req.method} ${pathname}`);

  if (scenario === 'slow') {
    setTimeout(() => handleRequest(req, res, pathname, parsedUrl), 10000);
  } else if (scenario === 'error') {
    sendJson(res, { error: 'InternalServerError', message: 'Simulated 500 error' }, 500);
  } else {
    handleRequest(req, res, pathname, parsedUrl, scenario);
  }
});

function handleRequest(req, res, pathname, parsedUrl, scenario) {
  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    try {
      if (req.method === 'GET' && pathname === '/employee/me') {
        return sendJson(res, {
          id: 'EMP-1042',
          name: 'Alexander Wright',
          department: 'Core Business Automation',
          role: 'Senior Software Engineer',
          officeLatitude: 28.6139,
          officeLongitude: 77.2090,
          geofenceRadiusMeters: 200.0,
          timezone: 'Asia/Kolkata (UTC+05:30)',
        });
      }

      if (req.method === 'GET' && pathname === '/attendance') {
        return sendJson(res, Object.values(attendanceRecords));
      }

      if (req.method === 'POST' && pathname === '/attendance/events') {
        if (scenario === 'conflict') {
          return sendJson(res, { error: 'Conflict', message: 'Simulated conflict' }, 409);
        }
        const data = JSON.parse(body);
        const { eventId, eventType, date, timestamp, latitude, longitude } = data;

        if (processedEvents.has(eventId)) {
          return sendJson(res, {
            status: 'success',
            message: 'Idempotent replay accepted',
            record: attendanceRecords[date],
          }, 200);
        }

        const existing = attendanceRecords[date];
        if (eventType === 'checkIn') {
          if (existing && existing.checkInTime) {
            return sendJson(res, { error: 'Conflict', message: `Check-in already completed for ${date}` }, 409);
          }
          const record = {
            id: `att_${Date.now()}`,
            employeeId: data.employeeId,
            date,
            checkInTime: timestamp,
            checkInLatitude: latitude,
            checkInLongitude: longitude,
            checkOutTime: null,
            checkOutLatitude: null,
            checkOutLongitude: null,
            syncStatus: 'synced',
          };
          attendanceRecords[date] = record;
          processedEvents.add(eventId);
          return sendJson(res, record, 201);
        } else if (eventType === 'checkOut') {
          if (!existing || !existing.checkInTime) {
            return sendJson(res, { error: 'BadRequest', message: 'Cannot check-out without check-in' }, 400);
          }
          existing.checkOutTime = timestamp;
          existing.checkOutLatitude = latitude;
          existing.checkOutLongitude = longitude;
          existing.syncStatus = 'synced';
          processedEvents.add(eventId);
          return sendJson(res, existing, 200);
        }
      }

      if (req.method === 'GET' && pathname === '/leave/balance') {
        return sendJson(res, { casual: casualBalance, sick: sickBalance, total: casualBalance + sickBalance });
      }

      if (req.method === 'GET' && pathname === '/leave/requests') {
        return sendJson(res, leaveRequests);
      }

      if (req.method === 'POST' && pathname === '/leave/requests') {
        if (scenario === 'rejection') {
          return sendJson(res, { error: 'ValidationError', message: 'Simulated leave rejection policy' }, 422);
        }
        const data = JSON.parse(body);
        const newReq = {
          id: `leave_${Date.now()}`,
          employeeId: data.employeeId || 'EMP-1042',
          type: data.type,
          startDate: data.startDate,
          endDate: data.endDate,
          daysCount: data.daysCount,
          reason: data.reason,
          status: 'pending',
          appliedAt: new Date().toISOString(),
        };
        leaveRequests.unshift(newReq);
        if (data.type === 'casual') casualBalance -= data.daysCount;
        else sickBalance -= data.daysCount;
        return sendJson(res, newReq, 201);
      }

      sendJson(res, { error: 'Not found' }, 404);
    } catch (err) {
      sendJson(res, { error: err.message }, 500);
    }
  });
}

function sendJson(res, data, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

server.listen(PORT, () => {
  console.log(`REBS HRMS Mock Server listening on http://localhost:${PORT}`);
});
