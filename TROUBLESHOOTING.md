# 🔧 SantéTogo - Troubleshooting Guide

## Common Issues & Solutions

### 1. Import Errors in IDE Analyzer

**Problem:** IDE shows "Target of URI doesn't exist" for imports like `package:sante/...` or external packages

**Solutions (in order):**

1. **Clean and refresh:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Reload Dart analyzer:**
   - VS Code: Open command palette (Ctrl+Shift+P)
   - Type: "Dart: Restart Analysis Server"
   - Press Enter

3. **Invalidate IDE cache:**
   - Close VS Code completely
   - Delete `.dart_tool` folder
   - Reopen VS Code
   - Run `flutter pub get` again

4. **Check pubspec.yaml:**
   ```bash
   # Verify file exists
   ls pubspec.yaml
   
   # Verify package name
   grep "^name:" pubspec.yaml
   # Should output: name: sante
   ```

5. **Nuclear option:**
   ```bash
   rm -rf .dart_tool pubspec.lock
   flutter pub get
   dart analyze
   ```

**Why this happens:**
- IDE caches package indexes
- Package not yet indexed after creation
- Dart pub cache not fully synchronized

---

### 2. Build Fails with "Package Not Found"

**Problem:** `flutter run` fails with "Could not find package X"

**Solution:**
```bash
# Re-download all packages
flutter clean
flutter pub get --verbose

# Check for typos in pubspec.yaml
cat pubspec.yaml | grep dependencies
```

**Check connection:**
```bash
# If behind proxy, configure:
flutter config --enable-web
flutter config --no-analytics
```

---

### 3. QR Code Not Displaying

**Problem:** QR codes show blank or error

**Solutions:**

1. **Verify QrImage implementation:**
   ```dart
   // ✅ Correct (current)
   QrImage(data: qrToken)
   
   // ❌ Incorrect
   QrImage(
     data: qrToken,
     version: QrVersions.auto,  // May not exist
     size: 200,                 // Use Container instead
   )
   ```

2. **Test with simple data:**
   ```dart
   QrImage(data: 'ST-123456')  // Simple string
   ```

3. **Check qr_flutter version:**
   ```bash
   flutter pub deps | grep qr_flutter
   # Current: qr_flutter: ^4.1.0
   ```

4. **Rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

### 4. Login Not Working

**Problem:** Login button doesn't respond or shows errors

**Debugging steps:**

1. **Check API connectivity:**
   ```dart
   // Add to login_screen.dart
   print('API Base URL: ${AppConstants.baseUrl}');
   print('Email: $email');
   ```

2. **Verify backend is running:**
   ```bash
   cd backend
   npm start
   # Should show: Server running on port 3000
   ```

3. **Test API endpoint directly:**
   ```bash
   curl -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@sante.tg","password":"admin123"}'
   ```

4. **Check token storage:**
   ```dart
   // Add debug code
   final token = await apiService.getAccessToken();
   print('Stored token: $token');
   ```

5. **Check SharedPreferences:**
   ```bash
   # Android emulator
   adb shell
   cd /data/data/com.example.sante/shared_prefs
   cat *.xml
   ```

---

### 5. State Not Updating

**Problem:** UI doesn't update after Riverpod state changes

**Solutions:**

1. **Use ConsumerWidget:**
   ```dart
   // ✅ Correct
   class MyWidget extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final state = ref.watch(authStateProvider);
       return state.when(...);
     }
   }
   
   // ❌ Wrong
   class MyWidget extends StatefulWidget {  // Won't watch Riverpod
     ...
   }
   ```

2. **Watch vs Read:**
   ```dart
   // Use watch() for UI updates
   final state = ref.watch(authStateProvider);
   
   // Use read() for one-time values/actions
   ref.read(authStateProvider.notifier).login(...);
   ```

3. **Rebuild listeners:**
   ```dart
   // Add rebuild listener
   ref.listen(authStateProvider, (prev, next) {
     if (next.hasError) {
       ScaffoldMessenger.of(context).showSnackBar(...);
     }
   });
   ```

---

### 6. Storage Issues

**Problem:** Data doesn't persist after app restart

**Solutions:**

1. **Initialize Hive:**
   ```dart
   // main.dart - verify this runs before app start
   await LocalStorageService.init();
   ```

2. **Check Hive boxes:**
   ```dart
   // Add debug code
   final qrBox = await Hive.openBox('patient_qr_box');
   print('QR Box keys: ${qrBox.keys}');
   print('QR Box length: ${qrBox.length}');
   ```

3. **Clear storage (testing):**
   ```dart
   // Add to main.dart temporarily
   await LocalStorageService.clearAll();
   ```

4. **Check permissions (mobile):**
   - Android: Verify storage permissions in AndroidManifest.xml
   - iOS: Verify privacy settings in Info.plist

---

### 7. Responsive Layout Issues

**Problem:** App layout broken on different screen sizes

**Solutions:**

1. **Check MediaQuery:**
   ```dart
   final width = MediaQuery.of(context).size.width;
   final isMobile = width < 600;
   
   if (isMobile) {
     return BottomNavigationBar(...);
   } else {
     return Sidebar(...);
   }
   ```

2. **Test on different devices:**
   ```bash
   flutter run -d chrome  # Web (resize window)
   flutter run -d android # Mobile
   flutter run -d macos   # Desktop
   ```

3. **Add debug display:**
   ```dart
   // Temporary debug
   Text('Width: ${MediaQuery.of(context).size.width}')
   ```

---

### 8. Firebase Not Working

**Problem:** Firebase initialization fails or FCM doesn't work

**Solutions:**

1. **Add Firebase config files:**
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - Web: `web/index.html` includes firebase script

2. **Check Firebase dependencies:**
   ```bash
   flutter pub deps | grep firebase
   # Should list: firebase_core, firebase_messaging
   ```

3. **Initialize in main.dart:**
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     // ... rest of initialization
   }
   ```

4. **Test Firebase:**
   ```dart
   try {
     await Firebase.initializeApp();
     print('Firebase initialized');
   } catch (e) {
     print('Firebase error: $e');
   }
   ```

---

### 9. Hot Reload Issues

**Problem:** Hot reload doesn't work or shows errors

**Solutions:**

1. **Force restart:**
   ```bash
   # In terminal during flutter run
   R - restart
   Q - quit
   ```

2. **Full rebuild:**
   ```bash
   flutter clean
   flutter run
   ```

3. **IDE restart:**
   - Close VS Code completely
   - Reopen and run again

---

### 10. Performance Issues

**Problem:** App runs slow or has jank

**Solutions:**

1. **Check build profile:**
   ```bash
   # Use profile mode (not debug)
   flutter run --profile
   ```

2. **Enable performance monitoring:**
   ```dart
   // main.dart
   if (kDebugMode) {
     // Performance overlay
   }
   ```

3. **Check for unnecessary rebuilds:**
   ```dart
   // Add in build method
   print('Building MyWidget');
   ```

4. **Profile with DevTools:**
   ```bash
   flutter pub global activate devtools
   devtools
   # Open in browser, then run: flutter run --profile
   ```

---

## Platform-Specific Issues

### Android
```bash
# Clear app cache
adb shell pm clear com.example.sante

# View logs
adb logcat | grep flutter

# Grant permissions
adb shell pm grant com.example.sante android.permission.CAMERA
```

### iOS
```bash
# Clean build
rm -rf ios/Pods
rm ios/Podfile.lock
flutter pub get
cd ios && pod install && cd ..

# View logs
log stream --predicate 'eventMessage contains[cd] "flutter"'
```

### Web
```bash
# Clear browser cache
# Chrome: DevTools > Application > Clear site data

# Run with web-renderer
flutter run -d chrome --web-renderer=html
flutter run -d chrome --web-renderer=canvaskit
```

---

## Debugging Commands

```bash
# Verbose output
flutter run -v

# Analyze for errors
dart analyze

# Format code
dart format lib/

# Generate documentation
dart doc

# Check dependencies
flutter pub deps

# Outdated packages
flutter pub outdated

# Security audit
flutter pub audit

# Test coverage
flutter test --coverage
lcov -l coverage/lcov.info
```

---

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "Target of URI doesn't exist" | Analyzer cache issue | `flutter clean && flutter pub get` |
| "No tests found" | Test files in wrong location | Put tests in `test/` folder |
| "Package not found" | pubspec.yaml mismatch | Check `name:` field in pubspec.yaml |
| "The following assertion was thrown" | Runtime error in code | Check stack trace, add error handling |
| "Dart SDK not found" | Flutter not in PATH | Add Flutter to system PATH |
| "The method doesn't override an inherited method" | Wrong class/method signature | Check base class definition |

---

## Getting Help

1. **Check the logs:**
   ```bash
   flutter run -v > build.log 2>&1
   # Review build.log for errors
   ```

2. **Search Stack Overflow:**
   - Tag: `flutter` + `dart`
   - Search error message exactly

3. **Check Flutter issues:**
   - https://github.com/flutter/flutter/issues

4. **Read Flutter docs:**
   - https://flutter.dev/docs

5. **Ask community:**
   - Flutter Discuss: https://discuss.flutter.dev
   - Reddit: r/Flutter

---

## Quick Diagnostic Script

```bash
#!/bin/bash
echo "=== Flutter Doctor ==="
flutter doctor -v

echo "=== Dart Analyze ==="
dart analyze

echo "=== Pub Outdated ==="
flutter pub outdated

echo "=== Project Structure ==="
find lib -type f -name "*.dart" | sort

echo "=== Dependency Tree ==="
flutter pub deps --style=dart

echo "=== Disk Space ==="
du -sh .dart_tool .flutter pubspec.lock
```

Save as `diagnostic.sh` and run:
```bash
chmod +x diagnostic.sh
./diagnostic.sh
```

---

**Still stuck?** Share the output of `flutter run -v` when reporting issues.

Last Updated: 2024
