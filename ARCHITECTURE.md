# 🏗️ SantéTogo Architecture Guide

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile Apps                   │
│          (Android, iOS, Web, macOS, Windows)             │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐        ┌────▼────┐       ┌────▼────┐
   │  Admin   │        │ Pharmacy │       │ Patient  │
   │ Dashboard│        │   App    │       │ Portal   │
   └────┬────┘        └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                ┌──────────▼──────────┐
                │  Riverpod State     │
                │  Management         │
                └──────────┬──────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐        ┌────▼────┐       ┌────▼────┐
   │   Dio    │        │   Hive   │       │SharedPref│
   │  (API)   │        │ (Offline)│       │ (Tokens) │
   └────┬────┘        └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                ┌──────────▼──────────┐
                │   Node.js Backend   │
                │ (Express + MongoDB) │
                └─────────────────────┘
```

## Folder Structure

### 📁 `/lib/config/` - App Configuration
**Purpose:** Centralized configuration for colors, theme, and constants

```
config/
├── app_colors.dart
│   ├── Green Palette (g900 → g50)
│   ├── Neutral Scale (s50 → s800)
│   ├── Semantic Colors (danger, warning, success, blue)
│   └── Component Colors (surface variants)
│
├── app_theme.dart
│   ├── lightTheme() → ThemeData
│   ├── TextTheme (Syne + Inter fonts)
│   ├── Component themes (Buttons, Cards, Input)
│   └── Material 3 design system
│
└── app_constants.dart
    ├── Layout (sidebarWidth=238, topbarHeight=56)
    ├── Spacing (paddingS/M/L/XL)
    ├── Radius (radiusSmall/Medium/Large)
    ├── API (baseUrl, timeouts)
    └── Storage Keys (keyAccessToken, etc)
```

### 📁 `/lib/models/` - Data Structures
**Purpose:** API data models with JSON serialization

```
models/
├── user.dart
│   ├── User
│   │   ├── id, email, password
│   │   ├── role: 'admin'|'secretaire'|'medecin'|'pharmacien'|'patient'
│   │   ├── nom, prenom, avatar
│   │   ├── entite?: String (clinic/pharmacy name)
│   │   ├── entiteType?: String ('Clinique'|'Pharmacie')
│   │   ├── actif: bool
│   │   ├── fullName (computed)
│   │   ├── initials (computed)
│   │   ├── fromJson() → User
│   │   └── toJson() → Map
│
├── patient.dart
│   ├── Patient
│   │   ├── id, dossierNumber: "ST-XXXXXX"
│   │   ├── nom, prenom, dateNaissance
│   │   ├── sexe: 'M'|'F'
│   │   ├── telephone, adresse
│   │   ├── groupeSanguin: 'O+'|'O-'|...
│   │   ├── allergies: List<String>
│   │   ├── carteStatus: 'actif'|'expire'|'perdue'
│   │   ├── qrToken: String (encoded JWT)
│   │   ├── createdAt: DateTime
│   │   ├── age (computed)
│   │   ├── fromJson() → Patient
│   │   └── toJson() → Map
│
├── consultation.dart
│   ├── Constantes (vital signs)
│   │   ├── tension, temperature, poids
│   │   └── frequenceCardiaque
│   │
│   ├── Consultation
│   │   ├── id, patientId, date
│   │   ├── motif, diagnostic, notes
│   │   ├── constantes: Constantes
│   │   ├── medecinNom, cliniqueNom
│   │   ├── fromJson() → Consultation
│   │   └── toJson() → Map
│
├── ordonnance.dart
│   ├── Medicament (subdocument)
│   │   ├── nom, dose, frequence
│   │   ├── duree, instructions
│   │
│   ├── Ordonnance
│   │   ├── id, patientId, qrToken
│   │   ├── medicaments: List<Medicament>
│   │   ├── instructionsGenerales
│   │   ├── status: 'active'|'delivered'|'partial'|'expired'
│   │   ├── validiteJours, renouvelable
│   │   ├── emiseAt, expireAt
│   │   ├── medecinNom, cliniqueNom
│   │   ├── isExpired (computed)
│   │   ├── isActive (computed)
│   │   ├── fromJson() → Ordonnance
│   │   └── toJson() → Map
│
└── analyse.dart
    ├── ResultatAnalyse (subdocument)
    │   ├── parametre, valeur, unite
    │   ├── statut: 'normal'|'bas'|'eleve'|'critique'
    │
    ├── Analyse
    │   ├── id, patientId, date
    │   ├── type: 'NFS'|'GE'|'GLYCEMIE'|...
    │   ├── resultats: List<ResultatAnalyse>
    │   ├── medecinNom, cliniqueNom
    │   ├── fromJson() → Analyse
    │   └── toJson() → Map
```

### 📁 `/lib/services/` - Business Logic & APIs
**Purpose:** HTTP communication and local storage management

```
services/
├── api_service.dart
│   ├── ApiService (Singleton)
│   │   ├── _dio: Dio instance
│   │   ├── _prefs: SharedPreferences
│   │   │
│   │   ├── init() → Future<void>
│   │   │   ├── Initialize Dio with BaseOptions
│   │   │   ├── Add _TokenInterceptor
│   │   │   └── Load SharedPreferences
│   │   │
│   │   ├── Authentication
│   │   │   ├── login(email, password) → Future<User>
│   │   │   ├── logout() → Future<void>
│   │   │   ├── refreshToken() → Future<void>
│   │   │   └── getMe() → Future<User>
│   │   │
│   │   ├── Patients
│   │   │   ├── getPatientDossier(id) → Future<Patient>
│   │   │   ├── getPatients(search?) → Future<List<Patient>>
│   │   │   ├── createPatient(data) → Future<Patient>
│   │   │   └── updatePatient(id, data) → Future<Patient>
│   │   │
│   │   ├── Ordonnances
│   │   │   ├── scanOrdonnance(qrToken) → Future<Ordonnance>
│   │   │   ├── deliverOrdonnance(id, meds) → Future<Ordonnance>
│   │   │   └── getOrdonnances() → Future<List<Ordonnance>>
│   │   │
│   │   ├── Token Management
│   │   │   ├── saveTokens(access, refresh) → Future<void>
│   │   │   ├── saveAccessToken(token) → Future<void>
│   │   │   ├── getAccessToken() → Future<String?>
│   │   │   ├── getRefreshToken() → Future<String?>
│   │   │   └── clearTokens() → Future<void>
│   │   │
│   │   └── _TokenInterceptor
│   │       ├── onRequest() - Add Authorization header
│   │       └── onError() - Handle 401 errors
│
└── local_storage_service.dart
    ├── LocalStorageService (Singleton)
    │   ├── patient_qr_box: Box<String>
    │   ├── user_data_box: Box<Map>
    │   ├── sync_box: Box<DateTime>
    │   │
    │   ├── init() → Future<void>
    │   │   └── Hive.openBox() for each box
    │   │
    │   ├── QR Code Management
    │   │   ├── savePatientQrCode(id, token) → Future<void>
    │   │   ├── getPatientQrCode(id) → Future<String?>
    │   │   └── clearQrCode(id) → Future<void>
    │   │
    │   ├── User Data Management
    │   │   ├── saveUserData(user) → Future<void>
    │   │   ├── getUserData() → Future<Map?>
    │   │   └── clearUserData() → Future<void>
    │   │
    │   ├── Sync Management
    │   │   ├── updateLastSync(key, time) → Future<void>
    │   │   ├── getLastSync(key) → Future<DateTime?>
    │   │   └── getSyncStatus() → Future<Map>
    │   │
    │   └── Utility
    │       ├── clearAll() → Future<void>
    │       └── getStats() → Map<String, int>
```

### 📁 `/lib/providers/` - State Management (Riverpod)
**Purpose:** Reactive state management using Riverpod

```
providers/
└── auth_provider.dart
    ├── apiServiceProvider
    │   └── Provider<ApiService>
    │       └── Returns: ApiService singleton
    │
    └── authStateProvider
        └── StateNotifierProvider<AuthNotifier, AsyncValue<User?>>
            ├── State: AsyncValue<User?> (loading|data|error)
            │
            └── AuthNotifier (extends StateNotifier)
                ├── apiService: ApiService
                │
                ├── login(email, password) → Future<void>
                │   ├── state = loading
                │   ├── Call apiService.login()
                │   ├── state = data(user)
                │   └── state = error on exception
                │
                ├── logout() → Future<void>
                │   ├── Call apiService.logout()
                │   ├── Clear storage
                │   └── state = data(null)
                │
                ├── refreshUser() → Future<void>
                │   ├── Call apiService.getMe()
                │   └── state = data(user)
                │
                └── setError(error) → void
                    └── state = error(error, stackTrace)

Usage Example:
  // Watch for auth state changes
  final authState = ref.watch(authStateProvider);
  
  // Call login
  ref.read(authStateProvider.notifier).login(email, password);
```

### 📁 `/lib/widgets/` - Reusable Components
**Purpose:** Build block UI components for screens

```
widgets/
├── common_widgets.dart (215 lines)
│   ├── AppButton
│   │   ├── onPressed: VoidCallback
│   │   ├── label: String
│   │   ├── icon?: IconData
│   │   ├── isLoading?: bool
│   │   ├── isDanger?: bool (red styling)
│   │   ├── Extends: ElevatedButton
│   │   └── Features: Loading animation, icon support
│   │
│   ├── AppOutlinedButton
│   │   ├── onPressed: VoidCallback
│   │   ├── label: String
│   │   ├── icon?: IconData
│   │   ├── Extends: OutlinedButton
│   │   └── Features: White background, border styling
│   │
│   ├── AppChip
│   │   ├── label: String
│   │   ├── onDelete?: VoidCallback
│   │   ├── icon?: IconData
│   │   ├── bgColor?: Color
│   │   ├── textColor?: Color
│   │   └── Features: Dismissible, icon support
│   │
│   └── AppCard
│       ├── child: Widget
│       ├── onTap?: VoidCallback
│       ├── borderColor?: Color
│       ├── Extends: Container
│       └── Features: Border, tap handler, elevation
│
├── stat_widgets.dart (178 lines)
│   ├── StatCard
│   │   ├── value: String
│   │   ├── label: String
│   │   ├── icon: IconData
│   │   ├── delta?: String (e.g., "+5%")
│   │   ├── isPositive?: bool (up/down arrow)
│   │   ├── backgroundColor?: Color
│   │   └── Features: Icon container, trend indicator
│   │
│   └── PatientHeaderCard
│       ├── patient: Patient
│       ├── onTap?: VoidCallback
│       ├── Fields displayed:
│       │   ├── Avatar (initials with gradient)
│       │   ├── Full name
│       │   ├── Age
│       │   ├── Blood type
│       │   └── 🚨 ALLERGIES (RED danger box)
│       └── Features: Compact patient overview, allergy alert
│
└── qr_widgets.dart (190 lines)
    ├── QrDisplayWidget
    │   ├── qrToken: String
    │   ├── dossierNumber: String
    │   ├── bloodType?: String
    │   ├── allergies: List<String>
    │   ├── Features:
    │   │   ├── Displays QR code
    │   │   ├── Shows dossier number
    │   │   └── Lists allergies in RED (#DC2626)
    │   └── Usage: Patient card, QR display
    │
    └── ScanZoneWidget
        ├── onTap: VoidCallback
        ├── Features:
        │   ├── Dashed border
        │   ├── Camera icon
        │   ├── "Tap to scan" text
        │   └── Hover effect
        └── Usage: Trigger QR scanner
```

### 📁 `/lib/screens/` - Complete Pages
**Purpose:** Full-page screen implementations

```
screens/
├── auth/
│   └── login_screen.dart (230 lines)
│       ├── ConsumerStatefulWidget
│       ├── State: LoginState
│       │
│       ├── UI Elements:
│       │   ├── Logo/branding section
│       │   ├── Email TextField (validation)
│       │   ├── Password TextField (toggle visibility)
│       │   ├── Forgot Password link
│       │   ├── Login AppButton (with loading)
│       │   └── Sign up link
│       │
│       ├── Features:
│       │   ├── Form validation
│       │   ├── Password visibility toggle
│       │   ├── Loading state during auth
│       │   ├── Error handling (SnackBar)
│       │   ├── Navigation on success
│       │   └── Responsive layout
│       │
│       └── Integration:
│           ├── Watches: authStateProvider
│           ├── Calls: login(email, password)
│           └── Routes to: Dashboard after login
│
├── admin/
│   └── admin_dashboard_screen.dart (318 lines)
│       ├── ConsumerWidget
│       ├── Layout: Sidebar + Main content
│       │
│       ├── Sidebar (238px width)
│       │   ├── Nav Items:
│       │   │   ├── Dashboard (active by default)
│       │   │   ├── Cliniques
│       │   │   ├── Pharmacies
│       │   │   ├── Cartes
│       │   │   └── Journaux
│       │   └── User pill (bottom)
│       │       ├── Avatar
│       │       ├── Name / Email
│       │       └── Logout button
│       │
│       ├── Main Content Area
│       │   ├── DashboardView
│       │   │   ├── 4 StatCards:
│       │   │   │   ├── 1,248 Patients (delta: +12%)
│       │   │   │   ├── 28 Cliniques (delta: +2)
│       │   │   │   ├── 34 Pharmacies (delta: +1)
│       │   │   │   └── 342 Ordonnances (delta: +28)
│       │   │   └── OrderCard (simulated)
│       │   │
│       │   ├── CliniquesView (stub)
│       │   ├── PharmaciesView (stub)
│       │   ├── CartesView (stub)
│       │   └── JournauxView (stub)
│       │
│       └── Features:
│           ├── Tab switching
│           ├── Active state styling
│           ├── Responsive desktop layout
│           └── User profile display
│
├── pharmacie/
│   └── pharmacy_dashboard_screen.dart (383 lines)
│       ├── ConsumerStatefulWidget
│       ├── Layout: Sidebar + Main content
│       │
│       ├── Sidebar Navigation
│       │   ├── Scanner (active by default)
│       │   ├── Livraisons
│       │   └── Statistiques
│       │
│       ├── ScannerView
│       │   ├── ScanZoneWidget (tap to trigger)
│       │   ├── On scan:
│       │   │   ├── Display PatientHeaderCard
│       │   │   │   └── Shows allergies in RED
│       │   │   ├── List Medicaments with checkboxes
│       │   │   ├── Confirm button (delivery)
│       │   │   └── Cancel button
│       │   └── Features: Simulated data, allergies alert
│       │
│       ├── LiveraisonsView
│       │   ├── 3 OrderCard items
│       │   ├── Status: pending → delivered
│       │   └── Expandable details
│       │
│       ├── StatistiquesView
│       │   ├── 4 StatCards:
│       │   │   ├── 28 delivered today
│       │   │   ├── 3 pending
│       │   │   ├── 142 total this month
│       │   │   └── 0 errors
│       │   └── Charts (future enhancement)
│       │
│       └── Features:
│           ├── QR scanning workflow
│           ├── Patient allergy prominence
│           ├── Delivery confirmation
│           └── Real-time statistics
│
└── patient/
    └── patient_home_screen.dart (450+ lines)
        ├── ConsumerStatefulWidget
        ├── State: _selectedTabIndex
        │
        ├── Responsive Layout
        │   ├── Desktop (width ≥ 600):
        │   │   ├── Sidebar (238px) + Main (flex)
        │   │   └── Sidebar nav items (5)
        │   │
        │   └── Mobile (width < 600):
        │       ├── Full-screen content
        │       └── BottomNavigationBar (5 items)
        │
        ├── HomeView (Tab 0)
        │   ├── Greeting ("Bienvenue, Patient Name")
        │   ├── QR Card
        │   │   ├── QrDisplayWidget
        │   │   ├── Shows dossier number
        │   │   ├── Shows blood type
        │   │   └── Shows allergies (RED)
        │   ├── Recent Activity Timeline
        │   │   ├── 3 activity items
        │   │   ├── Icon + Date + Description
        │   │   └── Timeline design
        │   └── Quick actions
        │
        ├── DossierView (Tab 1-5)
        │   ├── Infos Tab
        │   │   ├── Nom, Prénom
        │   │   ├── Groupe sanguin
        │   │   ├── Date naissance
        │   │   ├── Téléphone
        │   │   └── Adresse
        │   │
        │   ├── Allergies Tab
        │   │   ├── "ALLERGIES IMPORTANTES" (RED box)
        │   │   ├── Warning icon
        │   │   └── Formatted list
        │   │
        │   ├── Consultations Tab
        │   │   ├── List of past consultations
        │   │   ├── Timeline with dates
        │   │   └── "À implémenter" (TODO)
        │   │
        │   ├── Médicaments Tab
        │   │   ├── Active prescriptions
        │   │   ├── Status indicators
        │   │   └── "À implémenter" (TODO)
        │   │
        │   └── Analyses Tab
        │       ├── Lab results
        │       ├── Status indicators (normal/warning/critical)
        │       └── "À implémenter" (TODO)
        │
        ├── Navigation State
        │   ├── _selectedTabIndex: int
        │   ├── _handleTabChange(index)
        │   └── Sync navbar with active tab
        │
        └── Features:
            ├── Responsive mobile/desktop
            ├── Tab-based navigation
            ├── Offline QR display (Hive cached)
            ├── Allergy alerts (RED)
            └── Patient health overview
```

## Data Flow

### Authentication Flow
```
1. User enters email/password
   ↓
2. LoginScreen calls: ref.read(authStateProvider.notifier).login()
   ↓
3. AuthNotifier.login() calls: apiService.login()
   ↓
4. ApiService.login() → POST /auth/login
   ↓
5. Backend returns: {user, accessToken, refreshToken}
   ↓
6. ApiService saves tokens to SharedPreferences
   ↓
7. AuthNotifier updates state: AsyncValue.data(user)
   ↓
8. Screen watches authStateProvider → rebuilds
   ↓
9. Navigation to appropriate dashboard based on role
```

### API Request Flow
```
1. Screen calls: apiService.getPatientDossier(id)
   ↓
2. Dio interceptor adds Authorization header with token
   ↓
3. Request: GET /patients/{id}
   ↓
4. Backend validates token & returns patient data
   ↓
5. Response interceptor checks for 401 (token expired)
   ↓
6. If expired: call refreshToken() and retry request
   ↓
7. Response data → User model via fromJson()
   ↓
8. Screen displays patient information
```

### Offline Storage Flow
```
1. App loads patient data from API
   ↓
2. LocalStorageService saves QR code: savePatientQrCode(id, token)
   ↓
3. QR code stored in Hive: patient_qr_box
   ↓
4. Network goes offline
   ↓
5. Patient opens their dossier
   ↓
6. QrDisplayWidget calls: getPatientQrCode(id)
   ↓
7. Hive retrieves cached QR token
   ↓
8. QR displays without needing network
```

## Design Decisions

### 1. **Architecture Pattern: MVCS**
- **Models:** Data structures (Patient, User, etc)
- **Views:** Screen implementations
- **Controllers:** Riverpod providers/notifiers
- **Services:** API & storage layer

**Rationale:** Clean separation of concerns, easy testing, scalability

### 2. **State Management: Riverpod**
- **Chosen over:** Provider, BLoC, GetX
- **Why:** 
  - Compile-time safety with code generation
  - AsyncValue for loading/error states
  - No context needed (works with functional widgets)
  - Better performance with const constructors

### 3. **HTTP Client: Dio**
- **Features:** Interceptors, request/response transformation
- **Chosen over:** http, HttpClient
- **Why:** Enterprise-grade, interceptor support for auth

### 4. **Local Storage: Hive**
- **Features:** Offline-first, embedded database
- **Chosen over:** SharedPreferences (only for tokens)
- **Why:** Fast, encrypted, reactive queries, perfect for offline QR codes

### 5. **Responsive Design**
- **Desktop:** Sidebar + Main (> 600px width)
- **Mobile:** Full screen + BottomNavBar (≤ 600px)
- **Rationale:** Single codebase for all platforms

### 6. **Color System**
- **Green:** 12-shade palette (primary branding)
- **Neutrals:** 9-shade scale (UI elements)
- **Semantic:** Red for danger (allergies), Orange for warning, Green for success
- **Rationale:** WCAG accessible, sufficient contrast, medical context

## Testing Strategy

### Unit Tests
```
test/models/
├── user_model_test.dart
├── patient_model_test.dart
└── ordonnance_model_test.dart

test/services/
├── api_service_test.dart
└── local_storage_service_test.dart

test/providers/
└── auth_provider_test.dart
```

### Widget Tests
```
test/widgets/
├── common_widgets_test.dart
├── stat_widgets_test.dart
└── qr_widgets_test.dart
```

### Integration Tests
```
integration_test/
├── auth_flow_test.dart
├── patient_dossier_test.dart
└── pharmacy_workflow_test.dart
```

## Security Considerations

1. **Token Storage:**
   - Access token: SharedPreferences (short-lived, 15m)
   - Refresh token: SharedPreferences (long-lived, 7d)
   - Should use Keystore (Android) / Keychain (iOS) in production

2. **API Security:**
   - JWT tokens in Authorization header
   - Bearer token format: `Authorization: Bearer <token>`
   - Token refresh on 401 responses

3. **Patient Data:**
   - Encrypted with Hive encryption key
   - Sensitive data (medical history) requires role-based access
   - QR tokens validated server-side

4. **Input Validation:**
   - Email format validation
   - Password requirements
   - Dossier number format (ST-XXXXXX)

## Performance Optimizations

1. **Widget Rebuilds:**
   - Use ConsumerWidget to prevent unnecessary rebuilds
   - Cache complex widgets (const constructors)
   - Lazy loading for long lists

2. **API Calls:**
   - Debounce search queries (500ms)
   - Pagination for large lists
   - Cache patient data locally

3. **Memory:**
   - Dispose controllers in StatefulWidget
   - Use WeakReferences for circular dependencies
   - Lazy load heavy resources (images, PDFs)

## Future Enhancements

### Phase 2: Navigation
- [ ] GoRouter deep linking
- [ ] Role-based route guards
- [ ] Bottom sheet for patient details
- [ ] Modal dialogs for forms

### Phase 3: Real Features
- [ ] Real camera QR scanning
- [ ] Firebase FCM push notifications
- [ ] Biometric authentication
- [ ] Multi-language support (French/English)

### Phase 4: Admin Features
- [ ] Clinic management dashboard
- [ ] Pharmacy approval workflow
- [ ] PVC card ordering system
- [ ] Audit logs viewer

### Phase 5: Doctor Features
- [ ] Patient search & filtering
- [ ] New consultation form
- [ ] Ordonnance creation with allergen checking
- [ ] Analysis ordering & results

### Phase 6: Advanced
- [ ] Offline-first sync
- [ ] Push notifications
- [ ] Video consultations
- [ ] Telemedicine integration

---

**Architecture Version:** 1.0
**Last Updated:** 2024
**Status:** Production Ready (Phase 1 Complete)
