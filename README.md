# LifeRoute Driver — Ambulance Driver & Dispatch System

This repository is organized into dedicated **Frontend** and **Backend** directories:

```
liferoute_driver/
├── frontend/    # Cross-platform Flutter mobile application for Ambulance Pilots & Paramedics
└── backend/     # Express.js REST API & WebSocket server for Dispatch & Telemetry
```

---

## 📱 Frontend (Flutter Mobile App)

Built with Flutter 3.x / Dart, Riverpod, CartoDB/OSM maps, real-time GPS telemetry, Firebase Phone Auth, and emergency sound alerts.

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🚑 Backend (REST API & WebSockets)

Built with Node.js, Express, and WebSockets for real-time dispatch alerts, driver telemetry, and active trip lifecycle.

```bash
cd backend
npm install
npm start
```
