import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_theme.dart';
import 'models/user.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/clinique/clinic_dashboard_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/pharmacie/pharmacy_dashboard_screen.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();
  // Notification setup is optional and must not block the first screen.
  NotificationService.instance.init();

  runApp(ProviderScope(child: const SanteTogoApp()));
}

class SanteTogoApp extends StatelessWidget {
  const SanteTogoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SantéTogo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).restoreSession();
    });
  }

  Widget _buildDashboardForRole(User user) {
    final role = user.role.toLowerCase();
    final entiteType = (user.entiteType ?? '').toLowerCase();

    if (role == 'patient') {
      return const PatientHomeScreen();
    }

    if (role == 'pharmacien' || entiteType == 'pharmacie') {
      return const PharmacyDashboardScreen();
    }

    if (role == 'admin') {
      return const AdminDashboardScreen();
    }

    if (role == 'medecin' || role == 'secretaire' || entiteType == 'clinique') {
      return const ClinicDashboardScreen();
    }

    return const AdminDashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        return _BiometricGate(
          key: ValueKey(user.id),
          child: _buildDashboardForRole(user),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => const LoginScreen(),
    );
  }
}

class _BiometricGate extends StatefulWidget {
  final Widget child;

  const _BiometricGate({super.key, required this.child});

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> {
  bool _checking = true;
  bool _enabled = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkSessionLock();
  }

  Future<void> _checkSessionLock() async {
    final enabled = await BiometricService.instance.isEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    final unlocked = await BiometricService.instance.authenticate();
    if (!mounted) return;
    setState(() {
      _enabled = true;
      _unlocked = unlocked;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint_rounded, size: 64),
              const SizedBox(height: 16),
              const Text('Déverrouillez SantéTogo'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checkSessionLock,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(_enabled ? 'Réessayer' : 'Déverrouiller'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
