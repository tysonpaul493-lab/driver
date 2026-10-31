# LifeRoute Driver — Ambulance Driver App

A standalone Flutter mobile application built for Ambulance Pilots and Paramedics. It connects seamlessly to the shared **Laravel (Sanctum + Reverb) + MySQL** emergency dispatch backend.

---

## 1. Technology Stack

- **Framework**: Flutter 3.47+ & Dart 3.13+ (Null-safe)
- **State Management**: [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (StateNotifier, ProviderScope)
- **Networking**: [Dio](https://pub.dev/packages/dio) with Sanctum Bearer token auto-injection, retry policy, and multipart file upload
- **Real-Time WebSockets**: [Pusher Channels Flutter](https://pub.dev/packages/pusher_channels_flutter) configured for [Laravel Reverb](https://laravel.com/docs/reverb) (private encrypted driver and booking channels)
- **Push Notifications**: [Firebase Cloud Messaging (FCM)](https://pub.dev/packages/firebase_messaging) for high-priority dispatch alerts
- **GPS & Telemetry**: [Geolocator](https://pub.dev/packages/geolocator) with high-accuracy distance filtering (10m) and battery-conscious throttled HTTP telemetry (3.5s interval)
- **Mapping & Routing**: [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter) with animated vehicle bearing, patient markers, emergency hospital markers, and route polylines
- **Secure Token Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for Sanctum tokens and encrypted driver profiles
- **External Navigation & Telephony**: [url_launcher](https://pub.dev/packages/url_launcher) (`tel:` for calling patient/dispatcher, `geo:` / Google Maps for external turn-by-turn navigation)

---

## 2. Architecture & Project Structure

The project follows a modular, feature-first structure:

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart          # REST endpoints & Reverb WebSocket config
│   │   ├── app_colors.dart             # Curated emergency midnight palette
│   │   ├── app_theme.dart              # Material 3 dark contrast theme
│   │   └── storage_keys.dart           # Secure storage identifiers
│   ├── network/
│   │   ├── api_exception.dart          # Standardized error mapping
│   │   ├── auth_interceptor.dart       # Sanctum token injection & 401 handling
│   │   └── dio_client.dart             # HTTP client with multipart upload
│   ├── notifications/
│   │   └── fcm_service.dart            # Firebase push messaging & token synchronization
│   ├── storage/
│   │   └── secure_storage_service.dart # FlutterSecureStorage & SharedPreferences wrapper
│   ├── utils/
│   │   ├── audio_alert_service.dart    # Emergency sirens & haptic feedback patterns
│   │   ├── date_utils.dart             # Timestamp formatting
│   │   └── distance_utils.dart         # Haversine distance & emergency ETA calculator
│   └── websocket/
│       ├── reverb_provider.dart        # Riverpod WebSocket stream bindings
│       └── reverb_service.dart         # Laravel Reverb private channel client
├── features/
│   ├── active_trip/
│   │   ├── models/
│   │   │   ├── trip_model.dart         # Patient details, pickup coords, hospital destination
│   │   │   └── trip_status.dart        # 7-step lifecycle state machine
│   │   ├── providers/
│   │   │   └── active_trip_provider.dart
│   │   ├── repositories/
│   │   │   └── active_trip_repository.dart
│   │   └── screens/
│   │       └── active_trip_screen.dart # Live map, progress timeline, patient sheet, call button
│   ├── auth/
│   │   ├── models/
│   │   │   ├── auth_response.dart
│   │   │   ├── driver_model.dart       # Verification status, credentials, documents map
│   │   │   └── vehicle_model.dart      # BLS/ALS/PTV/NICU, equipment inventory, permits
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   ├── repositories/
│   │   │   └── auth_repository.dart
│   │   └── screens/
│   │       ├── document_upload_screen.dart
│   │       ├── driver_registration_screen.dart
│   │       ├── otp_verification_screen.dart
│   │       ├── phone_login_screen.dart
│   │       └── verification_pending_screen.dart
│   ├── dashboard/
│   │   ├── models/
│   │   │   └── dashboard_summary_model.dart
│   │   ├── providers/
│   │   │   └── dashboard_provider.dart
│   │   ├── repositories/
│   │   │   └── dashboard_repository.dart
│   │   └── screens/
│   │       └── driver_dashboard_screen.dart # Online/Offline toggle, stats, dispatch simulator
│   ├── history/
│   │   ├── models/
│   │   │   └── trip_history_item.dart
│   │   └── screens/
│   │       └── trip_history_screen.dart
│   ├── location/
│   │   ├── providers/
│   │   │   └── location_provider.dart
│   │   └── services/
│   │       └── driver_location_service.dart # Background GPS stream, telemetry pings, stale detector
│   ├── navigation/
│   │   └── widgets/
│   │       └── trip_map_view.dart      # Google Maps widget with polyline & custom vehicle marker
│   ├── notifications/
│   │   ├── models/
│   │   │   └── app_notification_model.dart
│   │   └── screens/
│   │       └── notifications_screen.dart
│   ├── profile/
│   │   └── screens/
│   │       └── driver_profile_screen.dart
│   └── requests/
│       ├── models/
│       │   └── booking_request_model.dart
│       ├── providers/
│       │   └── requests_provider.dart
│       ├── repositories/
│       │   └── requests_repository.dart
│       └── widgets/
│           └── incoming_request_sheet.dart  # 30s circular countdown, strobe alert, instructions
└── shared/
    └── widgets/
        ├── custom_button.dart          # High-contrast action buttons
        ├── emergency_banner.dart       # Warning & status banners
        ├── pulse_indicator.dart        # Pulsing GPS and online telemetry dots
        └── status_badge.dart           # Triage urgency chips and verification chips
```

---

## 3. Strict 7-Step Trip Lifecycle Workflow

Every trip action invokes the Laravel API endpoint `PATCH /api/v1/driver/trips/{id}/status` and automatically broadcasts to the User App (`private-booking.{id}`) and Admin Dashboard:

```
[1. Accept Booking]
       │
       ▼
[2. Navigate to Patient] (Status: en_route_to_pickup)
       │
       ▼
[3. Mark Arrived at Pickup] (Status: arrived_at_pickup)
       │
       ▼
[4. Confirm Patient Pickup] (Status: patient_onboard)
       │
       ▼
[5. Start Trip to Hospital] (Status: in_transit_to_hospital)
       │
       ▼
[6. Arrived at Hospital] (Status: arrived_at_hospital)
       │
       ▼
[7. Complete Trip & Handover] (Status: completed)
       │
       └──> Automatically halts background GPS tracking & unsubscribes Reverb channels
```

---

## 4. Race Condition & Conflict Handling

- When an emergency booking is broadcast to nearby ambulances, only the **first** driver to confirm acceptance claims the trip.
- If another ambulance accepts first:
  - The Laravel backend returns `409 Conflict`.
  - The app catches the conflict, displays an informative dialog (`"This emergency booking was already accepted by another ambulance or claimed by dispatch"`), and immediately dismisses the pending request.
  - Concurrently, if a Reverb `BookingAcceptedByOther` event is received via WebSocket, the incoming 30-second countdown sheet is closed automatically without requiring user interaction.

---

## 5. Live GPS Tracking & Telemetry Protocol

During an active assignment:
- **Frequency**: Emits upon 10-meter position change, network transmissions throttled to 3.5-second minimum intervals to protect cellular battery.
- **Payload Schema (`POST /api/v1/driver/location/telemetry`)**:
  ```json
  {
    "driver_id": 42,
    "booking_reference": "BK-89241",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "accuracy": 4.5,
    "heading": 185.0,
    "speed": 11.2,
    "timestamp": "2026-10-28T12:45:00.000Z"
  }
  ```
- **Stale Detection**: If no GPS fix is received for >15 seconds, a visual amber warning (`STALE GPS`) appears on the active trip top bar.
- **Privacy Assurance**: GPS telemetry automatically ceases when the driver switches offline or when the trip is marked `completed` or `cancelled`.

---

## 6. Laravel Backend API Contracts

### Authentication
- `POST /api/v1/driver/auth/send-otp`
  - Body: `{"phone": "+919876543210"}`
- `POST /api/v1/driver/auth/verify-otp`
  - Body: `{"phone": "+919876543210", "otp": "123456", "device_name": "Mobile"}`
  - Response: `{"token": "1|sanctum_token...", "driver": {...}}`
- `POST /api/v1/driver/auth/register`
  - Body: Driver profile, vehicle specifications, equipment checklist, and permit numbers.
- `POST /api/v1/driver/documents/upload`
  - Multipart: `document`, `document_type`, `expiry_date`

### Dashboard & Status
- `GET /api/v1/driver/dashboard/summary`
- `POST /api/v1/driver/status/toggle`
  - Body: `{"is_online": true, "latitude": 12.97, "longitude": 77.59}`

### Emergency Requests & Trips
- `GET /api/v1/driver/requests/pending`
- `POST /api/v1/driver/requests/{id}/accept`
- `POST /api/v1/driver/requests/{id}/decline`
- `GET /api/v1/driver/trips/active`
- `PATCH /api/v1/driver/trips/{id}/status`
- `POST /api/v1/driver/location/telemetry`

---

## 7. Setup & Run Instructions

### Prerequisites
1. Flutter SDK 3.47+ installed (`flutter --version`)
2. Android SDK with Build Tools 34+
3. Valid Google Maps API key

### Configuration
1. **Google Maps**:
   - In `android/app/src/main/AndroidManifest.xml`, replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your key.
2. **Backend Base URL**:
   - In `lib/core/constants/api_constants.dart`, update `defaultBaseUrl` (or use the Settings gear icon in the app's login screen).
3. **Firebase FCM**:
   - Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.

### Run
```bash
# Fetch dependencies
flutter pub get

# Run analyzer
flutter analyze

# Execute test suite
flutter test

# Launch on connected Android device / emulator
flutter run -d emulator-5554
```
