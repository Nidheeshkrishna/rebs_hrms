# REBS HRMS — Offline-Capable Employee Workspace

A production-grade, offline-capable Flutter application built for **REBS** (Business Automation Platform with HRMS, CRM, and Accounts modules). This application allows employees to track attendance (check-in/check-out with GPS geofencing), manage their work sessions with real-time duration tracking, apply for leave with comprehensive validations, and reliably synchronize queued events once connectivity is restored.

---

## 📑 Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Completed Features](#2-completed-features)
3. [Offline Storage & Synchronization Strategy](#3-offline-storage--synchronization-strategy)
4. [Event Identity & Idempotency Design](#4-event-identity--idempotency-design)
5. [Device-Side vs Production Server Validations](#5-device-side-vs-production-server-validations)
6. [Reviewer Simulation & Tools Guide](#6-reviewer-simulation--tools-guide)
7. [Automated Testing Suite](#7-automated-testing-suite)
8. [Setup & Running Instructions](#8-setup--running-instructions)
9. [Trade-offs, Limitations & Time Spent](#9-trade-offs-limitations--time-spent)

---

## 1. Architecture Overview

The app follows **Clean Architecture** principles and utilizes the **Provider** state management pattern (`ChangeNotifierProvider` and dependency injection):

```
lib/
├── core/
│   ├── constants/        # System configuration, default coords, timezone, timeouts
│   ├── network/          # ApiClient (HTTP), MockHttpClient, NetworkInfo
│   ├── storage/          # DatabaseHelper (SQLite persistent cache & queue)
│   └── utils/            # DateUtils, GeofenceUtils (Haversine formula)
├── data/
│   ├── models/           # Employee, AttendanceRecord, AttendanceEvent, Leave
│   └── repositories/     # EmployeeRepository, AttendanceRepository, LeaveRepository
├── domain/
│   └── services/         # LocationService (GPS & geofence), SyncService (Auto-sync)
└── presentation/
    ├── providers/        # EmployeeProvider, AttendanceProvider, LeaveProvider, SyncProvider, SettingsProvider
    ├── screens/          # DashboardScreen, LeaveScreen, LeaveApplyScreen, HistoryScreen
    └── widgets/          # AttendanceCard, LeaveBalanceCard, AttendanceListTile, SyncStatusBadge, OfflineBanner, ReviewerToolsSheet
```

### Why Provider?
- **Lightweight & Predictable**: Eliminates boilerplate while providing robust reactive state updates, lifecycle management, and clear UI separation.
- **Testability**: Facilitates dependency injection of repositories, mock HTTP clients, and in-memory SQLite databases.
- **Separation of Concerns**: Presentation widgets contain zero business logic; build methods only read state and invoke provider actions.

---

## 2. Completed Features

### 🏢 Employee Dashboard
- **Profile Header**: Preconfigured employee (`Alexander Wright`, `EMP-1042`, `Core Business Automation`).
- **Today's Attendance Status**: Dynamically renders `Not Checked In`, `Checked In`, or `Checked Out`.
- **Live Elapsed Time Ticker**: Real-time ticker calculating hours, minutes, and seconds while checked in.
- **Leave Balance Summary**: Real-time breakdown of Casual, Sick, and Total leave days.
- **Recent Attendance History**: Displays the latest 5 attendance records with in/out timestamps, working duration, and sync status badges.
- **States Handled**: Loading spinner, Empty state, Error state with retry action, and Offline state banner.

### 📍 Attendance Check-In and Check-Out
- **Single Session per Day**: Enforces 1 check-in per calendar day in the company timezone.
- **Sequential Guard**: Check-out is permitted only after check-in.
- **Rapid Tap / Debounce Protection**: `isActionInProgress` locking prevents duplicate tap events.
- **GPS Coordinates & Geofencing**: Captures device GPS coordinates; validates against the office location with a 200-meter radius threshold using the Haversine formula.
- **Permission & Service Handling**:
  - Handles denied permission (requests access).
  - Handles permanently denied permission (directs to App Settings).
  - Handles disabled GPS location services (prompts to enable GPS).
  - Displays user-friendly distance message when outside the permitted boundary (e.g., *"You are 450.0m from office. Permitted radius is 200m"*).

### 🏖️ Leave Application & Tracking
- **Leave Form Fields**: Leave Type (Casual/Sick), Start Date, End Date, Reason.
- **Validation Engine**:
  1. Start date cannot be before current company date.
  2. End date cannot be before start date.
  3. Reason must contain at least 10 non-whitespace characters.
  4. Dates cannot overlap an existing Pending or Approved leave request.
  5. Requested days cannot exceed available balance.
  6. All calendar days count as leave days (ignores weekends and holidays as per assignment spec).
- **Status Badges**: Distinguishes `Pending`, `Approved`, and `Rejected` leave applications.
- **Offline Resilience**: Offline submission alerts the user that connectivity is required, while previously cached leave history remains readable offline.

---

## 3. Offline Storage & Synchronization Strategy

Offline capability is built on top of a local SQLite database (`sqflite`):

### 1. Persistence Tables
- `attendance_records`: Stores local daily records and historical records.
- `attendance_events_queue`: FIFO queue storing every check-in/check-out event (`AttendanceEvent`).
- `employee_cache`: Caches profile and office configuration.
- `leave_balance_cache` & `leave_requests_cache`: Caches leave data for offline viewing.

### 2. Synchronization Lifecycle
- **Offline Action**: When offline, valid check-in and check-out actions are saved locally with `SyncStatus.pendingSync`.
- **Preserved Across Restarts**: Pending events are stored in persistent SQLite; killing and reopening the app keeps pending actions intact.
- **Auto-Sync on Reconnect**: `connectivity_plus` monitors network transitions. When the device returns online, `SyncService` automatically triggers queue synchronization.
- **Manual "Sync Now"**: Available at all times via the top AppBar action button.
- **Ordering Guarantee (FIFO)**: Queue is sorted by `created_at ASC` ensuring check-in is submitted to the server before check-out.

---

## 4. Event Identity & Idempotency Design

### The Problem
In mobile networks, network timeouts and dropouts are frequent: the client submits a check-in event, the server receives and writes it to the database, but the network connection drops before the client receives the `200 OK` response. On retry, the client resubmits the same event. Without idempotency, this would create duplicate attendance records or throw a false conflict error.

### Our Solution
1. **UUIDv4 Event Identity**:
   - Every `AttendanceEvent` generated on the device is assigned a cryptographically random UUID (`eventId`).
   - This `eventId` is persisted locally in the SQLite queue and transmitted in the JSON payload and `X-Idempotency-Key` HTTP header.
2. **Server-Side Idempotency Check**:
   - The server maintains a set/table of processed `eventId` keys.
   - If an incoming event has an `eventId` that was already committed, the server detects the replay and returns `200 OK` with the existing attendance record, without re-executing business logic or creating duplicate records.
3. **Conflict vs Idempotency**:
   - If a new event with a *different* `eventId` tries to check in on a date that already has attendance, the server responds with `409 Conflict`.
   - The client marks that specific event as `SyncStatus.rejected` with the server's explanation.

---

## 5. Device-Side vs Production Server Validations

Device-side validation improves user experience by providing instant feedback and preventing wasteful network requests. However, a production server cannot trust the client and must repeat several checks:

| Validation Rule | Device-Side Check | Production Server Must Repeat | Reason |
| :--- | :---: | :---: | :--- |
| **GPS Geofence (200m)** | Calculated via GPS position | **Yes** (Repeat using verified coordinates or IP telemetry) | Client GPS can be spoofed or mocked on rooted/jailbroken devices. |
| **Timestamp & Session Date** | Device clock | **Yes** (Server-authoritative NTP timestamp) | Users can tamper with their device system clock to alter check-in times. |
| **One Check-In per Day** | SQLite cache check | **Yes** (Unique constraint on `(employee_id, date)`) | Prevents race conditions from multiple devices logged into the same account. |
| **Sequence (Check-Out after Check-In)** | Local daily status state machine | **Yes** (Verify existing check-in session before accepting check-out) | Protects against out-of-order API packets and malicious requests. |
| **Leave Overlap & Balance** | Cached leave list & balance | **Yes** (ACID transaction on database balance and booking calendar) | Prevents concurrent overdraws and double-bookings. |
| **Active Employee Status** | Cached employee profile | **Yes** (Check active directory/employment status) | Revoked/terminated employees must be blocked immediately from checking in. |

---

## 6. Reviewer Simulation & Tools Guide

To make evaluation effortless without external spoofing tools, tap the **Reviewer Tools** icon (`tune` icon) in the AppBar:

1. **GPS Simulation Modes**:
   - **At Office (0m)**: Simulates exact office coordinates.
   - **Near Office (120m)**: Simulates being within the 200m geofence.
   - **Outside Office (450m)**: Simulates being outside the geofence to test rejection messages.
   - **Real Device GPS**: Uses live device hardware GPS (`geolocator`).
2. **Repeatable Mock API Scenarios**:
   - **Normal (200/201)**: Standard successful server responses.
   - **Slow Response & Timeout**: Simulates high latency and timeout errors.
   - **Server Error (500)**: Simulates backend 500 errors.
   - **Duplicate Attendance Conflict (409)**: Triggers conflict rejections.
   - **Leave Policy Rejection (422)**: Triggers policy validation failure.
3. **Connectivity Simulator**:
   - **Auto (Device)**: Uses physical network status.
   - **Force Online / Force Offline**: Instantly toggle offline mode to demonstrate offline actions and auto-sync on reconnect.
4. **Clean Slate & Reset**:
   - 1-tap reset to clear all SQLite caches and seed fresh records for repeated testing.

---

## 7. Automated Testing Suite

The project includes automated tests covering all requirements:

1. **Attendance Rules Test** (`test/attendance_validation_test.dart`):
   - Check-out without check-in is rejected.
   - Multiple check-ins on the same day are rejected.
   - Geofence boundary verification (under 200m accepted, beyond 200m rejected).
2. **Persistence & Idempotency Test** (`test/sync_and_persistence_test.dart`):
   - Pending attendance survives persistence and is marked `pendingSync`.
   - Pending attendance survives simulated app restart and synchronizes in FIFO order.
   - Repeated submission/retry with the same idempotency key does not create duplicate attendance.
   - Conflict responses mark events as `rejected`.
3. **Leave Validation Test** (`test/leave_validation_test.dart`):
   - Overlapping leave dates are rejected.
   - Start date before current company date is rejected.
   - End date before start date is rejected.
   - Reason with < 10 non-whitespace characters is rejected.
   - Requested days exceeding available balance is rejected.
   - All calendar days count as leave days.
4. **Widget Tests** (`test/dashboard_widget_test.dart`):
   - Loading, Error, and Pending-Sync state rendering.

---

## 8. Setup & Running Instructions

### Prerequisites
- Flutter SDK `^3.13.7` (Dart `^3.13.7`)
- Android SDK (API 34+)

### Run Standalone Mock Server (Optional)
The app includes an internal mock HTTP engine by default. If you wish to run the standalone mock server:
```bash
# Using Dart
dart run server/mock_server.dart

# Or using Node.js
node server/mock_server.js
```

### Run the Flutter App
```bash
flutter pub get
flutter run
```

### Run All Automated Tests
```bash
flutter test
```

### Build Debug APK
```bash
flutter build apk --debug
```
The output APK is generated at:
`build/app/outputs/flutter-apk/app-debug.apk`

---

## 9. Trade-offs, Limitations & Time Spent

### Trade-offs & Engineering Decisions
- **HTTP Client**: Implemented a genuine `http.BaseClient` interface (`MockHttpClient`) with full JSON serialization, headers, and status code emulation. This satisfies the requirement that widgets communicate exclusively via an HTTP client while providing offline self-containment for testing on real devices.
- **In-Memory vs SQLite for Tests**: Used `sqflite_common_ffi` in unit tests to test genuine SQL transactions and schemas without platform channel dependencies.
- **Geofence Calculation**: Implemented the Haversine formula directly in Dart alongside `geolocator` so that distance calculation is deterministic across unit tests and device platforms.

### Assumptions & Limitations
- Assumed single attendance session per day (no overnight split shifts).
- All calendar days count as leave days (weekends and holidays ignored per assignment spec).
- Background execution while the app is terminated is outside the scope (as noted in requirements).

### Time Spent
- **Domain & Architecture Design**: 1.5 hours
- **Local Persistence & Sync Queue**: 2.0 hours
- **Location, Geofencing & Reviewer Simulator**: 1.5 hours
- **Leave Application & Validations**: 1.0 hours
- **UI & Widget Polish**: 1.0 hours
- **Automated Tests & Documentation**: 1.0 hours
- **Total Time**: ~8.0 hours
