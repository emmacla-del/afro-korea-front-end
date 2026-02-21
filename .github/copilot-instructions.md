# Afro-Korea Pool Mobile App - AI Agent Instructions

## Project Overview
This is a Flutter mobile application called "Afro-Korea Pool" that enables buyers in Cameroon to pool minimum order quantities (MOQ) from suppliers in Nigeria 🇳🇬 and Korea 🇰🇷. The app focuses on dual supply markets where Nigerian suppliers offer faster/cheaper options and Korean suppliers provide premium/unique products.

## Key Features & Architecture
- **Supplier Origin Filtering**: Filter products by Nigerian or Korean suppliers
- **MOQ Pooling**: Progress bars showing pool completion (e.g., "25/50 items")
- **Mobile Money Payments**: Integration with MTN and Orange payment systems
- **Real-time Pool Tracking**: Live updates on pool status and progress

## App Structure
- **Home Screen** (`lib/home_page.dart`): Dashboard with welcome banner, search bar, category chips (Beauty, Electronics, Fashion, Home), 2-column product grid
- **Product Cards**: Image placeholder, title (2 lines max), price in XAF (e.g., "15,000 XAF"), MOQ progress bar, "Join Pool" button
- **Navigation**: Bottom nav (Home, My Pools, Profile), floating cart button
- **Main Entry** (`lib/main.dart`): Simple entry point calling `runApp(MyApp())`

## Development Patterns
- **Currency Display**: Always use "XAF" for Cameroonian Franc (e.g., `Text('15,000 XAF')`)
- **Progress Bars**: Use `LinearProgressIndicator` for MOQ pooling (value = current/total)
- **Comments Style**: Include emojis and flags in code comments for clarity
- **Widget Structure**: Prefer `StatelessWidget` for UI components, `Scaffold` for screens

## Workflows
- **Run App**: `flutter run` (specify device if multiple)
- **Build APK**: `flutter build apk --release`
- **Build iOS**: `flutter build ios --release` (on macOS)
- **Tests**: `flutter test` (currently has default counter test that needs updating)
- **Dependencies**: `flutter pub get` after adding packages

## Integration Points
- **Payments**: Mobile Money APIs (MTN, Orange) - implement payment flows in separate service classes
- **Backend**: Expected API endpoints for suppliers, pools, user data - create `services/` directory for API calls
- **Real-time**: WebSocket or polling for pool updates - consider `web_socket_channel` package

## Code Examples
```dart
// Product card with MOQ progress
Card(
  child: Column(
    children: [
      Image.asset('placeholder.png'),
      Text('Premium Korean Skincare', maxLines: 2),
      Text('25,000 XAF'),
      LinearProgressIndicator(value: 0.5), // 25/50 items
      Text('25/50 pooled'),
      ElevatedButton(onPressed: () {}, child: Text('Join Pool')),
    ],
  ),
)
```

## Getting Started
1. Ensure Flutter SDK ^3.10.1 installed
2. Run `flutter pub get` in project root
3. Connect device or start emulator
4. Run `flutter run` to launch app
5. Update `widget_test.dart` to test actual app features instead of counter

Focus on implementing the home page UI as described in `home_page.dart` comments, then add navigation and state management for pools and payments.