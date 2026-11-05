# LifeRoute Driver — Backend Service

A lightweight, high-performance Node.js REST API & WebSocket server for ambulance pilots and paramedics.

## Features
- **Driver Authentication**: Driver profile management and verified phone login.
- **Online/Offline Status**: Real-time duty toggle for dispatch routing.
- **Live GPS Telemetry**: High-frequency location streaming to dispatchers and patients.
- **Booking Acceptance & Lifecycle**: Accept dispatch, en-route, arrived at pickup, patient on-board, and hospital completion.
- **WebSockets**: Real-time push notifications (`booking-claimed`, `DriverLocationUpdated`, `BookingAcceptedByOther`).

## Getting Started

```bash
# 1. Install dependencies
npm install

# 2. Run the server
npm start

# 3. Run flow tests
npm run test:flow
```

- REST API runs on `http://localhost:8000`
- WebSocket Server runs on `ws://localhost:8080`

