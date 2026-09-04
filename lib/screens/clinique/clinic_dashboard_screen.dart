import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sante/config/app_colors.dart';
import 'package:sante/providers/auth_provider.dart';
import 'package:sante/widgets/sante_shell.dart';

class ClinicDashboardScreen extends ConsumerStatefulWidget {
  const ClinicDashboardScreen({super.key});

  @override
  ConsumerState<ClinicDashboardScreen> createState() =>
      _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends ConsumerState<ClinicDashboardScreen> {
  int _selectedTabIndex = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _ordonnances = [];
  Map<String, dynamic>? _selectedDossier;
  String _searchQuery = '';
  String _patientFilter = 'Tous';
  String? _selectedPatientId;
  bool _showNewOrdonnance = false;
  int _dossierTabIndex = 2;
  final TextEditingController _consultationMotifController =
      TextEditingController();
  final TextEditingController _consultationDiagnosticController =
      TextEditingController();
  final TextEditingController _consultationNotesController =
      TextEditingController();
  final TextEditingController _rxInstructionsController =
      TextEditingController();
  final GlobalKey<FormState> _settingsFormKey = GlobalKey<FormState>();
  final TextEditingController _settingsUserNomController =
      TextEditingController();
  final TextEditingController _settingsUserPrenomController =
      TextEditingController();
  final TextEditingController _settingsNameController = TextEditingController();
  final TextEditingController _settingsAddressController =
      TextEditingController();
  final TextEditingController _settingsCityController = TextEditingController();
  final TextEditingController _settingsPhoneController =
      TextEditingController();
  final TextEditingController _settingsEmailController =
      TextEditingController();
  final TextEditingController _settingsResponsibleController =
      TextEditingController();
  final TextEditingController _settingsAuthorizationController =
      TextEditingController();
  final TextEditingController _settingsAuthorizationDateController =
      TextEditingController();
  final List<Map<String, String>> _prescriptionMeds = [];
  Map<String, dynamic> _profile = {};
  String _rxValidity = '7 jours';
  String _rxRenewal = 'Non renouvelable';
  String _settingsClinicType = 'clinique_privee';
  bool _settingsReady = false;
  bool _savingSettings = false;

  static const List<String> _filterOptions = [
    'Tous',
    'Suivi',
    'Urgence',
    'À revoir',
  ];

  String _displayNameFromPatient(Map<String, dynamic> patient) {
    final direct = patient['fullName']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return [
      patient['prenom'] ?? '',
      patient['nom'] ?? '',
    ].where((part) => part.toString().trim().isNotEmpty).join(' ').trim();
  }

  Map<String, dynamic> _normalizePatient(
    Map<String, dynamic> patient, {
    int index = 0,
  }) {
    final fullName = _displayNameFromPatient(patient);
    final statusValue = patient['carteStatus'] ?? 'pending';
    return {
      ...patient,
      'id': (patient['_id'] ?? patient['id'] ?? '').toString(),
      'dossierNumber': patient['dossierNumber'] ?? '',
      'fullName': fullName.isNotEmpty ? fullName : 'Patient',
      'groupeSanguin': patient['groupeSanguin'] ?? '—',
      'telephone': patient['telephone'] ?? '—',
      'carteStatus': statusValue,
      'filterTag': statusValue == 'pending' ? 'À revoir' : 'Suivi',
      'rowIndex': index,
    };
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _dateLabel(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _ageLabel(dynamic value) {
    final birthDate = _parseDate(value);
    if (birthDate == null) return 'Âge non renseigné';
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years >= 0 ? '$years ans' : 'Âge non renseigné';
  }

  String _sexLabel(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'F':
      case 'FEMININ':
      case 'FÉMININ':
        return 'Féminin';
      case 'M':
      case 'MASCULIN':
        return 'Masculin';
      default:
        return 'Sexe non renseigné';
    }
  }

  String _timeLabel(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '—';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatOrdonnanceStatus(String? status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'delivered':
        return 'Délivrée';
      case 'partial':
        return 'Partielle';
      case 'expired':
        return 'Expirée';
      default:
        return 'Inconnue';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _consultationMotifController.dispose();
    _consultationDiagnosticController.dispose();
    _consultationNotesController.dispose();
    _rxInstructionsController.dispose();
    _settingsUserNomController.dispose();
    _settingsUserPrenomController.dispose();
    _settingsNameController.dispose();
    _settingsAddressController.dispose();
    _settingsCityController.dispose();
    _settingsPhoneController.dispose();
    _settingsEmailController.dispose();
    _settingsResponsibleController.dispose();
    _settingsAuthorizationController.dispose();
    _settingsAuthorizationDateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiServiceProvider);
      final patientResults = await api.getPatients();
      final consultationResults = await api.getClinicConsultations();
      final ordonnanceResults = await api.getClinicOrdonnances();
      final profile = await api.getMyProfile();

      final patientRows = patientResults
          .asMap()
          .entries
          .map((entry) => _normalizePatient(entry.value, index: entry.key))
          .toList();

      final consultations = consultationResults.map((entry) {
        final patient = entry['patient'] is Map
            ? Map<String, dynamic>.from(entry['patient'])
            : <String, dynamic>{};
        return {
          'id': (entry['_id'] ?? entry['id'] ?? '').toString(),
          'patientId':
              (patient['_id'] ?? patient['id'] ?? entry['patient'] ?? '')
                  .toString(),
          'type': entry['motif']?.toString() ?? 'Consultation',
          'patient': _displayNameFromPatient(patient),
          'hour': _timeLabel(entry['date'] ?? entry['createdAt']),
          'date': _dateLabel(entry['date'] ?? entry['createdAt']),
          'state': entry['diagnostic']?.toString().isNotEmpty == true
              ? 'Validée'
              : 'À compléter',
          'diagnostic': entry['diagnostic'] ?? '',
          'notes': entry['notes'] ?? '',
          'raw': entry,
        };
      }).toList();

      final ordonnances = ordonnanceResults.map((entry) {
        final patient = entry['patient'] is Map
            ? Map<String, dynamic>.from(entry['patient'])
            : <String, dynamic>{};
        final meds = (entry['medicaments'] as List? ?? const [])
            .map(
              (item) => item is Map
                  ? item['nom']?.toString() ?? 'Médicament'
                  : item.toString(),
            )
            .join(', ');
        return {
          'id': (entry['_id'] ?? entry['id'] ?? '').toString(),
          'patientId':
              (patient['_id'] ?? patient['id'] ?? entry['patient'] ?? '')
                  .toString(),
          'patient': _displayNameFromPatient(patient),
          'date': _dateLabel(entry['emiseAt'] ?? entry['createdAt']),
          'state': _formatOrdonnanceStatus(entry['status']?.toString()),
          'medicaments': meds.isEmpty ? 'Aucun médicament' : meds,
          'raw': entry,
        };
      }).toList();

      setState(() {
        _patients = patientRows;
        _consultations = consultations;
        _appointments = <Map<String, dynamic>>[];
        _ordonnances = ordonnances;
        _profile = profile;
        _settingsReady = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showActionMessage(
        'Chargement clinique impossible : ${e.toString().replaceFirst('Exception: ', '')}',
      );
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    final query = _searchQuery.trim().toLowerCase();
    return _patients.where((patient) {
      final matchesQuery =
          query.isEmpty ||
          (patient['fullName'] as String).toLowerCase().contains(query) ||
          (patient['dossierNumber'] as String).toLowerCase().contains(query);

      final matchesFilter =
          _patientFilter == 'Tous' ||
          (patient['filterTag'] as String) == _patientFilter ||
          (_patientFilter == 'Urgence' &&
              (patient['groupeSanguin'] as String) == 'A+');

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final userName = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName
        : 'Clinique Santé';

    final roleLabel = switch (currentUser?.role.toLowerCase()) {
      'medecin' => 'Médecin',
      'secretaire' => 'Secrétaire',
      'admin' => 'Administrateur',
      _ => 'Clinique',
    };

    final navItems = [
      SanteDashboardNavItem(
        icon: Icons.dashboard_rounded,
        label: 'Accueil',
        selected: _selectedTabIndex == 0,
        onTap: () => setState(() => _selectedTabIndex = 0),
      ),
      SanteDashboardNavItem(
        icon: Icons.people_alt_rounded,
        label: 'Patients',
        selected: _selectedTabIndex == 1,
        onTap: () => setState(() => _selectedTabIndex = 1),
      ),
      SanteDashboardNavItem(
        icon: Icons.medical_services_rounded,
        label: 'Consultations',
        selected: _selectedTabIndex == 2,
        onTap: () => setState(() => _selectedTabIndex = 2),
      ),
      SanteDashboardNavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Ordonnances',
        selected: _selectedTabIndex == 3,
        onTap: () => setState(() => _selectedTabIndex = 3),
      ),
      SanteDashboardNavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Rendez-vous',
        selected: _selectedTabIndex == 4,
        onTap: () => setState(() => _selectedTabIndex = 4),
      ),
      SanteDashboardNavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Rapports',
        selected: _selectedTabIndex == 5,
        onTap: () => setState(() => _selectedTabIndex = 5),
      ),
      SanteDashboardNavItem(
        icon: Icons.settings_rounded,
        label: 'Paramètres',
        selected: _selectedTabIndex == 6,
        onTap: () => setState(() => _selectedTabIndex = 6),
      ),
    ];

    return SanteDashboardShell(
      title: 'Espace clinique',
      subtitle: 'Suivi des patients, consultations, ordonnances et rapports',
      userName: userName,
      userRole: roleLabel,
      navItems: navItems,
      headerAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.health_and_safety_rounded,
              size: 14,
              color: AppColors.g700,
            ),
            const SizedBox(width: 6),
            Text(
              'Service actif',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.g700,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedPatientId != null && !_showNewOrdonnance) {
      return _patientDetailView();
    }

    if (_selectedPatientId != null && _showNewOrdonnance) {
      return _newOrdonnanceView();
    }

    switch (_selectedTabIndex) {
      case 1:
        return _patientsView();
      case 2:
        return _consultationsView();
      case 3:
        return _ordonnancesView();
      case 4:
        return _appointmentsView();
      case 5:
        return _reportsView();
      case 6:
        return _settingsView();
      case 0:
      default:
        return _overviewView();
    }
  }

  Map<String, dynamic>? get _selectedPatient {
    final dossierPatient = _selectedDossier?['patient'];
    if (dossierPatient is Map) {
      return _normalizePatient(Map<String, dynamic>.from(dossierPatient));
    }
    if (_selectedPatientId == null) return null;
    for (final patient in _patients) {
      if (patient['id']?.toString() == _selectedPatientId) {
        return patient;
      }
    }
    return null;
  }

  Future<void> _openPatientById(String patientId, {int dossierTab = 0}) async {
    if (patientId.isEmpty) {
      _showActionMessage('Patient introuvable.');
      return;
    }

    try {
      final dossier = await ref
          .read(apiServiceProvider)
          .getPatientDossier(patientId);
      if (!mounted) return;
      setState(() {
        _selectedPatientId = patientId;
        _selectedDossier = dossier;
        _showNewOrdonnance = false;
        _dossierTabIndex = dossierTab;
      });
    } catch (e) {
      if (!mounted) return;
      _showActionMessage(
        'Ouverture dossier impossible : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _showActionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _resetOrdonnanceForm() {
    _consultationMotifController.clear();
    _consultationDiagnosticController.clear();
    _consultationNotesController.clear();
    _rxInstructionsController.clear();
    _prescriptionMeds.clear();
    _rxValidity = '7 jours';
    _rxRenewal = 'Non renouvelable';
  }

  bool _isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 720;

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  String _scanLabel(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return value;
    final uri = Uri.tryParse(value);
    if (uri != null) {
      final dossier =
          uri.queryParameters['dossierNumber'] ??
          uri.queryParameters['dossier'] ??
          uri.queryParameters['numero'];
      if (dossier != null && dossier.trim().isNotEmpty) return dossier.trim();
    }
    return value;
  }

  Future<void> _openPatientFromScanValue(String rawValue) async {
    final value = _scanLabel(rawValue);
    if (value.isEmpty) return;

    try {
      final api = ref.read(apiServiceProvider);
      final patient = value.toUpperCase().startsWith('ST-')
          ? await api.getPatientByDossierNumber(value)
          : await api.getPatientByQrToken(value);
      if (!mounted) return;
      final normalized = _normalizePatient(patient);
      if (_patients.every((row) => row['id'] != normalized['id'])) {
        setState(() => _patients.insert(0, normalized));
      }
      await _openPatientById(normalized['id']?.toString() ?? '', dossierTab: 0);
      _showActionMessage('Dossier ${patient['dossierNumber']} ouvert.');
    } catch (e) {
      if (!mounted) return;
      _showActionMessage(
        'Patient introuvable : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _openCameraCardScanner() async {
    var captured = false;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scanner la carte patient'),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              onDetect: (capture) {
                if (captured) return;
                final code = capture.barcodes
                    .map((barcode) => barcode.rawValue?.trim() ?? '')
                    .firstWhere((value) => value.isNotEmpty, orElse: () => '');
                if (code.isEmpty) return;
                captured = true;
                Navigator.of(dialogContext).pop(code);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (value != null && value.trim().isNotEmpty) {
      await _openPatientFromScanValue(value);
    }
  }

  void _prepareSettingsForm() {
    if (_settingsReady) return;
    final currentUser = ref.read(authStateProvider).valueOrNull;
    final entite = _profile['entite'] is Map
        ? Map<String, dynamic>.from(_profile['entite'])
        : <String, dynamic>{};

    _settingsUserNomController.text = currentUser?.nom ?? '';
    _settingsUserPrenomController.text = currentUser?.prenom ?? '';
    _settingsNameController.text = entite['nom']?.toString() ?? '';
    _settingsAddressController.text = entite['adresse']?.toString() ?? '';
    _settingsCityController.text = entite['ville']?.toString() ?? '';
    _settingsPhoneController.text = entite['telephone']?.toString() ?? '';
    _settingsEmailController.text =
        entite['email']?.toString() ?? currentUser?.email ?? '';
    _settingsResponsibleController.text =
        entite['responsable']?.toString() ?? '';
    _settingsAuthorizationController.text =
        entite['numeroAutorisation']?.toString() ?? '';
    _settingsAuthorizationDateController.text =
        (entite['dateAutorisation'] ?? '').toString().split('T').first;
    final type = entite['type']?.toString();
    if (type == 'clinique_privee' ||
        type == 'hopital' ||
        type == 'centre_sante') {
      _settingsClinicType = type!;
    }
    _settingsReady = true;
  }

  Future<void> _saveSettings() async {
    if (!(_settingsFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingSettings = true);
    try {
      final currentUser = ref.read(authStateProvider).valueOrNull;
      final payload = {
        'nom': _settingsUserNomController.text.trim(),
        'prenom': _settingsUserPrenomController.text.trim(),
        'entite': {
          'nom': _settingsNameController.text.trim(),
          'adresse': _settingsAddressController.text.trim(),
          'ville': _settingsCityController.text.trim(),
          'telephone': _settingsPhoneController.text.trim(),
          'email': _settingsEmailController.text.trim(),
          'responsable': _settingsResponsibleController.text.trim(),
          'dateAutorisation': _settingsAuthorizationDateController.text.trim(),
          if (currentUser?.entiteType == 'clinique')
            'type': _settingsClinicType,
        },
      };
      final profile = await ref
          .read(apiServiceProvider)
          .updateMyProfile(payload);
      await ref.read(authStateProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _settingsReady = false;
        _savingSettings = false;
      });
      _showActionMessage('Paramètres enregistrés.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingSettings = false);
      _showActionMessage(
        'Enregistrement impossible : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _openAddMedicineDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un médicament'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Médicament'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Médicament requis'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: doseController,
                  decoration: const InputDecoration(labelText: 'Dose'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Dose requise'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: frequencyController,
                  decoration: const InputDecoration(labelText: 'Fréquence'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Fréquence requise'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: durationController,
                  decoration: const InputDecoration(labelText: 'Durée'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Durée requise'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'dose': doseController.text.trim(),
                  'interval': frequencyController.text.trim(),
                  'duration': durationController.text.trim(),
                });
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    nameController.dispose();
    doseController.dispose();
    frequencyController.dispose();
    durationController.dispose();

    if (result == null) return;
    setState(() => _prescriptionMeds.add(result));
  }

  Future<void> _emitOrdonnance() async {
    final patient = _selectedPatient;
    final patientId = patient?['id']?.toString();
    if (patientId == null || patientId.isEmpty) {
      _showActionMessage('Patient introuvable pour cette ordonnance.');
      return;
    }

    if (_consultationMotifController.text.trim().isEmpty ||
        _consultationDiagnosticController.text.trim().isEmpty ||
        _prescriptionMeds.isEmpty) {
      _showActionMessage(
        'Motif, diagnostic et au moins un médicament sont requis.',
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final consultationResult = await api.createConsultation({
        'patientId': patientId,
        'motif': _consultationMotifController.text.trim(),
        'diagnostic': _consultationDiagnosticController.text.trim(),
        'notes': _consultationNotesController.text.trim(),
        'constantes': {},
      });
      final consultation = Map<String, dynamic>.from(
        consultationResult['consultation'] ?? {},
      );
      final consultationId = (consultation['_id'] ?? consultation['id'])
          ?.toString();
      if (consultationId == null || consultationId.isEmpty) {
        throw Exception('Consultation créée sans identifiant.');
      }

      final validityDays = int.tryParse(_rxValidity.split(' ').first) ?? 7;
      await api.createOrdonnance({
        'patientId': patientId,
        'consultationId': consultationId,
        'medicaments': _prescriptionMeds.map((med) {
          return {
            'nom': med['name'],
            'dose': med['dose'],
            'frequence': med['interval'],
            'duree': med['duration'],
            'instructions': '',
          };
        }).toList(),
        'instructionsGenerales': _rxInstructionsController.text.trim(),
        'validiteJours': validityDays,
        'renouvelable': _rxRenewal != 'Non renouvelable',
      });

      if (!mounted) return;
      _resetOrdonnanceForm();
      setState(() {
        _showNewOrdonnance = false;
        _selectedPatientId = null;
        _selectedDossier = null;
        _selectedTabIndex = 3;
      });
      await _loadData();
      _showActionMessage(
        'Ordonnance émise. QR sécurisé généré et dossier patient mis à jour.',
      );
    } catch (e) {
      if (!mounted) return;
      _showActionMessage(
        'Émission impossible : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _openScanCardDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanner / retrouver un patient'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('__camera__'),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Scanner avec la caméra'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ou',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.g500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Numéro de dossier ou jeton QR',
                  hintText: 'ST-XXXXXX',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty) return;
    if (value == '__camera__') {
      await _openCameraCardScanner();
      return;
    }
    await _openPatientFromScanValue(value);
  }

  Future<void> _openNewPatientDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final telephoneController = TextEditingController();
    final adresseController = TextEditingController();
    final groupeController = TextEditingController(text: 'A+');
    final allergiesController = TextEditingController();
    final dateController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau patient'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomController,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nom requis'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: prenomController,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Prénom requis'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance (AAAA-MM-JJ)',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Date requise'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: telephoneController,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Téléphone requis'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: adresseController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Adresse requise'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: groupeController,
                    decoration: const InputDecoration(
                      labelText: 'Groupe sanguin',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Groupe requis'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergies (facultatif)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'nom': nomController.text.trim(),
        'prenom': prenomController.text.trim(),
        'dateNaissance': dateController.text.trim(),
        'sexe': 'F',
        'telephone': telephoneController.text.trim(),
        'adresse': adresseController.text.trim(),
        'groupeSanguin': groupeController.text.trim(),
        'allergies': allergiesController.text.trim().isEmpty
            ? []
            : allergiesController.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(),
      };
      final created = await api.createPatient(data);
      if (!mounted) return;
      await _loadData();
      await _openPatientById(
        (created['_id'] ?? created['id'] ?? '').toString(),
        dossierTab: 0,
      );
      _showActionMessage(
        'Patient créé avec succès. QR patient généré côté serveur.',
      );
    } catch (e) {
      if (!mounted) return;
      _showActionMessage(
        'Création impossible : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Widget _overviewView() {
    final waitingPatients = _patients.take(4).toList();
    final waitingList = waitingPatients.isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            for (var i = 0; i < waitingPatients.length; i++)
              {
                'dossierNumber': waitingPatients[i]['dossierNumber'] ?? '',
                'name': waitingPatients[i]['fullName'] ?? 'Patient ${i + 1}',
                'motif': 'Dossier enregistré',
                'status': waitingPatients[i]['carteStatus'] == 'delivered'
                    ? 'Actif'
                    : 'À compléter',
              },
          ];

    final pendingCount = _patients.where((patient) {
      final status = (patient['carteStatus'] ?? '').toString();
      return status == 'pending' || status == 'review';
    }).length;

    final consultationCount = _consultations.length;
    final ordonnanceCount = _ordonnances.length;
    final totalPatients = _patients.length;

    final stats = [
      {
        'icon': Icons.access_time_rounded,
        'value': '$pendingCount',
        'label': 'En attente',
        'tint': AppColors.g100,
      },
      {
        'icon': Icons.medical_services_rounded,
        'value': '$consultationCount',
        'label': 'En consultation',
        'tint': AppColors.g50,
      },
      {
        'icon': Icons.people_alt_rounded,
        'value': '$totalPatients',
        'label': 'Patients du jour',
        'tint': AppColors.g50,
      },
      {
        'icon': Icons.receipt_long_rounded,
        'value': '$ordonnanceCount',
        'label': 'Ordonnances émises',
        'tint': AppColors.g50,
      },
    ];

    final activityRows = [
      {'label': 'Nouveaux patients', 'value': '$totalPatients'},
      {'label': 'Patients à revoir', 'value': '$pendingCount'},
      {'label': 'Consultations', 'value': '$consultationCount'},
      {'label': 'Ordonnances émises', 'value': '$ordonnanceCount'},
      {
        'label': 'Cartes validées',
        'value':
            '${_patients.where((patient) => (patient['carteStatus'] ?? '').toString() == 'delivered').length}',
      },
    ];

    final doctors = [
      {
        'name': 'Equipe clinique',
        'specialty': 'Suivi général',
        'patients': '$totalPatients dossiers',
        'active': true,
        'color': AppColors.g700,
      },
      {
        'name': 'Service de consultation',
        'specialty': 'Contrôle et urgence',
        'patients': '$pendingCount à revoir',
        'active': true,
        'color': AppColors.g500,
      },
    ];

    final compact = _isCompact(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 320,
                child: Text(
                  'Accueil du jour',
                  style: GoogleFonts.syne(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: _openScanCardDialog,
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text('Scanner carte'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.g700,
                        side: const BorderSide(color: AppColors.s200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: _openNewPatientDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Nouveau patient'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 520
                  ? 2
                  : constraints.maxWidth < 900
                  ? 2
                  : 4;
              final tileWidth =
                  (constraints.maxWidth - (12 * (columns - 1))) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final stat in stats)
                    SizedBox(
                      width: tileWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.s100),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: stat['tint'] as Color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                stat['icon'] as IconData,
                                size: 18,
                                color: AppColors.g700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              stat['value'] as String,
                              style: GoogleFonts.syne(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat['label'] as String,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.g600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: compact ? 760 : constraints.maxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.s100),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fiche d\'attente',
                                    style: GoogleFonts.syne(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.g800,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => _showActionMessage(
                                      'Ajout d’un patient depuis le gestionnaire de dossiers.',
                                    ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Ajouter'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.g700,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.g50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '#',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.g700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'PATIENT',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.g700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'MOTIF',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.g700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'STATUT',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.g700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...List.generate(waitingList.length, (index) {
                                final item = waitingList[index];
                                final status = item['status'] as String;
                                final badgeColor = status == 'Consultation'
                                    ? AppColors.g100
                                    : AppColors.warningBg;
                                final badgeTextColor = status == 'Consultation'
                                    ? AppColors.g700
                                    : AppColors.warning;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: index < waitingList.length - 1
                                            ? AppColors.s100
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.g700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] as String,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.g800,
                                              ),
                                            ),
                                            Text(
                                              (item['dossierNumber'] ?? '')
                                                  .toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.g500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item['motif'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.g700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: badgeTextColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: AppColors.s100),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTIVITÉ DU JOUR',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.g700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...activityRows.map(
                                    (row) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            row['label'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.g700,
                                            ),
                                          ),
                                          Text(
                                            row['value'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.g800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: AppColors.s100),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MÉDECINS ACTIFS',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.g700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...doctors.map(
                                    (doctor) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: doctor['color'] as Color,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Center(
                                              child: Text(
                                                (doctor['name'] as String)
                                                    .split(' ')
                                                    .map((part) => part[0])
                                                    .take(2)
                                                    .join(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  doctor['name'] as String,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.g800,
                                                  ),
                                                ),
                                                Text(
                                                  '${doctor['specialty']} · ${doctor['patients']}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: AppColors.g600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.g50,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Actif',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.g700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _patientDetailView() {
    final patient = _selectedPatient;
    if (patient == null) {
      return const Center(child: Text('Aucun dossier patient sélectionné.'));
    }
    final fullName = (patient['fullName'] ?? 'Patient').toString();
    final dossierNumber = (patient['dossierNumber'] ?? '—').toString();
    final group = (patient['groupeSanguin'] ?? '—').toString();
    final phone = (patient['telephone'] ?? '—').toString();
    final allergiesList = (patient['allergies'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final allergies = allergiesList.isEmpty
        ? 'Allergies connues : aucune'
        : 'Allergies connues : ${allergiesList.join(' · ')}';
    final tabs = [
      'Antécédents',
      'Consultations',
      'Médicaments',
      'Ordonnances',
      'Analyses',
      'Pharmacie',
    ];
    final compact = _isCompact(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 260,
                child: Text(
                  'Dossier patient',
                  style: GoogleFonts.syne(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Imprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.g700,
                        side: const BorderSide(color: AppColors.s200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _showNewOrdonnance = true;
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nouvelle ordonnance'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.g700,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              _initialsFor(fullName),
                              style: GoogleFonts.syne(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth - 84 : 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.syne(
                                  fontSize: compact ? 22 : 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.s800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _InfoPill(
                                    label: _ageLabel(patient['dateNaissance']),
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                  _InfoPill(
                                    label: _sexLabel(patient['sexe']),
                                    icon: Icons.person_rounded,
                                  ),
                                  _InfoPill(
                                    label: 'Groupe $group',
                                    icon: Icons.favorite_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Dossier actif',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE9E7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEEB2B2)),
                      ),
                      child: Text(
                        allergies,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Text(
                          'N° dossier $dossierNumber',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.g600,
                          ),
                        ),
                        Text(
                          phone,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.g700,
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final qrCard = Container(
                  width: compact ? double.infinity : 180,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.g50,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.s100),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 52,
                            color: AppColors.g700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dossierNumber,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.g800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Carte permanente',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.g600,
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 18), qrCard],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 18),
                    qrCard,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.s100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final selected = index == _dossierTabIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _dossierTabIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected
                                    ? AppColors.g700
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              tabs[index],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.g700
                                    : AppColors.g600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: _patientDossierTabContent(_dossierTabIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientDossierTabContent(int tabIndex) {
    final selectedPatient = _selectedPatient;
    if (selectedPatient == null) {
      return const Text('Aucun dossier patient sélectionné.');
    }
    final allergiesList = (selectedPatient['allergies'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final allergiesText = allergiesList.isEmpty
        ? 'Aucune allergie connue'
        : allergiesList.join(', ');
    final dossier = _selectedDossier ?? <String, dynamic>{};
    final consultations = List<Map<String, dynamic>>.from(
      dossier['consultations'] ?? const [],
    );
    final ordonnances = List<Map<String, dynamic>>.from(
      dossier['ordonnances'] ?? const [],
    );
    final analyses = List<Map<String, dynamic>>.from(
      dossier['analyses'] ?? const [],
    );
    final delivrances = List<Map<String, dynamic>>.from(
      dossier['delivrances'] ?? const [],
    );
    final medicines = <Map<String, dynamic>>[];
    for (final ordonnance in ordonnances) {
      for (final med in (ordonnance['medicaments'] as List? ?? const [])) {
        if (med is Map) medicines.add(Map<String, dynamic>.from(med));
      }
    }

    switch (tabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Antécédents'),
            const SizedBox(height: 12),
            _DossierHistoryRow(label: 'Allergies', value: allergiesText),
            _DossierHistoryRow(
              label: 'Groupe sanguin',
              value: selectedPatient['groupeSanguin']?.toString() ?? '—',
            ),
            _DossierHistoryRow(
              label: 'Téléphone',
              value: selectedPatient['telephone']?.toString() ?? '—',
            ),
            _DossierHistoryRow(
              label: 'Adresse',
              value: selectedPatient['adresse']?.toString() ?? '—',
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Consultations'),
            const SizedBox(height: 12),
            if (consultations.isEmpty)
              _DossierHistoryRow(
                label: 'Aucune',
                value:
                    'Aucune consultation récente n’a été ajoutée à ce dossier.',
              )
            else
              ...consultations.map(
                (entry) => _DossierHistoryRow(
                  label: _dateLabel(entry['date'] ?? entry['createdAt']),
                  value:
                      '${entry['motif'] ?? 'Consultation'} · ${entry['diagnostic'] ?? 'Diagnostic non renseigné'}',
                ),
              ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Médicaments'),
            const SizedBox(height: 12),
            if (medicines.isEmpty)
              _DossierHistoryRow(
                label: 'Aucune',
                value: 'Aucun médicament prescrit dans ce dossier.',
              )
            else
              ...medicines.map(
                (med) => _DossierHistoryRow(
                  label: med['nom']?.toString() ?? 'Médicament',
                  value: [med['dose'], med['frequence'], med['duree']]
                      .where(
                        (part) =>
                            part != null && part.toString().trim().isNotEmpty,
                      )
                      .join(' · '),
                ),
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Ordonnances'),
            const SizedBox(height: 12),
            if (ordonnances.isEmpty)
              _DossierHistoryRow(
                label: 'Aucune',
                value: 'Aucune ordonnance récente enregistrée pour ce dossier.',
              )
            else
              ...ordonnances.map(
                (entry) => _DossierHistoryRow(
                  label: _dateLabel(entry['emiseAt'] ?? entry['createdAt']),
                  value:
                      '${_formatOrdonnanceStatus(entry['status']?.toString())} · ${(entry['medicaments'] as List? ?? const []).length} médicament(s)',
                ),
              ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Analyses'),
            const SizedBox(height: 12),
            if (analyses.isEmpty)
              _DossierHistoryRow(
                label: 'Aucune',
                value: 'Aucune analyse récente n’a été ajoutée à ce dossier.',
              )
            else
              ...analyses.expand((entry) {
                final resultats = entry['resultats'] as List? ?? const [];
                if (resultats.isEmpty) {
                  return [
                    _DossierHistoryRow(
                      label: entry['type']?.toString() ?? 'Analyse',
                      value: 'Résultat non renseigné',
                    ),
                  ];
                }
                return resultats.map(
                  (result) => _DossierHistoryRow(
                    label:
                        '${entry['type'] ?? 'Analyse'} · ${result['parametre'] ?? ''}',
                    value:
                        '${result['valeur'] ?? '—'} ${result['unite'] ?? ''} · ${result['statut'] ?? 'normal'}'
                            .trim(),
                  ),
                );
              }),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DossierSectionTitle(title: 'Passages pharmacie'),
            const SizedBox(height: 12),
            if (delivrances.isEmpty)
              _DossierHistoryRow(
                label: 'Aucune',
                value: 'Aucune délivrance enregistrée pour ce dossier.',
              )
            else
              ...delivrances.map((entry) {
                final pharmacy = entry['pharmacie'] is Map
                    ? (entry['pharmacie']['nom'] ?? 'Pharmacie').toString()
                    : (entry['pharmacie'] ?? 'Pharmacie').toString();
                final delivered =
                    entry['medicamentsDelivres'] as List? ?? const [];
                return _DossierHistoryRow(
                  label: _dateLabel(entry['date'] ?? entry['createdAt']),
                  value:
                      '$pharmacy · ${entry['status'] ?? 'delivered'} · ${delivered.length} médicament(s)',
                );
              }),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _newOrdonnanceView() {
    final patient = _selectedPatient;
    if (patient == null) {
      return const Center(child: Text('Aucun dossier patient sélectionné.'));
    }
    final fullName = (patient['fullName'] ?? 'Patient').toString();
    final group = (patient['groupeSanguin'] ?? '—').toString();
    final allergiesList = (patient['allergies'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final allergyText = allergiesList.isEmpty
        ? 'Aucune allergie connue'
        : allergiesList.join(' · ');
    final previewMeds = _prescriptionMeds;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final contentWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      320.0,
      double.infinity,
    ).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? contentWidth : null,
                child: Text(
                  'Nouvelle ordonnance',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact ? (contentWidth - 10) / 2 : null,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showNewOrdonnance = false;
                          _selectedPatientId = null;
                          _resetOrdonnanceForm();
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Retour'),
                    ),
                  ),
                  SizedBox(
                    width: compact ? (contentWidth - 10) / 2 : null,
                    child: FilledButton.icon(
                      onPressed: _emitOrdonnance,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Émettre'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.g700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE9E7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEB2B2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rappel : $fullName · Allergies connues : $allergyText · Vérifier les incompatibilités avant prescription',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: compact ? contentWidth : 520,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultation',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.g700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _consultationMotifController,
                        decoration: InputDecoration(
                          hintText: 'Motif de consultation',
                          filled: true,
                          fillColor: AppColors.g50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _consultationDiagnosticController,
                        decoration: InputDecoration(
                          hintText: 'Diagnostic',
                          filled: true,
                          fillColor: AppColors.g50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _consultationNotesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Notes médicales',
                          filled: true,
                          fillColor: AppColors.g50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Médicaments prescrits',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.g700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (previewMeds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucun médicament ajouté pour le moment.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.g600,
                            ),
                          ),
                        )
                      else
                        ...previewMeds.map(
                          (med) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PrescriptionRow(
                              name: med['name'] ?? 'Médicament',
                              posologie: med['dose'] ?? '—',
                              interval: med['interval'] ?? '—',
                              duration: med['duration'] ?? '—',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openAddMedicineDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Ajouter un médicament'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Instructions',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.g700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: _rxInstructionsController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                'Prendre dès les repas. Éviter exposition au soleil. Revenir si fièvre persiste après 48h.',
                            filled: true,
                            fillColor: AppColors.g50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Validité',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.g700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _rxValidity,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.g50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items:
                                      const ['7 jours', '15 jours', '30 jours']
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) => setState(
                                    () => _rxValidity = value ?? _rxValidity,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Renouvellement',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.g700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _rxRenewal,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.g50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items:
                                      const [
                                            'Non renouvelable',
                                            'Renouvelable 1x',
                                            'Renouvelable 2x',
                                          ]
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) => setState(
                                    () => _rxRenewal = value ?? _rxRenewal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: compact ? contentWidth : 360,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.s100),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APERÇU ORDONNANCE NUMÉRIQUE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.g600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.g700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SantéTogo',
                            style: GoogleFonts.syne(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'N° Ordonnance',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                            Text(
                              fullName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                            Text(
                              '${group == '—' ? 'Groupe non renseigné' : 'Groupe $group'} · ${allergiesList.isEmpty ? 'Aucune allergie' : allergiesList.join(' · ')}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ref
                                      .watch(authStateProvider)
                                      .valueOrNull
                                      ?.fullName ??
                                  'Médecin connecté',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                            Text(
                              'Professionnel de santé',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                            Text(
                              _dateLabel(DateTime.now().toIso8601String()),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Médicaments prescrits',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.g700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (previewMeds.isEmpty)
                      Text(
                        'Aucun médicament ajouté pour cette ordonnance.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.g600,
                        ),
                      )
                    else
                      ...previewMeds.map(
                        (med) => _PreviewMedicineLine(
                          label: med['name'] ?? 'Médicament',
                          details:
                              '${med['dose'] ?? '—'} · ${med['duration'] ?? '—'}',
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      _rxInstructionsController.text.trim().isEmpty
                          ? 'Aucune instruction générale ajoutée.'
                          : _rxInstructionsController.text.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.g600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.g50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.s100),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 58,
                              color: AppColors.g700,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Expire le',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                            Text(
                              _rxValidity,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.g800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _rxRenewal,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.g600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patientsView() {
    final visiblePatients = _filteredPatients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _PanelCard(
        title: 'Patients suivis',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Rechercher un patient ou un dossier',
                filled: true,
                fillColor: AppColors.g50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.g500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((option) {
                  final selected = _patientFilter == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _patientFilter = option),
                      selectedColor: AppColors.g700,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.g700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (visiblePatients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun patient ne correspond à ce filtre.'),
              )
            else
              ...visiblePatients.map((patient) {
                final fullName = patient['fullName'] as String;
                final dossier = patient['dossierNumber'] as String;
                final status = patient['carteStatus'] == 'pending'
                    ? 'Dossier en cours'
                    : 'Suivi actif';
                return GestureDetector(
                  onTap: () => _openPatientById(
                    patient['id']?.toString() ?? '',
                    dossierTab: 2,
                  ),
                  child: _PatientItem(
                    name: fullName,
                    id: dossier,
                    status: status,
                    risk: patient['groupeSanguin'] ?? '—',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _consultationsView() {
    if (_consultations.isEmpty) {
      return const Center(child: Text('Aucune consultation récente.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _PanelCard(
        title: 'Consultations enregistrées',
        child: Column(
          children: _consultations.map((item) {
            return _ConsultationItem(
              type: item['type'] as String,
              patient: item['patient'] as String,
              hour: item['hour'] as String,
              state: item['state'] as String,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _ordonnancesView() {
    if (_ordonnances.isEmpty) {
      return const Center(child: Text('Aucune ordonnance récente.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _PanelCard(
        title: 'Ordonnances',
        child: Column(
          children: _ordonnances.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.g50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.s100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['patient'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.g800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['id']} · ${item['date']} · ${item['medicaments']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.g600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item['state'] == 'Validée'
                          ? AppColors.successBg
                          : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item['state'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item['state'] == 'Validée'
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _appointmentsView() {
    if (_appointments.isEmpty) {
      return const Center(child: Text('Aucun rendez-vous à venir.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _PanelCard(
        title: 'Rendez-vous du jour',
        child: Column(
          children: _appointments.map((item) {
            return _AppointmentItem(
              time: item['time'] as String,
              name: item['name'] as String,
              reason: item['reason'] as String,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _reportsView() {
    final average = _patients.isEmpty ? 0 : _patients.length;
    final coverage = _patients.isEmpty
        ? 0
        : (_patients.where((p) => p['groupeSanguin'] != '—').length /
                  _patients.length *
                  100)
              .round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _StatCard(
                  label: 'Total',
                  value: '${_patients.length}',
                  subtitle: 'patients',
                ),
                _StatCard(
                  label: 'Couverture',
                  value: '$coverage%',
                  subtitle: 'dossiers complets',
                ),
                _StatCard(
                  label: 'Moyenne',
                  value: '$average',
                  subtitle: 'par journée',
                ),
              ];
              final columns = constraints.maxWidth < 720 ? 1 : 3;
              final width =
                  (constraints.maxWidth - (12 * (columns - 1))) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((card) => SizedBox(width: width, child: card))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          _PanelCard(
            title: 'Rapports de performance',
            child: Column(
              children: [
                _ActivityRow(
                  label: 'Consultations validées',
                  value: '${_consultations.length}',
                  tone: AppColors.success,
                ),
                _ActivityRow(
                  label: 'Ordonnances émises',
                  value: '${_ordonnances.length}',
                  tone: AppColors.g700,
                ),
                _ActivityRow(
                  label: 'Rendez-vous planifiés',
                  value: '${_appointments.length}',
                  tone: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsView() {
    _prepareSettingsForm();
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isClinic = currentUser?.entiteType != 'pharmacie';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _settingsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paramètres',
              style: GoogleFonts.syne(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.g800,
              ),
            ),
            const SizedBox(height: 18),
            _PanelCard(
              title: 'Compte utilisateur',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 680;
                  final fieldWidth = twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : double.infinity;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _SettingsTextField(
                          controller: _settingsUserPrenomController,
                          label: 'Prénom',
                          icon: Icons.person_rounded,
                          required: true,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _SettingsTextField(
                          controller: _settingsUserNomController,
                          label: 'Nom',
                          icon: Icons.badge_rounded,
                          required: true,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: _SettingsTextField(
                          controller: _settingsEmailController,
                          label: 'Email de contact',
                          icon: Icons.email_rounded,
                          required: true,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _PanelCard(
              title: isClinic
                  ? 'Informations clinique'
                  : 'Informations pharmacie',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 680;
                  final fieldWidth = twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : double.infinity;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsNameController,
                              label: 'Nom de la structure',
                              icon: Icons.local_hospital_rounded,
                              required: true,
                            ),
                          ),
                          if (isClinic)
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _settingsClinicType,
                                decoration: const InputDecoration(
                                  labelText: 'Type de structure',
                                  prefixIcon: Icon(Icons.apartment_rounded),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'clinique_privee',
                                    child: Text('Clinique privée'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hopital',
                                    child: Text('Hôpital'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'centre_sante',
                                    child: Text('Centre de santé'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _settingsClinicType = value);
                                },
                              ),
                            ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsResponsibleController,
                              label: 'Responsable',
                              icon: Icons.supervisor_account_rounded,
                              required: isClinic,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsPhoneController,
                              label: 'Téléphone',
                              icon: Icons.phone_rounded,
                              required: true,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsCityController,
                              label: 'Ville',
                              icon: Icons.location_city_rounded,
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsAddressController,
                              label: 'Adresse complète',
                              icon: Icons.place_rounded,
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsAuthorizationController,
                              label: 'Numéro d’autorisation',
                              icon: Icons.verified_rounded,
                              readOnly: true,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _SettingsTextField(
                              controller: _settingsAuthorizationDateController,
                              label: 'Date d’autorisation',
                              icon: Icons.event_available_rounded,
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _savingSettings ? null : _saveSettings,
                          icon: _savingSettings
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _savingSettings
                                ? 'Enregistrement...'
                                : 'Enregistrer les modifications',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.g700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _PanelCard(
              title: 'Sécurité',
              child: Column(
                children: [
                  _TaskItem(
                    title: 'Session active',
                    subtitle:
                        'Les appels backend utilisent le jeton sécurisé du compte connecté.',
                  ),
                  _TaskItem(
                    title: 'Autorisation',
                    subtitle: isClinic
                        ? 'Seules les cliniques approuvées créent et ouvrent des dossiers patients.'
                        : 'Seules les pharmacies approuvées délivrent les ordonnances.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;
  final bool readOnly;
  final TextInputType? keyboardType;

  const _SettingsTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
    this.readOnly = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (!required) return null;
        return value == null || value.trim().isEmpty ? 'Champ requis' : null;
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.g50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.g700),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.g700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DossierSectionTitle extends StatelessWidget {
  final String title;

  const _DossierSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.g700,
      ),
    );
  }
}

class _DossierHistoryRow extends StatelessWidget {
  final String label;
  final String value;

  const _DossierHistoryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.g600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.g800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final String name;
  final String posologie;
  final String interval;
  final String duration;

  const _PrescriptionRow({
    required this.name,
    required this.posologie,
    required this.interval,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.s100),
        color: AppColors.g50,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.s100),
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 16,
              color: AppColors.g700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniField(value: posologie),
                    _MiniField(value: interval),
                    _MiniField(value: duration),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final String value;

  const _MiniField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.s200),
        color: Colors.white,
      ),
      child: Text(
        value,
        style: GoogleFonts.inter(fontSize: 10, color: AppColors.g700),
      ),
    );
  }
}

class _PreviewMedicineLine extends StatelessWidget {
  final String label;
  final String details;

  const _PreviewMedicineLine({required this.label, required this.details});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.g700,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.g800,
                    ),
                  ),
                  TextSpan(
                    text: details,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.g600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientItem extends StatelessWidget {
  final String name;
  final String id;
  final String status;
  final String risk;

  const _PatientItem({
    required this.name,
    required this.id,
    required this.status,
    required this.risk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.g100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e[0]).take(2).join(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.g700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  id,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.g500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.g700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                risk,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.g500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentItem extends StatelessWidget {
  final String time;
  final String name;
  final String reason;

  const _AppointmentItem({
    required this.time,
    required this.name,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                time,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppColors.g700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reason,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.g500),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.g500),
        ],
      ),
    );
  }
}

class _ConsultationItem extends StatelessWidget {
  final String type;
  final String patient;
  final String hour;
  final String state;

  const _ConsultationItem({
    required this.type,
    required this.patient,
    required this.hour,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$patient · $hour',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.g500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: state == 'Validée'
                  ? AppColors.successBg
                  : state == 'En attente'
                  ? AppColors.warningBg
                  : AppColors.g50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              state,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: state == 'Validée'
                    ? AppColors.success
                    : state == 'En attente'
                    ? AppColors.warning
                    : AppColors.g700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.g50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.s100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.g600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.g800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.g500),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PanelCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.s100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.g800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;

  const _ActivityRow({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.g700),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tone.withAlpha(35),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TaskItem({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.s100)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.g700,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.g800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.g500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
