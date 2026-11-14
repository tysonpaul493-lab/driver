# LifeRoute Driver — Ambulance Driver & Dispatch Application

Official Flutter application for Ambulance Pilots, Paramedics, and Emergency Responders.

---

## 🌐 Deploy to Vercel

This repository is optimized for one-click deployment on [Vercel](https://vercel.com):

1. **Import this repository** on Vercel.
2. **Framework Preset**: `Other` (or leave default).
3. **Build & Output Settings**:
   - `vercel.json` automatically sets up the environment and executes the build.
   - Output Directory: `build/web`
4. Click **Deploy**.

---

## 📱 Running Locally

### Web:
```bash
flutter pub get
flutter run -d chrome
```

### Mobile (Android):
```bash
flutter run -d <device_id> --dart-define=DEFAULT_LAN_HOST=<your_server_ip>
```

---

## ⚙️ Connecting to Backend API

On the Login screen:
- Click **"Emergency Dispatch Server Settings"** at the bottom to configure your backend IP/hostname.
- Or pass at build time: `--dart-define=DEFAULT_API_URL=https://your-api.com/api/v1`

