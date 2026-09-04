# 🚀 SantéTogo - Next Steps & Quick Start

## Current Status: ✅ Phase 1 Complete

**What's Done:**
- ✅ 19 production-ready Dart files (~2,800+ lines)
- ✅ Complete design system (colors, typography, spacing)
- ✅ 4 functional screens (Login, Admin, Pharmacy, Patient)
- ✅ Riverpod state management
- ✅ API service with interceptors
- ✅ Local storage (Hive + SharedPreferences)
- ✅ 5 data models with JSON serialization

**What's Next:**
- 🔄 Navigation setup (GoRouter)
- 🔄 Real backend integration testing
- 📋 Clinic staff screens
- 📋 Firebase + FCM
- 📋 Real QR scanning

---

## 📋 Quick Start Guide

### 1. Get Familiar with the Codebase

```bash
# Open the project
cd c:\Users\paul.DESKTOP-A29SUEI\paul\sante\sante

# Review the architecture
cat ARCHITECTURE.md          # Detailed system design
cat IMPLEMENTATION_SUMMARY.md # What was built
cat README.md                # Quick reference
cat TROUBLESHOOTING.md       # Common issues
```

### 2. Run the App Locally

```bash
# Install dependencies
flutter pub get

# Build for your preferred platform
flutter run -d chrome        # Web (easiest for testing)
flutter run -d android       # Android emulator (if set up)
flutter run -d ios           # iOS simulator (Mac only)

# To see debug output
flutter run -v
```

### 3. Test the Current Screens

**Login Screen:**
- URL: http://localhost:3000 (backend)
- Test credentials from backend tests
- Email: `admin@sante.tg`
- Password: `admin123`

**Admin Dashboard:**
- After login as admin
- See: 4 stat cards with sample data
- Try: Click sidebar items (will show "À implémenter")

**Pharmacy Dashboard:**
- After login as pharmacist
- Try: Click "Tap to scan" in Scanner view
- See: Patient card with allergies in RED

**Patient Portal:**
- After login as patient
- See: QR card with offline display
- Try: Click tabs for dossier info

### 4. Explore the Code Structure

```
lib/
├── config/          ← Start here! App-wide constants
│   ├── app_colors.dart
│   ├── app_theme.dart
│   └── app_constants.dart
│
├── models/          ← Data structures matching backend
│   ├── user.dart
│   ├── patient.dart
│   ├── consultation.dart
│   ├── ordonnance.dart
│   └── analyse.dart
│
├── services/        ← API & Storage layer
│   ├── api_service.dart (Dio HTTP client)
│   └── local_storage_service.dart (Hive)
│
├── providers/       ← State management (Riverpod)
│   └── auth_provider.dart
│
├── widgets/         ← Reusable UI components
│   ├── common_widgets.dart (Buttons, Cards)
│   ├── stat_widgets.dart (Stats, Patient info)
│   └── qr_widgets.dart (QR display, Scanner)
│
├── screens/         ← Full page views
│   ├── auth/login_screen.dart
│   ├── admin/admin_dashboard_screen.dart
│   ├── pharmacie/pharmacy_dashboard_screen.dart
│   └── patient/patient_home_screen.dart
│
└── main.dart        ← App entry point
```

---

## 🔧 Phase 2: Navigation Setup

### Step 1: Create Router File

**File:** `lib/routing/app_router.dart`

```dart
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sante/screens/auth/login_screen.dart';
import 'package:sante/screens/admin/admin_dashboard_screen.dart';
import 'package:sante/screens/pharmacie/pharmacy_dashboard_screen.dart';
import 'package:sante/screens/patient/patient_home_screen.dart';
import 'package:sante/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      // Redirect unauthenticated users to login
      if (!isAuthenticated && state.matchedLocation != '/login') {
        return '/login';
      }

      // Redirect authenticated users away from login
      if (isAuthenticated && state.matchedLocation == '/login') {
        // Route based on role
        return authState.maybeWhen(
          data: (user) {
            if (user?.role == 'admin') return '/admin';
            if (user?.role == 'pharmacien') return '/pharmacy';
            if (user?.role == 'patient') return '/patient';
            if (['medecin', 'secretaire'].contains(user?.role)) {
              return '/clinic';
            }
            return '/login';
          },
          orElse: () => '/login',
        );
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/pharmacy',
        builder: (context, state) => const PharmacyDashboardScreen(),
      ),
      GoRoute(
        path: '/patient',
        builder: (context, state) => const PatientHomeScreen(),
      ),
      // TODO: Add clinic staff screen
      // GoRoute(
      //   path: '/clinic',
      //   builder: (context, state) => const ClinicDashboardScreen(),
      // ),
    ],
  );
});
```

### Step 2: Update main.dart

```dart
// Replace the initial home with GoRouter
import 'package:sante/routing/app_router.dart';

// In SanteTogoApp.build():
return MaterialApp.router(
  title: 'SantéTogo',
  theme: AppTheme.lightTheme(),
  routerConfig: ref.watch(appRouterProvider),
);
```

### Step 3: Test Navigation

```bash
flutter run -d chrome

# You should see:
# 1. Login screen first
# 2. After login → Appropriate dashboard based on role
# 3. Logout → Back to login
```

---

## 🏗️ Phase 3: Clinic Staff Dashboard

### File: `lib/screens/clinique/clinic_dashboard_screen.dart`

Create a new screen for doctors/clinic staff with:

1. **Dashboard View:**
   - Today's appointments (list)
   - Patient queue
   - Recent consultations

2. **Patients View:**
   - Patient search/filter
   - Patient list with status
   - New patient button

3. **Consultations View:**
   - Create new consultation form
   - Consultation history

4. **Ordonnances View:**
   - Create prescription
   - Allergy checking (show RED warning)
   - Prescription history

5. **Analytics View:**
   - Appointments chart
   - Patient demographics
   - Ordonnance trends

---

## 🔌 Phase 4: Real Backend Integration

### Current State:
- ✅ Models defined for API integration
- ✅ API endpoints written in `api_service.dart`
- ✅ Token management implemented
- ✅ Error handling with interceptors

### What to Update:

1. **Replace Mock Data:**

   In `admin_dashboard_screen.dart`:
   ```dart
   // ❌ Currently hardcoded
   final stats = [
     {value: '1,248', label: 'Patients', delta: '+12%'},
     // ...
   ];

   // ✅ Should call API
   final patientsCount = await apiService.getPatients();
   ```

2. **Fetch Real Clinic Data:**

   ```dart
   final clinics = await apiService.getClinics();
   final pharmacies = await apiService.getPharmacies();
   ```

3. **Handle Loading States:**

   ```dart
   // Use AsyncValue from Riverpod
   final clinicsAsync = ref.watch(clinicsProvider);
   
   return clinicsAsync.when(
     loading: () => CircularProgressIndicator(),
     error: (err, st) => Text('Error: $err'),
     data: (clinics) => ListView(children: clinics),
   );
   ```

---

## 🔐 Testing Checklist

Before moving to Phase 5, verify:

- [ ] Login works with backend
- [ ] Tokens are saved and refreshed correctly
- [ ] Each role routes to correct dashboard
- [ ] Patient QR card displays (with offline storage)
- [ ] Pharmacy QR scan interface works
- [ ] Allergies display in RED on all screens
- [ ] Admin can see correct clinic/pharmacy data
- [ ] All forms validate input correctly
- [ ] Error messages display properly
- [ ] App works on mobile (width < 600px)
- [ ] App works on desktop (width ≥ 600px)
- [ ] Logout clears auth state and storage

---

## 📱 Building for Platforms

### Android
```bash
# Build debug APK
flutter build apk

# Build release APK
flutter build apk --release

# Install on device
flutter install
```

### iOS (Mac only)
```bash
# Build debug
flutter build ios

# Build release
flutter build ios --release

# Deploy to TestFlight
cd ios && fastlane beta
```

### Web
```bash
# Build web
flutter build web

# Run web version
flutter run -d chrome --web-renderer=html

# Serve locally
cd build/web
python -m http.server 8000
```

### macOS/Windows
```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

---

## 📊 Monitoring & Debugging

### Check App Performance
```bash
flutter run --profile

# Then in another terminal
open http://localhost:9100/devtools
```

### View Network Calls
```dart
// Add to api_service.dart
import 'package:dio/dio.dart';

// Dio logs all requests/responses
// Access DevTools Network tab to see them
```

### Check Local Storage
```dart
// Add debug print in local_storage_service.dart
Future<void> savePatientQrCode(String id, String token) async {
  final box = await Hive.openBox('patient_qr_box');
  print('Saving QR: $id -> ${token.substring(0, 10)}...');
  await box.put(id, token);
  print('Box keys after save: ${box.keys}');
}
```

---

## 🚨 Common Mistakes to Avoid

1. **Forgetting `ConsumerWidget`**
   ```dart
   // ❌ Won't watch Riverpod state
   class MyScreen extends StatelessWidget {}
   
   // ✅ Correct
   class MyScreen extends ConsumerWidget {}
   ```

2. **Using `watch()` in event handlers**
   ```dart
   // ❌ Wrong - watch() is for build method
   onPressed: () {
     ref.watch(authStateProvider);
   }
   
   // ✅ Correct - use read()
   onPressed: () {
     ref.read(authStateProvider.notifier).login(email, pwd);
   }
   ```

3. **Forgetting to await async calls**
   ```dart
   // ❌ Lost in space
   apiService.login(email, pwd);
   
   // ✅ Proper async handling
   await apiService.login(email, pwd);
   ```

4. **Not checking permission levels**
   ```dart
   // ❌ Any user can see admin screens
   if (userRole != 'admin') return;
   
   // ✅ Use GoRouter guards instead
   redirect: (context, state) {
     if (!isAdmin) return '/login';
   }
   ```

5. **Hardcoding values**
   ```dart
   // ❌ Magic numbers everywhere
   SizedBox(height: 24)
   
   // ✅ Use constants
   SizedBox(height: AppConstants.paddingM)
   ```

---

## 📚 Resources

**Official Docs:**
- [Flutter](https://flutter.dev/docs)
- [Riverpod](https://riverpod.dev)
- [GoRouter](https://pub.dev/packages/go_router)
- [Dio](https://pub.dev/packages/dio)

**Tutorials:**
- [State Management in Flutter](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
- [Navigation with GoRouter](https://codewithandrea.com/articles/flutter-go-router/)
- [Interceptors with Dio](https://github.com/flutterchina/dio/wiki/Interceptors)

**Community:**
- [Flutter Discuss](https://discuss.flutter.dev)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [Reddit r/Flutter](https://reddit.com/r/Flutter)

---

## 🎯 Success Criteria for Phase 2

✅ Navigation works between all screens
✅ Role-based routing implemented
✅ Deep linking functional
✅ Token refresh on 401 works
✅ No import errors in analyzer
✅ All screens render without crashes
✅ Can login/logout without data loss

---

## 🎓 Next Learning Goals

1. **GoRouter:** Deep linking patterns, guards, error handling
2. **Error Handling:** Proper exception catching, user feedback
3. **Performance:** Lazy loading lists, caching strategies
4. **Testing:** Unit, widget, and integration tests
5. **Firebase:** FCM notifications, analytics

---

## ❓ Need Help?

1. **Analyzer errors?** → See TROUBLESHOOTING.md
2. **Unsure about architecture?** → See ARCHITECTURE.md
3. **Can't find a file?** → Check IMPLEMENTATION_SUMMARY.md
4. **Import errors persist?** → Run `flutter clean && flutter pub get`

---

**Project:** SantéTogo Healthcare Platform
**Status:** Phase 1 Complete ✅ → Phase 2 In Progress 🔄
**Last Updated:** 2024

Good luck! 🚀
