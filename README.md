# Kita Kita - Flutter Mobile App

**Kita Kita** (meaning "I see you" in Filipino) is a real-time location sharing mobile application built with Flutter. The app enables users to share their live GPS location with group members, displaying everyone on an interactive map with battery status monitoring.

## Features

- **Real-Time Location Sharing** - Share your live GPS location with group members
- **Interactive Map Display** - View all group members on a map with custom markers
- **Battery Status Monitoring** - See device battery levels with color-coded indicators
- **Group Management** - Create groups, generate shareable codes, and manage members
- **Background Location Tracking** - Continue tracking location even when app is closed
- **User Profile Management** - View and edit profile information
- **Customizable Settings** - Adjust update frequency, battery saver mode, and notifications

## Project Structure

```
lib/
├── main.dart                    # App entry point with routing
├── config/
│   ├── theme.dart             # Theme configuration
│   └── router.dart            # Navigation setup
├── screens/
│   ├── splash_screen.dart     # Splash/loading screen
│   ├── login_screen.dart      # Authentication
│   ├── home_screen.dart       # Main map view
│   ├── groups_screen.dart     # Group management
│   ├── group_details_screen.dart  # Group members
│   ├── profile_screen.dart    # User profile
│   └── settings_screen.dart   # App settings
├── services/
│   ├── location_service.dart  # GPS handling
│   ├── battery_service.dart   # Battery monitoring
│   └── background_service.dart # Background tasks
├── models/
│   ├── user.dart              # User model
│   ├── group.dart             # Group model
│   └── location.dart          # Location model
└── widgets/
    ├── map_marker.dart        # Custom markers
    └── battery_badge.dart     # Battery display
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or later
- Dart SDK 2.18.0 or later
- Android SDK API 24 or higher
- Android Studio or VS Code with Flutter extension

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/kita_kita_flutter.git
   cd kita_kita_flutter
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Android Studio Setup

For detailed Android Studio setup instructions, see [ANDROID_STUDIO_SETUP.md](ANDROID_STUDIO_SETUP.md).

### Quick Setup

1. Open Android Studio
2. Click "Open" and select the `kita_kita_flutter` directory
3. Wait for indexing to complete
4. Run `flutter pub get` in terminal
5. Click the green Run button or press `Shift + F10`

## Building for Release

### APK (for testing)
```bash
flutter build apk --release
```

### App Bundle (for Google Play)
```bash
flutter build appbundle --release
```

## Architecture

The app follows a clean architecture pattern with clear separation of concerns:

- **Presentation Layer** - UI screens and widgets
- **Business Logic Layer** - Services for location, battery, and background tasks
- **Data Layer** - Models and API communication

## Theme

The app uses a modern color scheme:

| Color | Hex Code | Usage |
|-------|----------|-------|
| Primary Blue | #0066CC | Main actions, highlights |
| Success Green | #22C55E | Battery >50%, positive states |
| Warning Yellow | #FBBF24 | Battery 20-50%, caution |
| Danger Red | #EF4444 | Battery <20%, errors |
| Background | #FFFFFF | Light mode background |
| Surface | #F8FAFC | Cards, elevated surfaces |

## Permissions

The app requires the following Android permissions:

- `ACCESS_FINE_LOCATION` - GPS location
- `ACCESS_COARSE_LOCATION` - Network location
- `ACCESS_BACKGROUND_LOCATION` - Background tracking
- `INTERNET` - API communication
- `BATTERY_STATS` - Battery monitoring

## Navigation

The app uses `go_router` for navigation:

| Route | Screen |
|-------|--------|
| `/` | Splash Screen |
| `/login` | Login Screen |
| `/home` | Home/Map Screen |
| `/groups` | Groups Screen |
| `/group-details/:groupId` | Group Details |
| `/profile` | Profile Screen |
| `/settings` | Settings Screen |

## Development

### Hot Reload
```bash
flutter run
# Press 'r' to hot reload, 'R' for full restart
```

### View Logs
```bash
flutter logs
```

### Run Tests
```bash
flutter test
```

## Troubleshooting

### "Flutter SDK not found"
- Ensure Flutter is installed and added to PATH
- Run `flutter doctor` to verify installation

### "Android SDK not found"
- Open Android Studio SDK Manager
- Install required SDK components
- Set `ANDROID_SDK_ROOT` environment variable

### App crashes on startup
- Check logcat: `flutter logs`
- Verify all permissions are declared in AndroidManifest.xml
- Ensure location permission is granted on device

### Emulator won't start
- Delete and recreate the emulator
- Ensure sufficient RAM and disk space
- Close other resource-intensive applications

## Dependencies

Key packages used in this project:

- **go_router** - Navigation and routing
- **provider** - State management
- **dio** - HTTP client
- **google_maps_flutter** - Map display
- **geolocator** - GPS services
- **battery_plus** - Battery monitoring
- **workmanager** - Background tasks
- **shared_preferences** - Local storage

See `pubspec.yaml` for complete list.

## Next Steps

1. **Integrate Backend API** - Connect to your backend server
2. **Implement Google Maps** - Add map display with markers
3. **Setup Location Services** - Configure GPS tracking
4. **Add Notifications** - Implement push notifications
5. **Test on Devices** - Test on various Android devices

## Support

For issues or questions, please open an issue on the GitHub repository.

## License

This project is licensed under the MIT License.

---

**Happy location sharing! 👁️**
