# LifeRoute Driver — Ambulance Driver & Dispatch System

This repository contains the complete **Driver Application (Flutter Mobile & Web)** and the **Central Backend & Admin Command Center (Laravel 12 API, WebSockets & MySQL)**.

```
liferoute-driver/
├── frontend/    # Cross-platform Flutter mobile application for Ambulance Drivers & Pilots
└── backend/     # Laravel 12 (PHP 8.2) REST API, Ratchet WebSocket Server & Central Admin
```

---

## 📱 Frontend (Flutter Driver App)

Built with Flutter 3.x / Dart, Riverpod, CartoDB/OSM maps, real-time GPS telemetry, background emergency alerts, document upload verification, and live turn-by-turn navigation.

### Running Driver App:
```bash
cd frontend
flutter pub get

# Run on Web:
flutter run -d chrome

# Run on Android Device:
flutter run -d <device_id> --dart-define=DEFAULT_LAN_HOST=<your_backend_ip>
```

---

## 🚑 Central Backend & Admin Command Center

Built with Laravel 12 (PHP 8.2), MySQL (`liferoute`), and Ratchet RFC6455 WebSockets for live driver dispatch alerts, real-time coordinate broadcasting, and active emergency lifecycle management.

* **Admin Command Center**: `http://localhost:8000/admin`
* **Admin Login**:
  - Email: `admin@gmail.com`
  - Password: `Admin@1234`

### Running Backend:
```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed

# 1. Start WebSocket Daemon:
php artisan websocket:serve --host=0.0.0.0 --port=8080

# 2. Start HTTP API:
php artisan serve --host=0.0.0.0 --port=8000
```
