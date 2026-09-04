# 🏥 SantéTogo - Healthcare Management Platform

A comprehensive Flutter-based healthcare management system connecting patients, doctors, pharmacists, and administrators across Togo.

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run on specific platform
flutter run -d chrome    # Web
flutter run -d android   # Android emulator
flutter run -d ios       # iOS simulator
```

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── config/                # Colors, theme, constants
├── models/                # Data models (User, Patient, Ordonnance, etc)
├── services/              # API client & local storage
├── providers/             # State management (Riverpod)
├── widgets/               # Reusable UI components
└── screens/               # Complete app screens
    ├── auth/              # Login screen
    ├── admin/             # Admin dashboard
    ├── pharmacie/         # Pharmacy workflow
    └── patient/           # Patient app
```

## ✨ Key Features

### Authentication
- Email/password login with validation
- JWT token management with refresh
- Role-based access control (5 roles)

### Admin Panel
- Dashboard with KPI statistics
- Clinic/Pharmacy management
- PVC card ordering system
- Audit logs

### Pharmacy App
- QR code scanner for prescriptions
- Prescription verification
- Delivery tracking & confirmation
- Real-time statistics

### Patient Portal
- Medical dossier with health info
- QR identification card (offline-capable)
- Prescription history
- Lab results
- Appointment tracking

## 🛠️ Technology Stack

- **Framework:** Flutter 3.16+
- **Language:** Dart 3.0+
- **State Management:** Riverpod
- **HTTP Client:** Dio
- **Local Storage:** Hive & SharedPreferences
- **Authentication:** JWT with token refresh
- **UI Framework:** Material 3

## 📦 Core Dependencies

```yaml
flutter_riverpod: ^2.6.1      # State management
dio: ^5.3.1                   # HTTP client
shared_preferences: ^2.2.0    # Key-value storage
hive_flutter: ^1.1.0          # Local database
google_fonts: ^6.3.3          # Typography
qr_flutter: ^4.0.0            # QR code generation
firebase_core: ^2.32.0        # Firebase
camera: ^0.10.6               # Camera access
mobile_scanner: ^5.2.3        # QR scanning
```

## 🎨 Design System

- **Primary Color:** Green (#0D7A5C)
- **Typography:** Syne (headings), Inter (body)
- **Spacing:** 8px baseline system
- **Components:** 12+ reusable widgets
- **Responsive:** Works on all screen sizes

## 📱 Supported Platforms

- ✅ Android (5.0+)
- ✅ iOS (13.0+)
- ✅ Web (Chrome, Firefox, Safari)
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/api_service_test.dart
```

## 🔐 Security Features

- JWT token-based authentication
- Token refresh mechanism
- Encrypted local storage
- API request/response interceptors
- Input validation

## 📊 Project Status

| Phase | Component | Status |
|-------|-----------|--------|
| 1 | Core Frontend | ✅ Complete |
| 1 | Models & Services | ✅ Complete |
| 1 | Login Screen | ✅ Complete |
| 1 | Admin Dashboard | ✅ Complete |
| 1 | Pharmacy App | ✅ Complete |
| 1 | Patient Portal | ✅ Complete |
| 2 | Navigation/Routing | 🔄 In Progress |
| 2 | Backend Integration | 🔄 In Progress |
| 3 | QR Scanning | 📋 Planned |
| 3 | Firebase/FCM | 📋 Planned |

**Stats:**
- 22 implementation files
- 4 production-ready screens
- ~2,800+ lines of code
- Full design system
- 0 external UI dependencies (custom-built)

## 🚀 Build & Deploy

```bash
# Android APK
flutter build apk --release

# iOS IPA
flutter build ios --release

# Web
flutter build web

# macOS
flutter build macos

# Windows
flutter build windows
```

## 📚 Additional Resources

- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Detailed architecture
- [Backend API Docs](backend/README.md) - Server endpoints
- [Flutter Docs](https://flutter.dev/docs)
- [Material Design 3](https://m3.material.io)

## 🤝 Contributing

1. Create feature branch: `git checkout -b feature/my-feature`
2. Follow Dart style guide
3. Write tests for new features
4. Submit PR with description

## ⚠️ Current Limitations

- Analyzer may show false import errors (run `flutter clean && flutter pub get`)
- QR generation uses mock (real camera scanning needed)
- Firebase config files needed for production
- Clinic staff screens not yet implemented

## 📞 Support

For issues or questions, check the [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) or contact the dev team.

---

**Made with ❤️ for SantéTogo**

