# Development guide (Mobile)

This guide covers day-to-day development for the Flutter app in `mobile/`, plus how to run the optional backend in `mobile/server/`.

## 1) Prerequisites

Confirm your toolchain:

```bash
flutter --version
flutter doctor -v
```

Typical platform requirements:

- **Windows desktop**: Visual Studio (Desktop development with C++), Windows SDK
- **Android**: Android Studio + SDK, accepted licenses
- **Web**: Chrome or Edge installed

## 2) Install dependencies

From `mobile/`:

```bash
flutter pub get
```

## 3) Run the Flutter app (hot reload)

List available targets:

```bash
flutter devices
```

Run on Windows desktop:

```bash
flutter run -d windows
```

Run on web (Chrome):

```bash
flutter run -d chrome
```

Run on Android:

```bash
flutter run -d <device-id>
```

Notes:
- While `flutter run` is active: press `r` for hot reload, `R` for hot restart, `q` to quit.
- If you don't see your Android device, re-check `flutter doctor -v`.

## 4) Build binaries (release)

From `mobile/`:

- Windows:
  - `flutter build windows`
  - Output: `build/windows/x64/runner/Release/mobile.exe`
- Web:
  - `flutter build web`
  - Output: `build/web/`
- Android:
  - APK: `flutter build apk`
  - App Bundle: `flutter build appbundle`

## 5) Quality checks

Static analysis:

```bash
flutter analyze
```

Tests:

```bash
flutter test
```

The widget tests use `network_image_mock` to avoid real network calls.

## 6) App structure (where to change things)

- `lib/main.dart`: app entry point + role-based routing (Customer vs Supplier)
- `lib/pages/home_page.dart`: Customer home/browse experience (filters, search, grid)
- `lib/pages/supplier_dashboard_page.dart`: Supplier dashboard screen
- `lib/widgets/`: shared UI components (product card, supplier filter, role switch)
- `lib/models/product.dart`: product model used by the UI
- `lib/services/mock_product_service.dart`: current data source (mock products)

## 7) Backend (optional, lives in `server/`)

The Flutter UI currently uses mock data. The backend in `server/` is available for an MVP workflow (pools, commitments, orders, supplier catalog), but the Flutter app is not yet wired to it.

### 7.1 Prereqs

- Node.js
- PostgreSQL database (local or hosted)

### 7.2 Setup and run (Windows)

From `mobile/server/`:

1) Create `.env`:

```bat
copy .env.example .env
```

2) Edit `.env` and set `DATABASE_URL`.

3) Install dependencies:

```bat
npm.cmd install
```

4) Generate Prisma client:

```bat
npm.cmd run prisma:generate
```

5) Run migrations (requires DB reachable):

```bat
npm.cmd run prisma:migrate
```

6) Start the API:

```bat
npm.cmd run dev
```

By default the server listens on `https://afro-korea-pool-server.onrender.com` in production (or `http://localhost:3000` when running locally).

For endpoint examples and the MVP auth model (uses `x-user-id`), read: `server/README.md`.

## 8) If something breaks

Common reset steps (from `mobile/`):

```bash
flutter clean
flutter pub get
```

If Windows build tools are missing, `flutter doctor -v` usually points to what to install/fix.

## 9) Verified environment (reference)

Last verified on **February 6, 2026** (Windows):

- Flutter: `3.38.3` (stable)
- Dart: `3.10.1`
- Android SDK: `36.1.0`
